import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/accessible_layout.dart';
import '../../core/utils/asset_lookup.dart';
import '../../core/utils/audio_speaking_mouth.dart';
import '../../core/utils/speech_cadence.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/asset_images.dart';
import '../../core/widgets/listen_button.dart';
import '../../core/widgets/talking_character.dart';
import '../../data/models/chapter.dart';
import '../audio/audio_controller.dart';
import '../audio/audio_lipsync.g.dart';
import '../grammar/grammar_lesson_screen.dart';

/// Navigation arguments for the story player.
class StoryArgs {
  const StoryArgs(this.chapterId, {this.startScene = 0});

  final String chapterId;
  final int startScene;
}

/// Screens 8 & 9 — the story scene, staged like a comic panel.
///
/// The scene background fills the screen, the chapter's characters stand in it
/// at full height (transparent cut-outs), and the speaker's line appears in a
/// bubble anchored just above *their* head — so it reads as someone talking in
/// the scene, not as captions pinned to the bottom of a photo. Characters who
/// are not speaking dim and shrink slightly, which is what makes the speaker
/// obvious at a glance.
///
/// English is always shown first; the toggle adds the Bengali or Hindi line
/// underneath. Tap anywhere to advance.
class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key, required this.args});

  static const routeName = '/story';

  final StoryArgs args;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  late int _sceneIndex = math.max(0, widget.args.startScene);
  int _lineIndex = 0;
  StoryChoice? _chosenChoice;

  /// Local display language for translations: 'off', 'bn', 'hi'.
  String _translationLang = 'off';

  /// Held so narration can be silenced on the way out, when reading the
  /// provider again is no longer safe.
  AudioController? _audio;

  Timer? _silentSpeechTimer;
  Timer? _autoAdvanceTimer;
  bool _silentTalking = false;

  /// Lip-sync driver: reads the real playhead (or the silent sentence clock)
  /// and hands back an exact mouth shape plus phrase energy.
  AudioSpeakingMouth? _mouthDriver;

  bool _reduceMotion = false;
  bool _localAutoPlay = true;
  bool _initialCueScheduled = false;
  String? _autoQueuedClipId;
  String? _observedPlayingId;
  int _observedCompletedCount = 0;
  int _utteranceKey = 0;
  int _lineToken = 0;

  static const _linePause = Duration(milliseconds: 850);
  static const _translatedLinePause = Duration(milliseconds: 1200);
  static const _lessonHandoffPause = Duration(milliseconds: 1250);
  static const _choiceFeedbackPause = Duration(milliseconds: 1600);

  bool get _autoPlayEnabled {
    final settings = Provider.of<SettingsController?>(context, listen: false);
    return settings?.autoPlayStory ?? _localAutoPlay;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextAudio = AudioScope.maybeOf(context);
    if (!identical(_audio, nextAudio)) {
      _audio?.removeListener(_onAudioChanged);
      _audio = nextAudio;
      _observedPlayingId = nextAudio?.playingId;
      _observedCompletedCount = nextAudio?.completedCount ?? 0;
      _audio?.addListener(_onAudioChanged);
    }
    final nextReduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (nextReduce && !_reduceMotion) {
      _cancelLineTimers();
    }
    _reduceMotion = nextReduce;

    if (!_initialCueScheduled) {
      _initialCueScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _warmChapterCast();
        _startLineDelivery();
      });
    }
  }

  @override
  void dispose() {
    _silentSpeechTimer?.cancel();
    _autoAdvanceTimer?.cancel();
    _mouthDriver?.dispose();
    _audio?.removeListener(_onAudioChanged);
    // A line that keeps talking after the learner has moved on sounds broken.
    _audio?.stop();
    super.dispose();
  }

  Chapter? get _chapter =>
      context.read<ContentController>().byId(widget.args.chapterId);

  String _linePrefix(String chapterId) =>
      'story_${chapterId}_${_sceneIndex}_$_lineIndex';

  void _warmChapterCast() {
    final chapter = _chapter;
    if (chapter == null) return;
    final ids = <String>{
      for (final scene in chapter.scenes) ...[
        ...scene.characterIds,
        for (final line in scene.dialogue) line.characterId,
      ],
    };
    for (final id in ids) {
      final frames = AssetLookup.framesFor(id);
      if (frames == null) continue;
      for (final path in frames.all) {
        precacheImage(AssetImage(path), context).catchError((_) {});
      }
    }
  }

  void _cancelLineTimers({bool updateState = false}) {
    _silentSpeechTimer?.cancel();
    _silentSpeechTimer = null;
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
    _autoQueuedClipId = null;
    _stopLipSync();
    if (_silentTalking) {
      _silentTalking = false;
      if (updateState && mounted) setState(() {});
    }
  }

  // -------------------------------------------------------------------------
  // Lip-sync driving
  //
  // While a clip is sounding, the mouth is read straight off the real playhead
  // and matched against the clip's measured waveform timeline. Before the first
  // sample actually plays the mouth stays politely shut through the load or
  // buffer window, so a slow phone never mimes ahead of a silent speaker.
  // -------------------------------------------------------------------------

  AudioSpeakingMouth _driver() =>
      _mouthDriver ??= AudioSpeakingMouth(audio: _audio);

  /// Measured mouth shape for the character's current animation frame. This is
  /// called from inside [TalkingCharacter]'s own ticker, so the jaw, the blinking
  /// eyelids and the posture all advance on the very same frame.
  MouthFrame? _mouthAt(Duration elapsed) {
    final driver = _driver();
    driver.sample(elapsed);
    return driver.mouth;
  }

  bool get _voiceIsLoading {
    final audio = _audio;
    final playing = audio?.playingId;
    if (audio == null || playing == null) return false;
    return audio.isBuffering(playing);
  }

  void _startLipSync() {
    if (_reduceMotion) return;
    final playing = _audio?.playingId;
    if (playing != null && AudioLipSync.has(playing)) {
      _driver().startClip(playing);
    }
  }

  void _startSilentClock(SpeechCadence cadence) {
    // Reduced motion: no per-frame mouth at all, just the pose.
    if (_reduceMotion) return;
    _driver().startSilent(cadence);
  }

  void _stopLipSync({bool rebuild = true}) {
    _mouthDriver?.stop();
    if (rebuild && mounted) setState(() {});
  }

  void _onAudioChanged() {
    if (!mounted) return;
    final audio = _audio;
    if (audio == null) return;

    final chapter = _chapter;
    final prefix = chapter == null ? null : _linePrefix(chapter.id);
    final playing = audio.playingId;
    final completed = audio.completedCount;

    // A fresh clip started for the line currently on stage (for instance, the
    // learner tapped Bangla or replayed English): rewind the mouth cadence and
    // stand down any pending auto-step so we never cut off what they chose.
    if (playing != null &&
        playing != _observedPlayingId &&
        prefix != null &&
        playing.startsWith('${prefix}_')) {
      _silentSpeechTimer?.cancel();
      _silentSpeechTimer = null;
      _autoAdvanceTimer?.cancel();
      _autoAdvanceTimer = null;
      _silentTalking = false;
      _utteranceKey += 1;
      if (playing != _autoQueuedClipId) {
        _autoQueuedClipId = null;
      }
      // A waveform exists for this clip: follow the real playhead instead of
      // pacing the text, so every syllable lands where the voice says it.
      _startLipSync();
    }

    final queued = _autoQueuedClipId;
    final finishedAutoClip = queued != null &&
        playing == null &&
        completed != _observedCompletedCount &&
        audio.lastCompletedId == queued;

    _observedPlayingId = playing;
    _observedCompletedCount = completed;

    if (playing == null) _stopLipSync(rebuild: false);

    if (finishedAutoClip) {
      _autoQueuedClipId = null;
      _scheduleAutoAdvance();
    }
    setState(() {});
  }

  Future<void> _startLineDelivery() async {
    _cancelLineTimers();
    if (!mounted || _reduceMotion || !_autoPlayEnabled) return;
    final chapter = _chapter;
    if (chapter == null || _sceneIndex >= chapter.scenes.length) return;
    final scene = chapter.scenes[_sceneIndex];
    if (_lineIndex >= scene.dialogue.length) return;
    final line = scene.dialogue[_lineIndex];

    final token = ++_lineToken;
    final enClip = '${_linePrefix(chapter.id)}_en';
    final audio = _audio;

    if (audio != null && audio.canPlay(enClip)) {
      _autoQueuedClipId = enClip;
      _observedCompletedCount = audio.completedCount;
      setState(() => _utteranceKey += 1);
      final started = await audio.play(enClip);
      if (!mounted || token != _lineToken) return;
      if (started) _startLipSync();
      if (!started) {
        // Never leave auto-story stuck when an audio device refuses to open:
        // fall back to text-paced lip-sync so the character still delivers it.
        _autoQueuedClipId = null;
        _startSilentSpeech(line.text.en, token: token);
      }
      return;
    }

    _startSilentSpeech(line.text.en, token: token);
  }

  void _startSilentSpeech(String text, {required int token}) {
    final cadence = SpeechCadence.fromText(text);
    final duration = cadence.silentDuration;
    setState(() {
      _silentTalking = true;
      _utteranceKey += 1;
    });
    _startSilentClock(cadence);
    _silentSpeechTimer = Timer(duration, () {
      if (!mounted || token != _lineToken) return;
      setState(() => _silentTalking = false);
      _scheduleAutoAdvance();
    });
  }

  void _scheduleAutoAdvance({Duration? delay}) {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
    if (!mounted || _reduceMotion || !_autoPlayEnabled) return;
    final chapter = _chapter;
    if (chapter == null || _sceneIndex >= chapter.scenes.length) return;
    final scene = chapter.scenes[_sceneIndex];

    final isLastLineInScene = _lineIndex >= scene.dialogue.length - 1;
    // Pause for learner input when a choice is waiting on screen.
    if (isLastLineInScene &&
        scene.choices.isNotEmpty &&
        _chosenChoice == null) {
      return;
    }

    final isEndOfStory =
        isLastLineInScene && _sceneIndex >= chapter.scenes.length - 1;
    final wait = delay ??
        (isEndOfStory
            ? _lessonHandoffPause
            : _translationLang != 'off'
                ? _translatedLinePause
                : _linePause);
    final token = _lineToken;
    _autoAdvanceTimer = Timer(wait, () {
      if (!mounted || token != _lineToken || !_autoPlayEnabled) return;
      _advance();
    });
  }

  Future<void> _toggleAutoPlay() async {
    final next = !_autoPlayEnabled;
    final settings = Provider.of<SettingsController?>(context, listen: false);
    if (settings != null) {
      await settings.setAutoPlayStory(next);
    } else {
      setState(() => _localAutoPlay = next);
    }
    if (!mounted) return;
    if (!next) {
      ++_lineToken;
      _cancelLineTimers(updateState: true);
      await _audio?.stop();
    } else {
      unawaited(_startLineDelivery());
    }
  }

  void _onChoicePicked(StoryChoice choice) {
    setState(() => _chosenChoice = choice);
    if (_autoPlayEnabled && !_reduceMotion && _audio?.playingId == null) {
      _silentSpeechTimer?.cancel();
      _silentTalking = false;
      _scheduleAutoAdvance(delay: _choiceFeedbackPause);
    }
  }

  void _advance() {
    final chapter = _chapter;
    if (chapter == null || _sceneIndex >= chapter.scenes.length) return;
    ++_lineToken;
    _cancelLineTimers();
    _audio?.stop();
    final scene = chapter.scenes[_sceneIndex];

    if (_lineIndex < scene.dialogue.length - 1) {
      setState(() {
        _chosenChoice = null;
        _lineIndex += 1;
      });
      unawaited(_startLineDelivery());
      return;
    }
    // The length itself is a valid bookmark: the grammar lesson is next.
    final nextScene = _sceneIndex + 1;
    context.read<ProgressController>().openChapter(chapter.id, nextScene);
    if (nextScene < chapter.scenes.length) {
      setState(() {
        _chosenChoice = null;
        _sceneIndex = nextScene;
        _lineIndex = 0;
      });
      unawaited(_startLineDelivery());
    } else {
      Navigator.of(context).pushReplacementNamed(
        GrammarLessonScreen.routeName,
        arguments: chapter.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _chapter;
    if (chapter == null) {
      return const Scaffold(body: Center(child: Text('Chapter not found')));
    }
    // A direct story link (e.g. Home) can also carry the lesson bookmark.
    if (_sceneIndex >= chapter.scenes.length) {
      return GrammarLessonScreen(chapterId: chapter.id);
    }
    // Deliberately NOT seeded from the support language: opening a scene with
    // the translation already rendered means the learner reads the answer
    // before trying the English, which is the one thing this screen teaches.
    final scene = chapter.scenes[_sceneIndex];
    final line = scene.dialogue.isEmpty ? null : scene.dialogue[_lineIndex];
    final text = Theme.of(context).textTheme;
    final autoPlay = context.select(
      (SettingsController? s) => s?.autoPlayStory ?? _localAutoPlay,
    );
    final clipPrefix = _linePrefix(chapter.id);
    final playingId = _audio?.playingId;
    final playingEn = playingId == '${clipPrefix}_en';
    final playingBn = playingId == '${clipPrefix}_bn';
    final audioTalking = playingEn || playingBn;
    // Hold the mouth shut until the decoder actually produces sound, and while
    // the story is paused by the learner — never mime over silence.
    final loadingVoice = _voiceIsLoading;
    final isSpeakerTalking =
        line != null && ((audioTalking && !loadingVoice) || _silentTalking);
    final spokenText = line == null
        ? ''
        : playingBn
            ? line.text.of('bn')
            : line.text.en;
    final showChoices = _lineIndex >= scene.dialogue.length - 1 &&
        scene.choices.isNotEmpty &&
        _chosenChoice == null;
    final hintLabel = isSpeakerTalking || loadingVoice
        ? 'Speaking · Tap to skip'
        : autoPlay && !_reduceMotion
            ? 'Auto on · Tap to continue'
            : 'Tap to continue';

    // The cast for this scene: whoever is listed, plus the current speaker if
    // the data forgot to list them (never leave the speaker off stage).
    final cast = <String>{
      ...scene.characterIds,
      if (line != null) line.characterId,
    }.toList();

    return Scaffold(
      body: GestureDetector(
        onTap: _advance,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A 320 ms cross-fade on the plate only: the cast stays put, so a
            // scene change reads like a cut in a film rather than a page swap.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (current, previous) => Stack(
                fit: StackFit.expand,
                children: [...previous, if (current != null) current],
              ),
              child: _SceneBackdrop(
                key: ValueKey(scene.backgroundId ?? 'none'),
                backgroundId: scene.backgroundId,
              ),
            ),
            // Ground shading: the characters need something to stand on.
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0, 0.45),
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x4D0B1B3A)],
                  ),
                ),
              ),
            ),
            if (line != null)
              _Stage(
                cast: cast,
                speakerId: line.characterId,
                isSpeakerTalking: isSpeakerTalking,
                spokenText: spokenText,
                utteranceKey: _utteranceKey,
                loopSpeech: audioTalking,
                mouthFor: isSpeakerTalking ? _mouthAt : null,
                energy: _mouthDriver?.energy ?? 0,
                backgroundId: scene.backgroundId,
                bubble: _DialogueBubble(
                  characterId: line.characterId,
                  line: line,
                  translationLang: _translationLang,
                  clipPrefix: clipPrefix,
                  isTalking: isSpeakerTalking,
                ),
              ),
            // Bottom interaction zone: choices, then the advance hint.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_chosenChoice != null)
                      _ChoiceResponseBubble(
                        choice: _chosenChoice!,
                        lang: _translationLang,
                      ),
                    if (showChoices)
                      _ChoiceList(
                        choices: scene.choices,
                        lang: _translationLang,
                        onChosen: _onChoicePicked,
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                            AppSpacing.xs, AppSpacing.md, AppSpacing.sm + 2),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.42),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isSpeakerTalking
                                      ? Icons.graphic_eq_rounded
                                      : Icons.touch_app_rounded,
                                  size: 15,
                                  color: Colors.white.withValues(alpha: 0.96),
                                ),
                                const SizedBox(width: 6),
                                // Long scales wrap the hint onto a second line
                                // instead of running past the screen edge.
                                Flexible(
                                  child: Text(
                                    hintLabel,
                                    textAlign: TextAlign.center,
                                    style: text.bodyMedium?.copyWith(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Top bar: progress through the scene + the translation switch.
            // Positioned, not a bare Stack child: with `StackFit.expand` a
            // plain child fills the screen and its Row centres vertically,
            // which parked the back button in the middle of the scene.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xs, AppSpacing.sm, AppSpacing.sm, 0),
                  child: Row(
                    children: [
                      _GlassIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Progress and the language switch share one row while
                      // that fits, and stack when it does not. The switch is
                      // never dropped: at a large font scale the learner needs
                      // the translation most, so the row gives way instead.
                      Expanded(
                        child: AccessibleLayout.needsReflow(context) ||
                                MediaQuery.sizeOf(context).width < 370
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _SceneProgress(
                                          scene: _sceneIndex + 1,
                                          scenes: chapter.scenes.length,
                                          lineProgress: scene.dialogue.isEmpty
                                              ? 1.0
                                              : (_lineIndex + 1) /
                                                  scene.dialogue.length,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      _AutoPlayToggle(
                                        enabled: autoPlay,
                                        onTap: _toggleAutoPlay,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  // Full width, so the three segments split
                                  // the row instead of measuring their own
                                  // intrinsic widths (which is what pushed
                                  // them 42 px past the edge at 200%).
                                  _TranslationToggle(
                                    lang: _translationLang,
                                    stretch: true,
                                    onChanged: (value) => setState(
                                        () => _translationLang = value),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: _SceneProgress(
                                      scene: _sceneIndex + 1,
                                      scenes: chapter.scenes.length,
                                      lineProgress: scene.dialogue.isEmpty
                                          ? 1.0
                                          : (_lineIndex + 1) /
                                              scene.dialogue.length,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  _AutoPlayToggle(
                                    enabled: autoPlay,
                                    onTap: _toggleAutoPlay,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  _TranslationToggle(
                                    lang: _translationLang,
                                    onChanged: (value) => setState(
                                        () => _translationLang = value),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The stage
// ---------------------------------------------------------------------------

/// Lays the cast out along the bottom of the screen and floats the speaker's
/// bubble above their head.
///
/// Each character keeps a consistent spot across the scene so two people talk
/// face-to-face instead of trading places between lines; the active speaker
/// steps slightly taller under a warm key light while listeners stay 100% solid
/// and crisp beside them.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.cast,
    required this.speakerId,
    required this.isSpeakerTalking,
    required this.spokenText,
    required this.utteranceKey,
    required this.loopSpeech,
    required this.mouthFor,
    required this.energy,
    required this.backgroundId,
    required this.bubble,
  });

  final List<String> cast;
  final String speakerId;
  final bool isSpeakerTalking;
  final String spokenText;
  final int utteranceKey;
  final bool loopSpeech;

  /// Measured mouth shape for an animation frame (null keeps the calm text
  /// cadence inside the character widget).
  final MouthFrame? Function(Duration elapsed)? mouthFor;

  /// Smoothed vocal energy for posture and breathing emphasis.
  final double energy;

  final String? backgroundId;
  final Widget bubble;

  /// Character height as a fraction of the stage, and where they stand.
  static const _baseHeightFactor = 0.52;

  /// Low foreground depth band: frames the bottom corners below the cast's
  /// knees so blurred desks/foliage add depth without clouding any character.
  static const _foregroundHeightFactor = 0.22;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;

        // Keep each character anchored to their own stage position throughout
        // the scene so turns feel like a real conversation, not teleporting.
        final ordered = <String>[];
        for (final id in cast) {
          if (!ordered.contains(id)) ordered.add(id);
        }
        if (!ordered.contains(speakerId)) {
          ordered.insert(0, speakerId);
        }

        final slots = _slotsFor(ordered, speakerId, w, h);
        final placements = <_Placement>[];
        for (var i = 0; i < ordered.length; i++) {
          final id = ordered[i];
          placements.add(_Placement(
            id: id,
            dx: slots[i].dx,
            height: slots[i].height,
            isSpeaker: id == speakerId,
          ));
        }

        final speaker = placements.firstWhere(
          (p) => p.isSpeaker,
          orElse: () => placements.first,
        );
        final tallest = placements.fold<double>(
          speaker.height,
          (acc, p) => math.max(acc, p.height),
        );

        // Bubble sits cleanly above the cast heads and grows upward.
        final bubbleWidth = math.min(w * 0.80, 420.0);
        final headY = h - tallest - _stageBottomInset(context);
        final targetTail =
            tailX(speaker.dx + speaker.width / 2, w, bubbleWidth);

        return Stack(
          children: [
            // Draw listeners first and the active speaker on top so emphasis
            // layering stays crisp even on narrow 320 dp phones.
            for (final p in [
              ...placements.where((p) => !p.isSpeaker),
              ...placements.where((p) => p.isSpeaker),
            ])
              Positioned(
                key: ValueKey<String>('stage_slot_${p.id}'),
                left: p.dx,
                // A floor strip so shoes are never cut by the screen edge and
                // the advance hint pill does not sit on their feet.
                bottom: _stageBottomInset(context),
                child: TalkingCharacter(
                  key: ValueKey<String>('stage_char_${p.id}'),
                  characterId: p.id,
                  height: p.height,
                  isSpeaker: p.isSpeaker,
                  isTalking: p.isSpeaker && isSpeakerTalking,
                  spokenText: p.isSpeaker ? spokenText : '',
                  utteranceKey: p.isSpeaker ? utteranceKey : 0,
                  loopSpeech: p.isSpeaker && loopSpeech,
                  mouthFor: p.isSpeaker ? mouthFor : null,
                  energy: p.isSpeaker ? energy : 0,
                ),
              ),
            // Low out-of-focus foreground framing along the bottom edge.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: h * _foregroundHeightFactor,
              child: IgnorePointer(
                child: _Foreground(backgroundId: backgroundId),
              ),
            ),
            // Anchored by its *bottom*, not its top: the bubble grows upward
            // from above the cast so long lines never cover anyone's face.
            Positioned(
              bottom: math.max(
                h - headY + 4,
                MediaQuery.paddingOf(context).bottom + 120,
              ),
              left: (w - bubbleWidth) / 2,
              width: bubbleWidth,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: 1.0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    bubble,
                    // Pointer glides smoothly to whoever is currently talking.
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: targetTail),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      builder: (context, align, _) => _BubbleTail(
                        color: AppColors.surface,
                        align: align,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static double _stageBottomInset(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + 46;

  /// 0..1 horizontal position of the tail inside the bubble, so the pointer
  /// lands on the head of whoever is talking.
  static double tailX(
      double headCentre, double stageWidth, double bubbleWidth) {
    final bubbleLeft = (stageWidth - bubbleWidth) / 2;
    return ((headCentre - bubbleLeft) / bubbleWidth).clamp(0.10, 0.90);
  }

  /// Assigns stable left/centre/right slots while keeping both speaker and
  /// listener generous in size so nobody shrinks into the background.
  static List<_Slot> _slotsFor(
    List<String> ordered,
    String speakerId,
    double w,
    double h,
  ) {
    final base = h * _baseHeightFactor;
    switch (ordered.length) {
      case 1:
        final height = base * 0.96;
        return [_Slot(dx: (w - height * 0.36) / 2, height: height)];
      case 2:
        final xPositions = [w * 0.04, w * 0.54];
        return [
          for (var i = 0; i < 2; i++)
            _Slot(
              dx: xPositions[i],
              height: ordered[i] == speakerId ? base * 1.0 : base * 0.93,
            ),
        ];
      default:
        final xPositions = [w * 0.02, w * 0.35, w * 0.67];
        return [
          for (var i = 0; i < ordered.length; i++)
            _Slot(
              dx: xPositions[math.min(i, xPositions.length - 1)],
              height: ordered[i] == speakerId ? base * 0.95 : base * 0.88,
            ),
        ];
    }
  }
}

class _Slot {
  const _Slot({required this.dx, required this.height});
  final double dx;
  final double height;
}

class _Placement {
  const _Placement({
    required this.id,
    required this.dx,
    required this.height,
    required this.isSpeaker,
  });

  final String id;
  final double dx;
  final double height;
  final bool isSpeaker;

  double get width => height * 0.36;
}

// ---------------------------------------------------------------------------
// Bubble
// ---------------------------------------------------------------------------

/// The speech bubble: the speaker's name, the English line, and — only when
/// asked for — the translation.
class _DialogueBubble extends StatelessWidget {
  const _DialogueBubble({
    required this.characterId,
    required this.line,
    required this.translationLang,
    required this.clipPrefix,
    this.isTalking = false,
  });

  final String characterId;
  final DialogueLine line;
  final String translationLang;

  /// `story_<chapter>_<scene>_<line>` — the clip id is the prefix plus the
  /// language, so the bubble never has to know how assets are named.
  final String clipPrefix;
  final bool isTalking;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = AssetLookup.characterDisplayName(characterId);
    final translation =
        translationLang == 'off' ? null : line.text.of(translationLang);

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm + 2, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: CharacterAvatar(characterId: characterId, size: 24),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  name,
                  style: text.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              if (isTalking) ...[
                const SizedBox(width: 6),
                const ExcludeSemantics(
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
              ],
              const Spacer(),
              // Heard, not read: the English line is what the learner is
              // being taught to say, so it gets its own speaker.
              ListenButton(clipId: '${clipPrefix}_en', size: 26),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            line.text.en,
            style: text.bodyLarge?.copyWith(
              height: 1.42,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (translation != null && translation != line.text.en) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm + 2, 6, AppSpacing.sm, AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.10),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _translationLabel(translationLang),
                          style: text.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const Spacer(),
                      ListenButton(
                          clipId: '${clipPrefix}_$translationLang', size: 24),
                    ],
                  ),
                  Text(
                    translation,
                    style: text.bodyMedium?.copyWith(
                      height: 1.42,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The little pointer that makes a bubble belong to one character.
class _BubbleTail extends StatelessWidget {
  const _BubbleTail({required this.color, required this.align});

  final Color color;
  final double align;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const tailSize = 15.0;
        final leanRight = align > 0.5;
        final left = (width * align - tailSize * 0.8)
            .clamp(12.0, width - tailSize * 2.2);
        return SizedBox(
          height: tailSize,
          width: width,
          child: Stack(
            children: [
              Positioned(
                left: left,
                child: ClipPath(
                  clipper: _TailClipper(leanRight: leanRight),
                  child: Container(
                    width: tailSize * 1.6,
                    height: tailSize,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TailClipper extends CustomClipper<Path> {
  const _TailClipper({required this.leanRight});

  final bool leanRight;

  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * 0.25, 0)
    ..lineTo(size.width * 0.75, 0)
    ..lineTo(size.width * (leanRight ? 0.82 : 0.18), size.height)
    ..close();

  @override
  bool shouldReclip(_TailClipper oldClipper) =>
      oldClipper.leanRight != leanRight;
}

// ---------------------------------------------------------------------------
// Chrome
// ---------------------------------------------------------------------------

class _SceneProgress extends StatelessWidget {
  const _SceneProgress({
    required this.scene,
    required this.scenes,
    this.lineProgress = 1.0,
  });

  final int scene;
  final int scenes;
  final double lineProgress;

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, scenes);
    final activeIndex = (scene - 1).clamp(0, total - 1);
    final fill = lineProgress.clamp(0.18, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scene $scene of $scenes',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Color(0xAA000000), blurRadius: 6)],
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 5,
                    child: LinearProgressIndicator(
                      value: i < activeIndex
                          ? 1.0
                          : i == activeIndex
                              ? fill
                              : 0.0,
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.28),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AccessibleLayout.minTouchTarget,
              minHeight: AccessibleLayout.minTouchTarget,
            ),
            child: Center(child: Icon(icon, size: 20, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

/// Switches automatic story speech + line stepping on and off directly on stage.
class _AutoPlayToggle extends StatelessWidget {
  const _AutoPlayToggle({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: enabled,
      excludeSemantics: true,
      label: 'Auto-play story',
      onTap: onTap,
      child: Tooltip(
        message: enabled ? 'Pause auto-play' : 'Auto-play story',
        child: Material(
          color: enabled
              ? AppColors.primary
              : Colors.black.withValues(alpha: 0.32),
          shape: StadiumBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: AccessibleLayout.minTouchTarget,
                minHeight: AccessibleLayout.minTouchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      enabled ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Auto',
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: enabled ? FontWeight.w900 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// English · বাংলা · हिन्दी as a single segmented switch that cannot overflow.
class _TranslationToggle extends StatelessWidget {
  const _TranslationToggle({
    required this.lang,
    required this.onChanged,
    this.stretch = false,
  });

  final String lang;
  final ValueChanged<String> onChanged;

  /// When true the three segments share the available width equally, which is
  /// what keeps Bengali and Hindi labels reachable at a large font scale.
  final bool stretch;

  static const _options = <(String, String)>[
    ('off', 'EN'),
    ('bn', 'বাংলা'),
    ('hi', 'हिन्दी'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final (value, label) in _options)
            if (stretch)
              Expanded(
                child: _Segment(
                  label: label,
                  selected: lang == value,
                  onTap: () => onChanged(value),
                ),
              )
            else
              _Segment(
                label: label,
                selected: lang == value,
                onTap: () => onChanged(value),
              ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Same reasoning as ListenButton: the pill stays small, the target does
    // not. `selected: true` is what tells a reader which language is active -
    // colour alone does not survive a screen reader.
    return Semantics(
      button: true,
      selected: selected,
      // The visible text lives inside the ExcludeSemantics below, so the
      // label has to be restated here - otherwise the segment is a button
      // with no name at all.
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AccessibleLayout.minTouchTarget,
                minWidth: AccessibleLayout.minTouchTarget,
              ),
              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Choices
// ---------------------------------------------------------------------------

class _ChoiceList extends StatelessWidget {
  const _ChoiceList({
    required this.choices,
    required this.lang,
    required this.onChosen,
  });

  final List<StoryChoice> choices;
  final String lang;
  final ValueChanged<StoryChoice> onChosen;

  static String _promptFor(String lang) => switch (lang) {
        'bn' => 'তোমার পালা · একটি বেছে নাও',
        'hi' => 'आपकी बारी · एक चुनें',
        _ => 'YOUR TURN · CHOOSE A REPLY',
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm + 4, AppSpacing.sm + 2, AppSpacing.sm + 4, 4),
      decoration: BoxDecoration(
        color: const Color(0xCC0B1B3A),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              _promptFor(lang),
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
                letterSpacing: lang == 'off' ? 0.6 : 0.1,
              ),
            ),
          ),
          for (final choice in choices)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppButton(
                label: choice.text.of(lang == 'off' ? 'en' : lang),
                variant: AppButtonVariant.blue,
                expand: false,
                onPressed: () => onChosen(choice),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChoiceResponseBubble extends StatelessWidget {
  const _ChoiceResponseBubble({required this.choice, required this.lang});

  final StoryChoice choice;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              choice.response.of(lang == 'off' ? 'en' : lang),
              style: text.bodyLarge?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _translationLabel(String lang) => lang == 'hi'
    ? 'HINDI'
    : lang == 'bn'
        ? 'BENGALI'
        : '';

/// Out-of-focus props framing the bottom floor edge in front of the cast.
class _Foreground extends StatelessWidget {
  const _Foreground({required this.backgroundId});

  final String? backgroundId;

  @override
  Widget build(BuildContext context) {
    final path =
        backgroundId == null ? null : AssetLookup.foregroundPath(backgroundId!);
    if (path == null) return const SizedBox.shrink();
    // Smooth top fade keeps blurred books/chairs strictly in the bottom floor
    // band so they add cinema depth without clouding any character's body.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
        stops: [0.0, 0.58],
      ).createShader(Offset.zero & rect.size),
      child: Image.asset(
        path,
        fit: BoxFit.cover,
        alignment: Alignment.bottomCenter,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

/// The scene background.
///
/// A 1280 × 714 illustration on a portrait phone has to crop somewhere, and the
/// useful part of every scene is the middle band and the floor — so it covers
/// from the bottom. A soft top vignette hides the hard end of the crop and
/// gives the bubble some air.
class _SceneBackdrop extends StatelessWidget {
  const _SceneBackdrop({super.key, required this.backgroundId});

  final String? backgroundId;

  @override
  Widget build(BuildContext context) {
    final path =
        backgroundId == null ? null : AssetLookup.backgroundPath(backgroundId!);
    if (path == null) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.skyTop, AppColors.skyBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          path,
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: AppColors.skyTop),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xB313276B),
                Color(0x330F172A),
                Color(0x00000000),
                Color(0x4D0B1B3A),
              ],
              stops: [0.0, 0.22, 0.55, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
