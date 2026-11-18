import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/accessible_layout.dart';
import '../../core/utils/audio_speaking_mouth.dart';
import '../../core/utils/speech_cadence.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/idle_motion.dart';
import '../../core/widgets/listen_button.dart';
import '../../data/models/chapter.dart';
import '../audio/audio_controller.dart';
import '../audio/audio_lipsync.g.dart';
import '../quiz/quiz_screen.dart';

/// Screen 10 — the grammar lesson, staged as a moment in class.
///
/// It used to be a white card: a title, a paragraph, a list of examples and a
/// round avatar in the corner — a document with a picture on it. A learner
/// opening "the grammar lesson" expects to be *taught*, so the rule is written
/// on a board, Mrs. Sen stands in front of it with a pointer, and the page
/// turns in her rhythm: the rule first, then the examples, then "your turn".
class GrammarLessonScreen extends StatefulWidget {
  const GrammarLessonScreen({super.key, required this.chapterId});

  static const routeName = '/lesson';

  final String chapterId;

  @override
  State<GrammarLessonScreen> createState() => _GrammarLessonScreenState();
}

class _GrammarLessonScreenState extends State<GrammarLessonScreen>
    with TickerProviderStateMixin {
  /// The board is written, not rendered: each page sweeps in line by line.
  late final AnimationController _chalk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  int _page = 0;
  bool _revealAnswers = false;

  /// Board language: English by default, with one tap to read the rule in the
  /// learner's own script. The English example sentences never change — they are
  /// the thing being taught — only the writing around them.
  bool _boardInSupportLanguage = false;

  /// Rule → examples → remember. Three beats, one board.
  static const _pageCount = 3;

  @override
  void initState() {
    super.initState();
    _chalk.forward();
  }

  /// Held so narration can be silenced on the way out, when reading the
  /// provider again is no longer safe.
  AudioController? _audio;

  /// Mrs Sen keeps explaining while the board is read aloud, so her jaw is
  /// driven from the same measured lip-sync timeline as the story cast.
  AudioSpeakingMouth? _mouth;
  late final Ticker _mouthTicker = createTicker(_onMouthTick);

  /// Eyelid state on the animation clock — the jaw itself is measured from audio.
  bool _blinking = false;

  /// Mrs Sen's line for the page on the board, in the current board language.
  /// Her silent lip-sync reads this text when no recording is playing.
  String _spokenLine = '';

  /// True once the first delivery has been armed for this page.
  bool _lineQueued = false;

  /// Where she is in that line: the moment her silent delivery started, and
  /// how long the sentence takes to say. A delivery is re-armed every time she
  /// finishes, so the standee keeps teaching the whole time the page is open.
  DateTime _slotStartedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _slotLength = Duration.zero;
  String? _slotClipId;

  /// A blink lasts about a sixth of a second, and comes round every few
  /// seconds with a per-page offset so it never feels metronomic.
  static const int _blinkMs = 150;
  static const int _blinkPeriodMs = 3900;

  bool _blinkAt(Duration elapsed) {
    final pos = (elapsed.inMilliseconds + _page * 1170) % _blinkPeriodMs;
    return pos < _blinkMs;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final nextAudio = AudioScope.maybeOf(context);
    if (!identical(nextAudio, _audio)) {
      _audio?.removeListener(_syncMouth);
      _mouth = AudioSpeakingMouth(audio: nextAudio);
      _audio = nextAudio;
      _audio?.addListener(_syncMouth);
    }
    if (reduceMotion) {
      _chalk.value = 1;
    }
    if (reduceMotion) {
      if (_mouthTicker.isActive) _mouthTicker.stop();
      _mouth?.stop();
    } else if (!_mouthTicker.isActive) {
      _mouthTicker.start();
    }
  }

  /// Points her jaw at whatever is audible: her own `teach_*` recording when it
  /// plays, the board narration when that is the sound, and a calm silent read
  /// of her line when narration is off — she always talks, like a real teacher.
  void _syncMouth() {
    if (_spokenLine.isEmpty && _audio?.playingId == null) return;
    // No AudioScope in this tree (golden tests, storyboard harness): she keeps
    // her resting pose rather than guessing at a timeline.
    final mouth = _mouth ??= AudioSpeakingMouth(audio: _audio);
    final audio = _audio;
    final playing = audio?.playingId;

    final audioLang = _boardLangForAudio();
    final candidates = <String>[
      'teach_${_page + 1}_$audioLang',
      switch (_page) {
        0 => 'board_${widget.chapterId}_explain_$audioLang',
        1 => 'board_${widget.chapterId}_examples_en',
        _ => '',
      },
    ];

    final clip = candidates.where((c) => c.isNotEmpty && c == playing).toList();
    if (clip.isNotEmpty && AudioLipSync.has(clip.first)) {
      // A real recording is sounding: follow its measured timeline instead.
      _slotClipId = null;
      _slotLength = Duration.zero;
      mouth.startClip(clip.first);
      return;
    }

    if (_spokenLine.isEmpty) {
      _slotClipId = null;
      _slotLength = Duration.zero;
      mouth.stop();
      return;
    }

    // No sound right now: she delivers the sentence silently, at the pace a
    // person would say it, then pauses like a teacher waiting for the class.
    final cadence = SpeechCadence.fromText(_spokenLine);
    final now = DateTime.now();
    if (_slotClipId != null || _slotLength == Duration.zero) {
      _slotClipId = _spokenLine;
      _slotStartedAt = now;
      _slotLength = cadence.silentDuration;
      mouth.startSilent(cadence);
      return;
    }

    final elapsed = now.difference(_slotStartedAt);
    if (elapsed >= _slotLength + const Duration(milliseconds: 1400)) {
      // Finished the sentence and held the pause: start a fresh delivery.
      _slotStartedAt = now;
      _slotLength = cadence.silentDuration;
      mouth.startSilent(cadence);
    }
  }

  String _boardLangForAudio() {
    final support = context.read<SettingsController>().supportLanguage;
    return _boardInSupportLanguage ? support : 'en';
  }

  void _onMouthTick(Duration elapsed) {
    final mouth = _mouth;
    final mouthChanged = mouth?.sample() ?? false;
    final blink = _blinkAt(elapsed);
    if (mouthChanged || blink != _blinking) {
      if (!mounted) return;
      setState(() => _blinking = blink);
    }
  }

  @override
  void dispose() {
    _audio?.removeListener(_syncMouth);
    _mouthTicker.dispose();
    _mouth?.dispose();
    _audio?.stop();
    _chalk.dispose();
    super.dispose();
  }

  void _turn({required bool forward, required VoidCallback onFinish}) {
    // The board is re-written on every turn; whatever was being read aloud
    // belongs to the page that just left.
    _audio?.stop();
    if (forward && _page == _pageCount - 1) {
      onFinish();
      return;
    }
    setState(() {
      _page = (_page + (forward ? 1 : -1)).clamp(0, _pageCount - 1);
      _revealAnswers = false;
    });
    _lineQueued = false;
    _syncMouth();
    if (MediaQuery.disableAnimationsOf(context)) {
      _chalk.value = 1;
    } else {
      _chalk.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentController>();
    final settings = context.watch<SettingsController>();
    final chapter = content.byId(widget.chapterId);
    if (chapter == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Chapter not found')));
    }
    final lang = settings.supportLanguage;
    final boardLang = _boardInSupportLanguage ? lang : 'en';
    final teacherLine = _teacherLine(boardLang, _page);
    if (!_lineQueued) {
      // Start her jaw once the first frame is laid out, so the standee begins
      // teaching instead of standing frozen until something else happens.
      _lineQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _spokenLine = teacherLine;
        _syncMouth();
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF16241E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _ClassroomWall(),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: _TopBar(
                    chapter: chapter,
                    boardLang: boardLang,
                    onToggleLanguage: () => setState(() {
                      _boardInSupportLanguage = !_boardInSupportLanguage;
                      // New language, new sentence: she starts it over.
                      _lineQueued = false;
                    }),
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm + 4),
                    child: _Board(
                      chapter: chapter,
                      page: _page,
                      pageCount: _pageCount,
                      lang: boardLang,
                      progress: _chalk,
                      revealAnswers: _revealAnswers,
                      onToggleAnswers: () =>
                          setState(() => _revealAnswers = !_revealAnswers),
                      audioClipId: switch (_page) {
                        0 => 'board_${chapter.id}_explain_$boardLang',
                        1 => 'board_${chapter.id}_examples_en',
                        _ => null,
                      },
                      teacher: _TeacherStage(
                        pose: _poses[_page],
                        line: teacherLine,
                        clipId: 'teach_${_page + 1}_$boardLang',
                        eyeBand: _poseEyeBand[_page],
                        mouthFrame: _mouth?.mouth,
                        blinking: _blinking,
                      ),
                    ),
                  ),
                ),
                _CtaBar(
                  label: _page == _pageCount - 1 ? 'Start the quiz' : 'Next',
                  icon: _page == _pageCount - 1
                      ? Icons.quiz_rounded
                      : Icons.arrow_forward_rounded,
                  onBack: _page == 0
                      ? null
                      : () => _turn(forward: false, onFinish: () {}),
                  onPressed: () => _turn(
                    forward: true,
                    onFinish: () => Navigator.of(context).pushNamed(
                        QuizScreen.routeName,
                        arguments: widget.chapterId),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One standee per page: pointer on the rule, book while reading the
  /// examples, open palms for "your turn".
  static const List<TeacherPose> _poses = [
    TeacherPose(
      'assets/characters/teacher_pointer.webp',
      479 / 703,
      talkHalf: 'assets/characters/teacher_pointer_talk_half.webp',
      talkOpen: 'assets/characters/teacher_pointer_talk_open.webp',
      blink: 'assets/characters/teacher_pointer_blink.webp',
    ),
    TeacherPose(
      'assets/characters/teacher_book.webp',
      428 / 714,
      talkHalf: 'assets/characters/teacher_book_talk_half.webp',
      talkOpen: 'assets/characters/teacher_book_talk_open.webp',
      blink: 'assets/characters/teacher_book_blink.webp',
    ),
    TeacherPose(
      'assets/characters/teacher_invite.webp',
      328 / 708,
      talkHalf: 'assets/characters/teacher_invite_talk_half.webp',
      talkOpen: 'assets/characters/teacher_invite_talk_open.webp',
      blink: 'assets/characters/teacher_invite_blink.webp',
    ),
  ];

  /// Height fraction of the eyelid band inside each pose, measured from the
  /// sprites, so a blink never reaches down into a talking mouth.
  static const List<double> _poseEyeBand = [0.136, 0.132, 0.122];

  /// One sentence per page, in the language the learner reads in. The long
  /// explanation belongs on the board; this is the teacher talking over it.
  static String _teacherLine(String lang, int page) {
    switch (lang) {
      case 'hi':
        return switch (page) {
          0 => 'यह नियम बोर्ड पर है। ध्यान से देखो।',
          1 => 'उदाहरण ज़ोर से पढ़ो — मैं सुन रही हूँ।',
          _ => 'अब अपनी बारी। क्विज़ में आज़माओ।',
        };
      case 'en':
        return switch (page) {
          0 => 'The rule is on the board — read it carefully.',
          1 => 'Read each example out loud; I am listening.',
          _ => 'Your turn now. Try it in the quiz.',
        };
      default:
        return switch (page) {
          0 => 'নিয়মটা বোর্ডে লিখেছি। ভালো করে দেখো।',
          1 => 'উদাহরণগুলো জোরে পড়ো — আমি শুনছি।',
          _ => 'এবার তোমার পালা। কুইজে চেষ্টা করে দেখো।',
        };
    }
  }
}

// ---------------------------------------------------------------- the room ---

/// The classroom wall behind the board: the room plate, darkened so the board
/// and the person in front of it own the frame.
class _ClassroomWall extends StatelessWidget {
  const _ClassroomWall();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/backgrounds/bg_classroom.webp',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0xFF2B3F35)),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xD90F172A), Color(0x99101814), Color(0xE6101E18)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.chapter,
    required this.boardLang,
    required this.onToggleLanguage,
    required this.onBack,
  });

  final Chapter chapter;
  final String boardLang;
  final VoidCallback onToggleLanguage;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final close = _GlassButton(icon: Icons.arrow_back_rounded, onTap: onBack);
    final toggle = _LanguagePill(boardLang: boardLang, onTap: onToggleLanguage);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Grammar lesson',
            style: text.titleMedium?.copyWith(color: Colors.white)),
        Text(
          chapter.title.en,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.bodySmall
              ?.copyWith(color: Colors.white.withValues(alpha: 0.86)),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: AccessibleLayout.needsReflow(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [close, toggle]),
                heading,
              ],
            )
          : Row(
              children: [
                close,
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: heading),
                toggle,
              ],
            ),
    );
  }
}

/// "EN / বাংলা / हिन्दी" — the board's language, as one small pill.
class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.boardLang, required this.onTap});

  final String boardLang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Hindi vs Bangla comes from the app's support language, so the pill always
    // names the script the tap will produce.
    final support = context.watch<SettingsController>().supportLanguage;
    if (support == 'en') return const SizedBox.shrink();
    final (label, language) = switch (boardLang == 'en' ? support : 'en') {
      'hi' => ('हिन्दी', 'Hindi'),
      'bn' => ('বাংলা', 'Bengali'),
      _ => ('EN', 'English'),
    };
    return Semantics(
      container: true,
      button: true,
      label: 'Show lesson in $language',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            constraints: const BoxConstraints(
                minWidth: AccessibleLayout.minTouchTarget,
                minHeight: AccessibleLayout.minTouchTarget),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.24), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.translate_rounded,
                    size: 13, color: Colors.white.withValues(alpha: 0.8)),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: AccessibleLayout.minTouchTarget,
        minHeight: AccessibleLayout.minTouchTarget,
      ),
      child: IconButton(
        tooltip: 'Close lesson',
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: Colors.white),
        style: IconButton.styleFrom(
            minimumSize: const Size.square(AccessibleLayout.minTouchTarget),
            visualDensity: VisualDensity.standard,
            backgroundColor: Colors.white.withValues(alpha: 0.16)),
      ),
    );
  }
}

// --------------------------------------------------------------- the board ---

/// A blackboard, drawn rather than photographed: wooden frame, chalk tray, and
/// the page written on it in chalk.
class _Board extends StatelessWidget {
  const _Board({
    required this.page,
    required this.pageCount,
    required this.chapter,
    required this.revealAnswers,
    required this.onToggleAnswers,
    required this.teacher,
    required this.lang,
    required this.progress,
    required this.audioClipId,
  });

  final int page;
  final int pageCount;
  final Chapter chapter;
  final bool revealAnswers;
  final VoidCallback onToggleAnswers;
  final Widget teacher;
  final String lang;
  final Animation<double> progress;

  /// Narration for what is written on this page; null on the "your turn"
  /// page, where the teacher's own line is the thing to hear.
  final String? audioClipId;

  /// Where the page is, written on the slate so the top bar can hold the
  /// language toggle instead.
  String get _pageLabel => switch (lang) {
        'bn' => 'পৃষ্ঠা ${page + 1} / ৩',
        'hi' => 'पेज ${page + 1} / 3',
        _ => 'PAGE ${page + 1} OF 3',
      };

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 12, 4),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                  child: Text(_pageLabel,
                      style: _BoardPage.chalk(11,
                          alpha: 0.86, w: FontWeight.w800))),
              const SizedBox(width: AppSpacing.xs),
              for (var i = 0; i < pageCount; i++)
                Container(
                  width: i == page ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.only(left: 5),
                  decoration: BoxDecoration(
                    color: i == page
                        ? AppColors.accent
                        : Colors.white.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ]),
            if (audioClipId != null)
              _BoardListenChip(
                  clipId: audioClipId!,
                  label: switch (lang) {
                    'bn' => 'শুনে নাও',
                    'hi' => 'सुनकर देखो',
                    _ => 'Hear it',
                  }),
          ],
        ),
      );

  Widget _layoutPage(BuildContext context, BoxConstraints space) {
    // Let the cast scroll with the writing on a small slate. On roomier
    // screens Mrs. Sen stays in view, but never covers an answer or a control.
    final dockTeacher = space.maxHeight >= 420 &&
        space.maxWidth >= 300 &&
        !AccessibleLayout.needsReflow(context);
    final writing = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: _BoardPage(
        chapter: chapter,
        page: page,
        lang: lang,
        progress: progress,
        revealAnswers: revealAnswers,
        onToggleAnswers: onToggleAnswers,
      ),
    );
    final scroll = SingleChildScrollView(
      key: ValueKey(page),
      primary: false,
      child: dockTeacher
          ? writing
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [writing, teacher],
            ),
    );
    if (!dockTeacher) return scroll;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: scroll),
      teacher,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF8A5A34), Color(0xFF5E3A20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      padding: const EdgeInsets.all(9),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
                decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2F4B3C), Color(0xFF21362C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            )),
            // Chalk haze: corners are never evenly erased.
            DecoratedBox(
                decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.6),
                radius: 1.1,
                colors: [
                  Colors.white.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0)
                ],
              ),
            )),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _header(),
              Expanded(child: LayoutBuilder(builder: _layoutPage)),
            ]),
          ],
        ),
      ),
    );
  }
}

/// One page of the board. Each block is written in turn as the sweep runs.
class _BoardPage extends StatelessWidget {
  const _BoardPage({
    required this.page,
    required this.chapter,
    required this.revealAnswers,
    required this.onToggleAnswers,
    required this.lang,
    required this.progress,
  });

  final int page;
  final Chapter chapter;
  final bool revealAnswers;
  final VoidCallback onToggleAnswers;
  final String lang;
  final Animation<double> progress;

  static TextStyle chalk(
    double size, {
    double alpha = 0.94,
    Color color = Colors.white,
    FontWeight w = FontWeight.w600,
  }) {
    return TextStyle(
      fontSize: size,
      height: 1.35,
      color: color.withValues(alpha: alpha),
      fontWeight: w,
      letterSpacing: 0.2,
      shadows: const [
        Shadow(color: Color(0x20FFFFFF), blurRadius: 2),
        Shadow(color: Color(0x66000000), blurRadius: 1, offset: Offset(0, 1)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = chapter.lesson;
    final children = <Widget>[
      _ChalkLine(
        progress: progress,
        from: 0.0,
        to: 0.25,
        child: Text(_kicker, style: chalk(11, alpha: 0.76, w: FontWeight.w800)),
      ),
    ];

    if (page == 0) {
      children.addAll([
        _ChalkLine(
          progress: progress,
          from: 0.12,
          to: 0.45,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lesson.title.en, style: chalk(25, w: FontWeight.w700)),
              const SizedBox(height: 6),
              _ChalkUnderline(progress: progress, from: 0.34, to: 0.55),
            ],
          ),
        ),
        _ChalkLine(
          progress: progress,
          from: 0.46,
          to: 0.72,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(lesson.explanation.of(lang),
                style: chalk(14.5, alpha: 0.95)),
          ),
        ),
        if (chapter.id == 'ch01')
          for (var i = 0; i < _table.length; i++)
            _ChalkLine(
              progress: progress,
              from: 0.70 + i * 0.09,
              to: 0.84 + i * 0.09,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                // Flexible subject, fixed verb column: Bangla subjects are wider
                // than "I", and a fixed 118 px column pushed them into the dash.
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        switch (lang) {
                          'bn' => _table[i].$3,
                          'hi' => _table[i].$4,
                          _ => _table[i].$1,
                        },
                        style: chalk(14, alpha: 0.75),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('—', style: chalk(14, alpha: 0.76)),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 62,
                      child: Text(
                        _table[i].$2,
                        style: chalk(17, w: FontWeight.w700).copyWith(
                            color: AppColors.accent.withValues(alpha: 0.95)),
                      ),
                    ),
                  ],
                ),
              ),
            )
        else if (lesson.examples.isNotEmpty)
          _ChalkLine(
            progress: progress,
            from: 0.70,
            to: 1,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.45)),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: _example(lesson.examples.first, highlighted: true),
              ),
            ),
          ),
      ]);
    } else if (page == 1) {
      children.addAll([
        _ChalkLine(
          progress: progress,
          from: 0.1,
          to: 0.3,
          child: Text(_t('Examples', 'উদাহরণ', 'उदाहरण'),
              style: chalk(20, w: FontWeight.w700)),
        ),
        for (var i = 0; i < lesson.examples.length; i++)
          _ChalkLine(
            progress: progress,
            from: 0.24 + i * 0.14,
            to: 0.5 + i * 0.14,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3, right: 8),
                    child: Icon(Icons.check_rounded,
                        size: 16,
                        color: AppColors.accent.withValues(alpha: 0.90)),
                  ),
                  Expanded(child: _example(lesson.examples[i])),
                ],
              ),
            ),
          ),
      ]);
    } else {
      final practice = _practice;
      final answerKey = practice.map((line) => line.answer).join(' · ');
      final toggleLabel = revealAnswers
          ? _t('Hide answers', 'উত্তর লুকাও', 'जवाब छुपाओ')
          : _t('Show answers', 'উত্তর দেখো', 'जवाब देखो');
      children.addAll([
        _ChalkLine(
          progress: progress,
          from: 0.1,
          to: 0.3,
          child: Text(_t('Say it yourself', 'নিজে বলে দেখো', 'खुद बोलकर देखो'),
              style: chalk(20, w: FontWeight.w700)),
        ),
        _ChalkLine(
          progress: progress,
          from: 0.25,
          to: 0.45,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              chapter.id == 'ch01'
                  ? _t(
                      'Fill the gap out loud, then check below.',
                      'ফাঁকা জায়গাটা জোরে বলে ভরো, তারপর নিচে মিলিয়ে নাও।',
                      'खाली जगह ज़ोर से बोलकर भरो, फिर नीचे मिलाओ।')
                  : chapter.quiz.isEmpty
                      ? _t(
                          'Read the examples aloud and explain the rule.',
                          'উদাহরণগুলো জোরে পড়ো আর নিয়মটা বোঝাও।',
                          'उदाहरण ज़ोर से पढ़ो और नियम समझाओ।')
                      : _t(
                          'Answer out loud, then check below.',
                          'জোরে উত্তর বলো, তারপর নিচে মিলিয়ে নাও।',
                          'जवाब ज़ोर से बोलो, फिर नीचे मिलाओ।'),
              style: chalk(13, alpha: 0.86),
            ),
          ),
        ),
        for (var i = 0; i < practice.length; i++)
          _ChalkLine(
            progress: progress,
            from: 0.35 + i * 0.14,
            to: 0.6 + i * 0.14,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${i + 1}.  ${practice[i].prompt}', style: chalk(15)),
                    if (practice[i].options.isNotEmpty)
                      Text(practice[i].options.join('  /  '),
                          style: chalk(13, alpha: 0.85)),
                  ]),
            ),
          ),
        if (practice.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: onToggleAnswers,
            icon: Icon(
                revealAnswers
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18),
            label: Text(toggleLabel),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              shape: const StadiumBorder(),
              minimumSize: const Size.square(AccessibleLayout.minTouchTarget),
              visualDensity: VisualDensity.standard,
            ),
          ),
          if (revealAnswers)
            _RevealIntoView(
              child: Semantics(
                  liveRegion: true,
                  child: Container(
                    margin: const EdgeInsets.only(top: AppSpacing.sm),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(AppRadii.chip)),
                    child: Text(
                        '${_t('Answers: ', 'উত্তর: ', 'जवाब: ')}$answerKey',
                        style: chalk(15,
                            color: AppColors.accent,
                            alpha: 1,
                            w: FontWeight.w700)),
                  )),
            ),
        ],
      ]);
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _example(LessonExample example, {bool highlighted = false}) {
    final note = example.note.of(lang).trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(example.sentence,
          style:
              chalk(15, color: highlighted ? AppColors.goldTop : Colors.white)),
      if (note.isNotEmpty) ...[
        const SizedBox(height: 3),
        Text(note,
            style: chalk(13, color: const Color(0xFFE2F1E8), alpha: 0.80)),
      ],
    ]);
  }

  /// Board chrome in the language the toggle is set to. The English example
  /// sentences are deliberately never translated.
  String _t(String en, String bn, String hi) =>
      switch (lang) { 'bn' => bn, 'hi' => hi, _ => en };

  String get _kicker => switch (page) {
        0 => _t('TODAY’S RULE', 'আজকের নিয়ম', 'आज का नियम'),
        1 => _t('ON THE BOARD', 'বোর্ডে লেখা', 'बोर्ड पर'),
        _ => _t('YOUR TURN', 'তোমার পালা', 'तुम्हारी बारी'),
      };

  List<({String prompt, String answer, List<String> options})> get _practice {
    if (chapter.id == 'ch01') {
      return const [
        (prompt: 'I ___ a student.', answer: 'am', options: <String>[]),
        (prompt: 'He ___ my friend.', answer: 'is', options: <String>[]),
        (prompt: 'They ___ classmates.', answer: 'are', options: <String>[]),
      ];
    }
    if (chapter.quiz.isNotEmpty) {
      return [
        for (final q in chapter.quiz.take(3))
          (
            prompt: q.question, answer: q.correctAnswer,
            // A “choose the correct sentence” prompt needs its choices to make sense.
            options: q.question.contains('___') ? const <String>[] : q.options
          )
      ];
    }
    return [
      for (final e in chapter.lesson.examples.take(3))
        (
          prompt: e.sentence,
          answer: e.note.of(lang).trim().isEmpty ? e.sentence : e.note.of(lang),
          options: const <String>[]
        )
    ];
  }

  /// Subject → verb, the three rows a teacher writes under the rule, with the
  /// subject in all three languages.
  static const List<(String, String, String, String)> _table = [
    ('I', 'am', 'আমি', 'मैं'),
    ('he / she / it', 'is', 'সে', 'वह'),
    ('you / we / they', 'are', 'তুমি / আমরা / তারা', 'तुम / हम / वे'),
  ];
}

/// Scrolls a newly revealed answer pill into view on the board slate so it is
/// never tucked below the scroll fold above Mrs. Sen.
class _RevealIntoView extends StatefulWidget {
  const _RevealIntoView({required this.child});

  final Widget child;

  @override
  State<_RevealIntoView> createState() => _RevealIntoViewState();
}

class _RevealIntoViewState extends State<_RevealIntoView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final instant = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      Scrollable.ensureVisible(
        context,
        alignment: 1.0,
        duration: instant ? Duration.zero : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Reveals its child between two points of the chalk animation.
class _ChalkLine extends StatelessWidget {
  const _ChalkLine({
    required this.progress,
    required this.from,
    required this.to,
    required this.child,
  });

  final Animation<double> progress;
  final double from;
  final double to;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final interval =
        Interval(from.clamp(0, 1), to.clamp(0, 1), curve: Curves.easeOut);
    final curve = progress.drive(CurveTween(curve: interval));
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, 4 * (1 - curve.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _ChalkUnderline extends StatelessWidget {
  const _ChalkUnderline({
    required this.progress,
    required this.from,
    required this.to,
  });

  final Animation<double> progress;
  final double from;
  final double to;

  @override
  Widget build(BuildContext context) {
    final interval =
        Interval(from.clamp(0, 1), to.clamp(0, 1), curve: Curves.easeOut);
    final curve = progress.drive(CurveTween(curve: interval));
    return AnimatedBuilder(
      animation: curve,
      builder: (context, _) => FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: curve.value.clamp(0.001, 1),
        child: Container(
          height: 3,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- the teacher ---

/// One standee and its art aspect.
class TeacherPose {
  const TeacherPose(
    this.asset,
    this.aspect, {
    required this.talkHalf,
    required this.talkOpen,
    required this.blink,
  });

  final String asset;
  final double aspect;

  /// Pixel-registered mouth and eyelid frames for this pose, so Mrs. Sen's jaw
  /// moves while she explains the board instead of standing frozen beside a
  /// speaking bubble. Built by `tool/build_teacher_pose_frames.py`.
  final String talkHalf;
  final String talkOpen;
  final String blink;

  /// Body frame carrying only the jaw shape; eyelids are overlaid separately.
  String baseFor(MouthFrame mouth) {
    switch (mouth) {
      case MouthFrame.open:
        return talkOpen;
      case MouthFrame.half:
        return talkHalf;
      case MouthFrame.closed:
        return asset;
    }
  }
}

/// Keep the silhouette and the speech bubble out of the writing's hit area.
class _TeacherStage extends StatelessWidget {
  const _TeacherStage({
    required this.pose,
    required this.line,
    required this.clipId,
    required this.eyeBand,
    required this.mouthFrame,
    required this.blinking,
  });

  final TeacherPose pose;
  final String line;
  final String clipId;

  /// Height fraction of the eyelid band inside [pose]'s sprite.
  final double eyeBand;

  /// Mouth shape measured from whatever audio is sounding, or null when she is
  /// not speaking at all.
  final MouthFrame? mouthFrame;

  /// True for the ~150 ms of an eyelid closure.
  final bool blinking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 6),
      child: LayoutBuilder(builder: (context, space) {
        final width = (space.maxWidth * 0.38).clamp(0.0, 224.0 * pose.aspect);
        final standee = SizedBox(
          width: width,
          child: AspectRatio(
              aspectRatio: pose.aspect,
              child: IdleBob(
                period: 5000,
                amplitude: 0.005,
                child: _Teacher(
                  pose: pose,
                  eyeBand: eyeBand,
                  mouthFrame: mouthFrame,
                  blinking: blinking,
                ),
              )),
        );
        final speech = _TeacherSays(text: line, clipId: clipId);
        if (AccessibleLayout.needsReflow(context)) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [standee, speech]);
        }
        return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [Expanded(child: speech), standee]);
      }),
    );
  }
}

class _Teacher extends StatelessWidget {
  const _Teacher({
    required this.pose,
    required this.eyeBand,
    required this.mouthFrame,
    required this.blinking,
  });

  final TeacherPose pose;
  final double eyeBand;

  /// Current jaw shape; null keeps the resting smile of the standee.
  final MouthFrame? mouthFrame;

  final bool blinking;

  @override
  Widget build(BuildContext context) {
    final mouth = mouthFrame ?? MouthFrame.closed;
    final bodyPath = pose.baseFor(mouth);
    final art = _PoseImage(
      path: bodyPath,
      fallback: pose.asset,
      eyeBand: eyeBand,
      blinking: blinking,
    );
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.bottomRight,
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: const Offset(-2, 4),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(
                sigmaX: 7, sigmaY: 7, tileMode: TileMode.decal),
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.32), BlendMode.srcIn),
              child: _PoseImage(
                path: bodyPath,
                fallback: pose.asset,
                eyeBand: eyeBand,
                blinking: false,
              ),
            ),
          ),
        ),
        art,
      ],
    );
  }
}

/// One standee frame with, while she talks, only the eyelid band taken from the
/// blink frame — the jaw keeps its vowel shape through the blink.
class _PoseImage extends StatelessWidget {
  const _PoseImage({
    required this.path,
    required this.fallback,
    required this.eyeBand,
    required this.blinking,
  });

  final String path;
  final String fallback;
  final double eyeBand;
  final bool blinking;

  @override
  Widget build(BuildContext context) {
    Widget image(String asset) => Image.asset(
          asset,
          key: ValueKey<String>(asset),
          fit: BoxFit.contain,
          alignment: Alignment.bottomRight,
          filterQuality: FilterQuality.high,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          errorBuilder: (_, __, ___) =>
              asset == fallback ? const SizedBox.shrink() : image(fallback),
        );

    final body = image(path);
    if (!blinking) return body;
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.bottomRight,
      children: [
        body,
        Align(
          alignment: Alignment.topRight,
          heightFactor: eyeBand,
          child: ClipRect(child: image(_blinkPathFor(path))),
        ),
      ],
    );
  }

  static String _blinkPathFor(String bodyPath) => bodyPath.replaceFirst(
      RegExp(r'(_talk_half|_talk_open)?\.webp$'), '_blink.webp');
}

class _TeacherSays extends StatelessWidget {
  const _TeacherSays({required this.text, required this.clipId});

  final String text;

  /// `teach_<page>_<lang>` — the same line the bubble shows, spoken.
  final String clipId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.14)),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Speaker name and the narration button already filled the
                // bubble at default type; at 200% the name overflowed by
                // 44 px. Flexible lets the name wrap inside the bubble, and
                // the button keeps its 48 dp target - a finger does not get
                // smaller when the text gets bigger.
                Row(
                  children: [
                    const Icon(Icons.record_voice_over_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Mrs. Sen',
                        style: theme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (AudioScope.maybeOf(context)?.canPlay(clipId) ?? false)
                      SizedBox.square(
                        dimension: AccessibleLayout.minTouchTarget,
                        child: ListenButton(clipId: clipId, size: 26),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: theme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: CustomPaint(size: const Size(16, 20), painter: _TailPainter()),
        ),
      ],
    );
  }
}

/// A chalk-outlined pill on the slate: "hear this page".
///
/// Hidden outright when there is no clip or narration is switched off — a
/// button that does nothing is worse than no button.
class _BoardListenChip extends StatelessWidget {
  const _BoardListenChip({required this.clipId, required this.label});

  final String clipId;
  final String label;

  @override
  Widget build(BuildContext context) {
    final audio = AudioScope.maybeOf(context);
    if (audio == null || !audio.canPlay(clipId)) return const SizedBox.shrink();
    final playing = audio.isPlaying(clipId);
    Future<void> toggle() async {
      final started = await audio.toggle(clipId);
      if (!started && context.mounted) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Could not play this audio'),
            duration: Duration(seconds: 2),
          ));
      }
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(
          minWidth: AccessibleLayout.minTouchTarget,
          minHeight: AccessibleLayout.minTouchTarget),
      child: Semantics(
        container: true,
        button: true,
        label: label,
        toggled: playing,
        onTap: toggle,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: playing
                ? [
                    BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.22),
                        blurRadius: 10)
                  ]
                : null,
          ),
          child: OutlinedButton.icon(
            onPressed: toggle,
            icon: Icon(
                playing ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
                size: 16),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.square(AccessibleLayout.minTouchTarget),
              visualDensity: VisualDensity.standard,
              foregroundColor: playing ? AppColors.accent : Colors.white,
              backgroundColor: Colors.black.withValues(alpha: 0.20),
              side: BorderSide(
                  color: playing
                      ? AppColors.accent
                      : Colors.white.withValues(alpha: 0.54)),
              shape: const StadiumBorder(),
            ),
          ),
        ),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height * 0.55)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.surface);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ------------------------------------------------------------------- CTA -----

class _CtaBar extends StatelessWidget {
  const _CtaBar({
    required this.label,
    required this.icon,
    required this.onBack,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onBack;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00101E18), Color(0xFF101E18)],
          stops: [0.0, 0.55],
        ),
      ),
      child: Row(
        children: [
          if (onBack != null) ...[
            IconButton.outlined(
              tooltip: 'Previous page',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                minimumSize: const Size.square(AccessibleLayout.minTouchTarget),
                visualDensity: VisualDensity.standard,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.65)),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.button)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: AppButton(
              label: label,
              icon: icon,
              variant: AppButtonVariant.primary,
              onPressed: onPressed,
            ),
          ),
        ],
      ),
    );
  }
}
