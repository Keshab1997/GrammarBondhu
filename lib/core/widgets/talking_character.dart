import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme/app_theme.dart';
import '../utils/asset_lookup.dart';
import '../utils/speech_cadence.dart';
import 'idle_motion.dart';

/// A full-body story character that blinks naturally and moves their mouth in
/// time with spoken dialogue.
///
/// All four frames per character share the exact pixel geometry of the resting
/// full-body sprite, so swapping [Image.asset] with `gaplessPlayback: true`
/// animates only the mouth and eyelids without shifting the clothing or shoes.
///
/// The mouth is paced from [spokenText] by [SpeechCadence] at a calm human rate
/// (roughly three syllables a second with real punctuation pauses), and eyelid
/// and posture polish ride on top. When the caller has a *measured* mouth shape
/// for the exact audio frame it can pass one through `mouthFor`, which wins over
/// the text cadence for that frame — that is how live narration lip-syncs.
///
/// Honours [MediaQuery.maybeDisableAnimationsOf] by resting on the closed smile
/// with no running ticker, keeping reduced-motion devices and `pumpAndSettle`
/// tests completely calm.
class TalkingCharacter extends StatefulWidget {
  const TalkingCharacter({
    super.key,
    required this.characterId,
    required this.height,
    required this.isSpeaker,
    required this.isTalking,
    this.spokenText = '',
    this.utteranceKey = 0,
    this.loopSpeech = false,
    this.energy = 0.0,
    this.mouthFor,
  });

  final String characterId;
  final double height;
  final bool isSpeaker;

  /// True while the character is actively delivering their line (either synced
  /// to playing voice audio or running through the silent speech cadence).
  final bool isTalking;

  /// Text currently being voiced — drives syllable pacing and comma pauses.
  final String spokenText;

  /// Incremented each time a fresh utterance starts so the cadence rewinds to
  /// syllable zero even when the same line is replayed.
  final int utteranceKey;

  /// True while live voice audio is playing so mouth shapes wrap smoothly until
  /// playback completes.
  final bool loopSpeech;

  /// Smoothed phrase-level vocal energy (0..1) used for breathing, head
  /// emphasis and shoulder lift — slow by construction, so it never jitters.
  final double energy;

  /// Optional per-frame mouth override supplied by an owner that knows the real
  /// audio playhead (see `AudioSpeakingMouth`). Returning null keeps the calm
  /// text cadence for that frame.
  final MouthFrame? Function(Duration elapsed)? mouthFor;

  /// How long a single eye-closure lasts. Fast enough to read as a blink rather
  /// than a nap, slow enough to be visible on a 20 ms animation grid.
  static const blinkDurationMs = 155;

  @override
  State<TalkingCharacter> createState() => _TalkingCharacterState();
}

class _TalkingCharacterState extends State<TalkingCharacter>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  late SpeechCadence _cadence = SpeechCadence.fromText(widget.spokenText);

  Duration _lastElapsed = Duration.zero;
  Duration _speechOrigin = Duration.zero;
  MouthFrame _mouth = MouthFrame.closed;
  bool _blinking = false;
  bool _reduceMotion = false;
  String? _warmedCharacter;

  /// Wall-clock moments of a double-blink: eyes sometimes flick twice in quick
  /// succession the way real faces do. Deterministic, so tests stay calm.
  int _blinkCount = 0;
  int _lastBlinkCycle = -1;

  /// Deterministic per-character blink cycle so two actors standing together
  /// never blink in lockstep.
  int get _blinkPeriodMs {
    switch (widget.characterId) {
      case 'rahul':
        return 3400;
      case 'priya':
        return 4150;
      case 'teacher':
        return 3800;
      default:
        return 3600 + (widget.characterId.hashCode.abs() % 700);
    }
  }

  int get _blinkOffsetMs {
    switch (widget.characterId) {
      case 'rahul':
        return 900;
      case 'priya':
        return 2100;
      case 'teacher':
        return 1450;
      default:
        return 1100;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _warmFramesIfNeeded();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant TalkingCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.characterId != widget.characterId) {
      _warmFramesIfNeeded();
    }
    final restarted = oldWidget.utteranceKey != widget.utteranceKey ||
        oldWidget.spokenText != widget.spokenText ||
        (!oldWidget.isTalking && widget.isTalking);
    if (restarted) {
      _cadence = SpeechCadence.fromText(widget.spokenText);
      _speechOrigin = _lastElapsed;
    }
    if (!widget.isTalking && _mouth != MouthFrame.closed) {
      _mouth = MouthFrame.closed;
    }
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _warmFramesIfNeeded() {
    if (_warmedCharacter == widget.characterId) return;
    _warmedCharacter = widget.characterId;
    final frames = AssetLookup.framesFor(widget.characterId);
    if (frames == null) return;
    for (final path in frames.all) {
      precacheImage(AssetImage(path), context).catchError((_) {});
    }
  }

  void _syncTicker() {
    final hasFrames = AssetLookup.framesFor(widget.characterId) != null;
    final shouldRun = !_reduceMotion && hasFrames;
    if (shouldRun && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _speechOrigin = Duration.zero;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
      if (_mouth != MouthFrame.closed || _blinking) {
        setState(() {
          _mouth = MouthFrame.closed;
          _blinking = false;
        });
      }
    }
  }

  void _onTick(Duration elapsed) {
    _lastElapsed = elapsed;

    final nextMouth = widget.isTalking
        ? widget.mouthFor?.call(elapsed) ??
            _cadence.frameAt(
              elapsed - _speechOrigin,
              loop: widget.loopSpeech,
            )
        : MouthFrame.closed;

    final cycle = (elapsed.inMilliseconds + _blinkOffsetMs) ~/ _blinkPeriodMs;
    final cyclePos = (elapsed.inMilliseconds + _blinkOffsetMs) % _blinkPeriodMs;
    if (cycle != _lastBlinkCycle) {
      _lastBlinkCycle = cycle;
      _blinkCount = cycle % 4 == 1 ? 1 : 0;
    }
    // Occasionally the second lid-flick of a double blink, ~230 ms later.
    final doubleFlick = _blinkCount > 0 &&
        cyclePos >= TalkingCharacter.blinkDurationMs + 230 &&
        cyclePos < TalkingCharacter.blinkDurationMs + 230 + 90;
    final nextBlink =
        cyclePos < TalkingCharacter.blinkDurationMs || doubleFlick;

    if (nextMouth != _mouth || nextBlink != _blinking) {
      setState(() {
        _mouth = nextMouth;
        _blinking = nextBlink;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final frames = AssetLookup.framesFor(widget.characterId);
    final mouth =
        (_reduceMotion || !widget.isTalking) ? MouthFrame.closed : _mouth;
    final blinking = !_reduceMotion && _blinking;
    final name = AssetLookup.characterDisplayName(widget.characterId);

    // A blink is drawn as an eyelid band lifted from the blink frame, so the
    // jaw keeps talking through a blink instead of snapping shut for 155 ms.
    final image = _CharacterImage(
      characterId: widget.characterId,
      frames: frames,
      mouth: mouth,
      blinking: blinking,
      height: widget.height,
      fallbackName: name,
    );

    // Vocal emphasis: on an open vowel the torso lifts a hair and the head
    // follows the phrase energy. Tiny numbers, anchored at the shoes.
    final energy = widget.isTalking ? widget.energy.clamp(0.0, 1.0) : 0.0;
    final mouthWeight = switch (mouth) {
      MouthFrame.open => 1.0,
      MouthFrame.half => 0.45,
      MouthFrame.closed => 0.0,
    };
    final emphasis = (mouthWeight * 0.55 + energy * 0.45).clamp(0.0, 1.0);

    Widget art = image;
    if (!_reduceMotion) {
      art = AnimatedScale(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        scale: 1 + 0.0055 * emphasis,
        alignment: Alignment.bottomCenter,
        child: art,
      );
      // Phrase-level head/torso sway: a slow drift that reads as breath and
      // emphasis. Sine of a 2.4 s cycle keeps it under 1% and never stutters.
      final swayMs = _lastElapsed.inMilliseconds +
          (widget.characterId.isEmpty
              ? 0
              : widget.characterId.codeUnitAt(0) * 40);
      final sway = emphasis * 0.9 * math.sin(swayMs / 2400.0 * 2 * math.pi);
      if (sway.abs() > 0.001) {
        art = Transform.rotate(
          angle: sway * 0.006,
          alignment: Alignment.bottomCenter,
          child: art,
        );
      }
    }

    // Focus by lighting, NEVER by lowering opacity: semi-transparency lets
    // desks, chairs, and trees bleed straight through the listener's face and
    // clothes. `srcATop` tints RGB while keeping every body pixel 100% solid.
    art = ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: widget.isSpeaker
            ? const [Color(0x16FFF5DE), Color(0x00FFF5DE)]
            : const [Color(0x0D0F172A), Color(0x050F172A)],
        stops: widget.isSpeaker ? const [0.0, 0.48] : const [0.0, 1.0],
      ).createShader(Offset.zero & rect.size),
      child: art,
    );

    final shadowPath =
        frames?.closed ?? AssetLookup.fullBodyPath(widget.characterId);
    final phase = (widget.characterId.hashCode.abs() % 1000) / 1000.0;

    return AnimatedScale(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      scale: widget.isSpeaker ? 1.0 : 0.96,
      alignment: Alignment.bottomCenter,
      child: IdleBob(
        // Breathing quickens very slightly under speech, like a real chest.
        period: widget.isTalking ? 3100 : (widget.isSpeaker ? 3600 : 4600),
        phase: phase,
        amplitude: widget.isTalking ? 0.0055 : 0.0045,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            // Contact shadow: anchors the shoes firmly onto the scene floor.
            Container(
              width: widget.height * 0.28,
              height: widget.height * 0.036,
              margin: EdgeInsets.only(bottom: widget.height * 0.004),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: RadialGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.42),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            // True contour-matched soft drop shadow so bright desks, walls, and
            // garden leaves never merge with either the speaker or listener.
            if (shadowPath != null)
              IgnorePointer(
                child: ExcludeSemantics(
                  child: Transform.translate(
                    offset: const Offset(0, 3),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: 7,
                        sigmaY: 7,
                        tileMode: TileMode.decal,
                      ),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(
                            alpha: widget.isSpeaker ? 0.30 : 0.26,
                          ),
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          shadowPath,
                          height: widget.height,
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                          gaplessPlayback: true,
                          excludeFromSemantics: true,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            art,
          ],
        ),
      ),
    );
  }
}

/// The body plus, while speaking, a clipped eye-band so a blink and an open
/// jaw can happen at the same instant without ever dropping to the closed
/// smile mid-word.
class _CharacterImage extends StatelessWidget {
  const _CharacterImage({
    required this.characterId,
    required this.frames,
    required this.mouth,
    required this.blinking,
    required this.height,
    required this.fallbackName,
  });

  final String characterId;
  final CharacterFrames? frames;
  final MouthFrame mouth;
  final bool blinking;
  final double height;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final body =
        frames?.baseFor(mouth) ?? AssetLookup.fullBodyPath(characterId);
    if (body == null) {
      return _FallbackBody(name: fallbackName, height: height);
    }

    final base = Image.asset(
      body,
      key: ValueKey<String>(body),
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) =>
          _FallbackBody(name: fallbackName, height: height),
    );

    final blinkPath = frames?.blink;
    if (!blinking || blinkPath == null) return base;

    // Only the hair/brow/lid band is copied from the blink frame (its height is
    // measured per sprite), so the lids close while the jaw keeps working and no
    // vowel is ever clipped off mid-word.
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        base,
        ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: AssetLookup.eyeBandFraction(characterId),
            child: Image.asset(
              blinkPath,
              key: ValueKey<String>(blinkPath),
              height: height,
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}

class _FallbackBody extends StatelessWidget {
  const _FallbackBody({required this.name, required this.height});

  final String name;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: height * 0.36,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.skyTop],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(height * 0.18),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: height * 0.16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
