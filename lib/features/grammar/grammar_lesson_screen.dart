import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/idle_motion.dart';
import '../../core/widgets/listen_button.dart';
import '../audio/audio_controller.dart';
import '../../data/models/chapter.dart';
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
    with SingleTickerProviderStateMixin {
  /// The board is written, not rendered: each page sweeps in line by line.
  late final AnimationController _chalk = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  int _page = 0;

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audio = AudioScope.maybeOf(context);
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _chalk.value = 1;
    }
  }

  @override
  void dispose() {
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
    setState(
        () => _page = (_page + (forward ? 1 : -1)).clamp(0, _pageCount - 1));
    _chalk
      ..reset()
      ..forward();
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
    final lesson = chapter.lesson;
    final lang = settings.supportLanguage;
    final boardLang = _boardInSupportLanguage ? lang : 'en';

    return Scaffold(
      backgroundColor: const Color(0xFF16241E),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final ctaTop = _ctaHeight(context);
          final teacherHeight = h * 0.40;
          final teacherWidth = teacherHeight * _teacherAspect;

          return Stack(
            fit: StackFit.expand,
            children: [
              const _ClassroomWall(),

              // The board, full width, standing behind the teacher.
              Positioned(
                left: AppSpacing.sm + 4,
                right: AppSpacing.sm + 4,
                top: MediaQuery.paddingOf(context).top + 64,
                bottom: ctaTop + 8,
                child: _Board(
                  page: _page,
                  pageCount: _pageCount,
                  // Text keeps clear of the body standing in front of it.
                  contentBottomInset: teacherHeight * 0.85,
                  lesson: lesson,
                  lang: boardLang,
                  progress: _chalk,
                  audioClipId: switch (_page) {
                    // The rule is read in the board's own language; the
                    // examples are always English, because that is the
                    // sentence being taught; the last page is the learner's
                    // turn, so the teacher speaks instead.
                    0 => 'board_${widget.chapterId}_explain_$boardLang',
                    1 => 'board_${widget.chapterId}_examples_en',
                    _ => null,
                  },
                ),
              ),

              // Those little things a classroom is made of.
              Positioned(
                left: AppSpacing.sm + 4,
                right: AppSpacing.sm + 4,
                top: MediaQuery.paddingOf(context).top,
                child: _TopBar(
                  chapter: chapter,
                  boardLang: boardLang,
                  onToggleLanguage: () => setState(
                      () => _boardInSupportLanguage = !_boardInSupportLanguage),
                  onBack: () => Navigator.of(context).maybePop(),
                ),
              ),

              // Mrs. Sen, in front of the board, pointer across it.
              // A pose per page — pointing, explaining from the book, then
              // inviting the learner to try — cross-faded so she moves rather
              // than teleports.
              Positioned(
                right: -14,
                bottom: ctaTop - 6,
                height: teacherHeight,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.bottomRight,
                    children: [...previous, if (current != null) current],
                  ),
                  child: IdleBob(
                    key: ValueKey(_page),
                    period: 5000,
                    amplitude: 0.005,
                    child: _Teacher(pose: _poses[_page % _poses.length]),
                  ),
                ),
              ),

              // What she is saying about the page that is up.
              Positioned(
                left: AppSpacing.md,
                right: teacherWidth * 0.52,
                bottom: ctaTop + 10,
                child: _TeacherSays(
                  text: _teacherLine(boardLang, _page),
                  clipId: 'teach_${_page + 1}_$boardLang',
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _CtaBar(
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
                      arguments: widget.chapterId,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static double _ctaHeight(BuildContext context) =>
      88 + MediaQuery.paddingOf(context).bottom;

  /// One standee per page: pointer on the rule, book while reading the
  /// examples, open palms for "your turn".
  static const List<TeacherPose> _poses = [
    TeacherPose('assets/characters/teacher_pointer.webp', 479 / 703),
    TeacherPose('assets/characters/teacher_book.webp', 428 / 714),
    TeacherPose('assets/characters/teacher_invite.webp', 328 / 708),
  ];

  /// Standee aspect of the pose on the current page.
  static const double _teacherAspect = 479 / 703;

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          _GlassButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grammar lesson',
                  style: text.titleMedium?.copyWith(color: Colors.white),
                ),
                Text(
                  chapter.title.en,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          // The board's language. Small, one tap, and it never hides the rule:
          // English stays the default, the support script is opt-in.
          _LanguagePill(
            boardLang: boardLang,
            onTap: onToggleLanguage,
          ),
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
    final label =
        boardLang == 'en' ? (support == 'hi' ? 'हिन्दी' : 'বাংলা') : 'EN';
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
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
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
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
    required this.contentBottomInset,
    required this.lesson,
    required this.lang,
    required this.progress,
    required this.audioClipId,
  });

  final int page;
  final int pageCount;
  final double contentBottomInset;
  final GrammarLesson lesson;
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
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2F4B3C), Color(0xFF21362C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Chalk haze: corners are never evenly erased.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.4, -0.6),
                      radius: 1.1,
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                // The teacher stands in the lower right of the slate, so the
                // chalk stops above her head rather than beside it.
                padding:
                    EdgeInsets.fromLTRB(16, 14, 16, 12 + contentBottomInset),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  // Switcher children centre themselves; the chalk belongs at
                  // the top of the slate, where a teacher starts writing.
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topLeft,
                    children: [...previous, if (current != null) current],
                  ),
                  child: _BoardPage(
                    key: ValueKey(page),
                    page: page,
                    lesson: lesson,
                    lang: lang,
                    progress: progress,
                  ),
                ),
              ),
            ),
            // Chalk dots: how far through the lesson you are.
            Positioned(
              right: 14,
              top: 12,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      _pageLabel,
                      style: const TextStyle(
                        color: Color(0x99FFFFFF),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // "Hear it" sits on the lower-left of the slate, at the edge of
            // the area reserved for the teacher — above her speech bubble,
            // and below the last chalk line, so it covers neither.
            if (audioClipId != null)
              Positioned(
                left: 14,
                bottom: (contentBottomInset - 30).clamp(12.0, 240.0),
                child: _BoardListenChip(
                  clipId: audioClipId!,
                  label: switch (lang) {
                    'bn' => 'শুনে নাও',
                    'hi' => 'सुनकर देखो',
                    _ => 'Hear it',
                  },
                ),
              ),
            Positioned(
              right: 14,
              top: 30,
              child: Row(
                children: [
                  for (var i = 0; i < pageCount; i++)
                    Container(
                      width: i == page ? 16 : 7,
                      height: 7,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: i == page ? 0.85 : 0.28),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One page of the board. Each block is written in turn as the sweep runs.
class _BoardPage extends StatelessWidget {
  const _BoardPage({
    super.key,
    required this.page,
    required this.lesson,
    required this.lang,
    required this.progress,
  });

  final int page;
  final GrammarLesson lesson;
  final String lang;
  final Animation<double> progress;

  static TextStyle chalk(
    double size, {
    double alpha = 0.94,
    FontWeight w = FontWeight.w600,
  }) {
    return TextStyle(
      fontSize: size,
      height: 1.35,
      color: Colors.white.withValues(alpha: alpha),
      fontWeight: w,
      letterSpacing: 0.2,
      shadows: [
        Shadow(color: Colors.white.withValues(alpha: 0.35), blurRadius: 6),
        const Shadow(
            color: Color(0x66000000), blurRadius: 1, offset: Offset(0, 1)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _ChalkLine(
        progress: progress,
        from: 0.0,
        to: 0.25,
        child: Text(_kicker, style: chalk(11, alpha: 0.55, w: FontWeight.w800)),
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
                style: chalk(14.5, alpha: 0.88)),
          ),
        ),
        // The same rule as a table — how a teacher actually leaves it on the
        // board, and it fills the slate instead of trailing off into nothing.
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
                  Text('—', style: chalk(14, alpha: 0.4)),
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
                        size: 16, color: Colors.white.withValues(alpha: 0.55)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lesson.examples[i].sentence, style: chalk(15)),
                        if (lesson.examples[i].note.of(lang).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              lesson.examples[i].note.of(lang),
                              style: chalk(12, alpha: 0.55),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ]);
    } else {
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
              _t(
                'Fill the gap out loud, then check below.',
                'ফাঁকা জায়গাটা জোরে বলে ভরো, তারপর নিচে মিলিয়ে নাও।',
                'खाली जगह ज़ोर से बोलकर भरो, फिर नीचे मिलाओ।',
              ),
              style: chalk(13, alpha: 0.7),
            ),
          ),
        ),
        for (var i = 0; i < _gaps.length; i++)
          _ChalkLine(
            progress: progress,
            from: 0.35 + i * 0.14,
            to: 0.6 + i * 0.14,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '${i + 1}.  ${_gaps[i].$1}',
                style: chalk(15),
              ),
            ),
          ),
        _ChalkLine(
          progress: progress,
          from: 0.8,
          to: 1.0,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_answers, style: chalk(12, alpha: 0.5)),
          ),
        ),
      ]);
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
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

  /// Three gaps that only need the rule that was just taught.
  static final List<(String,)> _gaps = [
    ('I ___ a student.',),
    ('He ___ my friend.',),
    ('They ___ classmates.',),
  ];

  String get _answers => _t(
      'Answers: am · is · are', 'উত্তর: am · is · are', 'जवाब: am · is · are');

  /// Subject → verb, the three rows a teacher writes under the rule, with the
  /// subject in all three languages.
  static const List<(String, String, String, String)> _table = [
    ('I', 'am', 'আমি', 'मैं'),
    ('he / she / it', 'is', 'সে', 'वह'),
    ('you / we / they', 'are', 'তুমি / আমরা / তারা', 'तुम / हम / वे'),
  ];
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
    final curve = CurvedAnimation(
      parent: progress,
      curve: Interval(from.clamp(0, 1), to.clamp(0, 1), curve: Curves.easeOut),
    );
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
    final curve = CurvedAnimation(
      parent: progress,
      curve: Interval(from.clamp(0, 1), to.clamp(0, 1), curve: Curves.easeOut),
    );
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
  const TeacherPose(this.asset, this.aspect);

  final String asset;
  final double aspect;
}

class _Teacher extends StatelessWidget {
  const _Teacher({required this.pose});

  final TeacherPose pose;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      pose.asset,
      fit: BoxFit.contain,
      alignment: Alignment.bottomRight,
      filterQuality: FilterQuality.medium,
      // The pointer pose is new art; the plain standee keeps the screen usable
      // if the asset is ever missing.
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/characters/teacher_full.webp',
        fit: BoxFit.contain,
        alignment: Alignment.bottomRight,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
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
                Row(
                  children: [
                    const Icon(Icons.record_voice_over_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Mrs. Sen',
                      style: theme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    ListenButton(clipId: clipId, size: 26),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final started = await audio.toggle(clipId);
        if (!started && context.mounted) {
          ScaffoldMessenger.maybeOf(context)
            ?..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              content: Text('Could not play this audio'),
              duration: Duration(seconds: 2),
            ));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: playing ? 0.26 : 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              playing ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
              size: 13,
              color: Colors.white.withValues(alpha: 0.92),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
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
        AppSpacing.lg,
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
            SizedBox(
              width: 56,
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.35), width: 1.6),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                ),
                child: const Icon(Icons.arrow_back_rounded),
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
