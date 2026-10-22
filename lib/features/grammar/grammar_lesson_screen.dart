import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/idle_motion.dart';
import '../../data/models/chapter.dart';
import '../quiz/quiz_screen.dart';

/// Screen 10 — the grammar lesson, staged as a moment in class.
///
/// It used to be a white card: a title, a paragraph, a list of examples and a
/// round avatar in the corner — a document with a picture on it. A learner
/// opening "the grammar lesson" expects to be *taught*, so the rule is written
/// on a board that the teacher is standing in front of, the examples are chalk
/// lines under it, and the sentence in the learner's own language comes out of
/// the teacher's mouth rather than out of a paragraph.
class GrammarLessonScreen extends StatefulWidget {
  const GrammarLessonScreen({super.key, required this.chapterId});

  static const routeName = '/lesson';

  final String chapterId;

  @override
  State<GrammarLessonScreen> createState() => _GrammarLessonScreenState();
}

class _GrammarLessonScreenState extends State<GrammarLessonScreen>
    with SingleTickerProviderStateMixin {
  /// Drives the chalk reveal: the rule is "written" line by line when the
  /// screen opens, which is what sells the board as a board.
  late final AnimationController _chalk = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));

  @override
  void initState() {
    super.initState();
    _chalk.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _chalk.value = 1;
    }
  }

  @override
  void dispose() {
    _chalk.dispose();
    super.dispose();
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

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A24),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _ClassroomWall(),

          // The wall the board hangs on, then the board, then the person
          // standing in front of it.
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _TopBar(
                    chapter: chapter,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.sm, 0, AppSpacing.sm, 0),
                      child: _Board(
                        lesson: lesson,
                        lang: lang,
                        progress: _chalk,
                      ),
                    ),
                  ),
                  // Room for the teacher, who stands in front of the board and
                  // is cropped by the CTA bar rather than floating above it.
                  SizedBox(height: _teacherLane(context)),
                ],
              ),
            ),
          ),

          // The teacher herself: full body, on the right, feet behind the CTA.
          Positioned(
            right: -10,
            bottom: _ctaHeight(context) - 40,
            height: _teacherHeight(context),
            child: const IdleBob(period: 4600, child: _Teacher()),
          ),

          // What she is saying, in the learner's own language.
          Positioned(
            left: AppSpacing.md,
            right: _teacherWidth(context) * 0.55,
            bottom: _ctaHeight(context) + 6,
            child: _TeacherSays(text: _teacherLine(lang, lesson)),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _CtaBar(
              onPressed: () => Navigator.of(context).pushNamed(
                QuizScreen.routeName,
                arguments: widget.chapterId,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Height reserved so the board stops at the teacher's hairline instead of
  /// running underneath her.
  static double _teacherLane(BuildContext context) =>
      MediaQuery.sizeOf(context).height * 0.34;

  static double _teacherHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height * 0.46;

  /// Where the CTA bar starts, so the bubble and the teacher can sit above it.
  static double _ctaHeight(BuildContext context) =>
      92 + MediaQuery.paddingOf(context).bottom;

  static double _teacherWidth(BuildContext context) =>
      _teacherHeight(context) * 0.34;

  /// One sentence, in the language the learner reads in. The explanation itself
  /// is long — that belongs on the board; this is the teacher pointing at it.
  static String _teacherLine(String lang, GrammarLesson lesson) {
    switch (lang) {
      case 'hi':
        return 'यह नियम बोर्ड पर लिखा है। नीचे के उदाहरण पढ़ो और खुद बोलकर देखो।';
      case 'en':
        return 'The rule is on the board. Read the examples under it and say '
            'each one out loud.';
      default:
        return 'নিয়মটা বোর্ডে লিখেছি। নিচের উদাহরণগুলো পড়ে জোরে বলে দেখো।';
    }
  }
}

// ---------------------------------------------------------------- the room ---

/// The classroom wall behind the board: the room plate, darkened and slightly
/// blurred so the board (and the person in front of it) own the frame.
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
              colors: [
                Color(0xCC0F172A),
                Color(0x990F172A),
                Color(0xE6101E18),
              ],
              stops: [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.chapter, required this.onBack});

  final Chapter chapter;
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
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'IN CLASS',
              style: TextStyle(
                color: Color(0xFF4A3410),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ],
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
/// the rule written on it in chalk.
class _Board extends StatelessWidget {
  const _Board({
    required this.lesson,
    required this.lang,
    required this.progress,
  });

  final GrammarLesson lesson;
  final String lang;
  final Animation<double> progress;

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
      child: Stack(
        children: [
          // The slate itself.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: const LinearGradient(
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
                  borderRadius: BorderRadius.circular(9),
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: _BoardContent(
                lesson: lesson,
                lang: lang,
                progress: progress,
              ),
            ),
          ),
          // Chalk tray with a couple of sticks and an eraser.
          const Positioned(
            left: 10,
            right: 10,
            bottom: -3,
            child: _ChalkTray(),
          ),
        ],
      ),
    );
  }
}

class _BoardContent extends StatelessWidget {
  const _BoardContent({
    required this.lesson,
    required this.lang,
    required this.progress,
  });

  final GrammarLesson lesson;
  final String lang;
  final Animation<double> progress;

  /// Chalk: soft white, a faint halo so it sits on the slate, and a hint of
  /// dust under the strokes.
  static TextStyle chalk(double size,
      {double alpha = 0.94, FontWeight w = FontWeight.w600}) {
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
    // Each block is written in turn: title, rule, then one line per example.
    final lines = <Widget>[
      _ChalkLine(
        progress: progress,
        from: 0.00,
        to: 0.22,
        child: Text('TODAY’S RULE',
            style: chalk(11, alpha: 0.55, w: FontWeight.w800)),
      ),
      _ChalkLine(
        progress: progress,
        from: 0.12,
        to: 0.40,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lesson.title.en, style: chalk(26, w: FontWeight.w700)),
            const SizedBox(height: 6),
            // The underline is drawn, not printed — a teacher's stroke.
            _ChalkUnderline(progress: progress, from: 0.30, to: 0.50),
          ],
        ),
      ),
      _ChalkLine(
        progress: progress,
        from: 0.42,
        to: 0.66,
        child: Text(lesson.explanation.en, style: chalk(14.5, alpha: 0.88)),
      ),
      _ChalkLine(
        progress: progress,
        from: 0.56,
        to: 0.66,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.16),
          ),
        ),
      ),
      for (var i = 0; i < lesson.examples.length; i++)
        _ChalkLine(
          progress: progress,
          from: 0.62 + i * 0.09,
          to: 0.78 + i * 0.09,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
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
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines,
      ),
    );
  }
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

class _ChalkTray extends StatelessWidget {
  const _ChalkTray();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 9,
          decoration: BoxDecoration(
            color: const Color(0xFF6B4226),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 26, right: 20),
          child: Row(
            children: [
              _stick(const Color(0xFFF4EFE6), 30),
              const SizedBox(width: 6),
              _stick(const Color(0xFFF7E7A6), 20),
              const SizedBox(width: 6),
              _stick(const Color(0xFFEFC9C9), 14),
              const Spacer(),
              // Eraser, sitting where a teacher would leave it.
              Container(
                width: 46,
                height: 11,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2.5),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3E6B8C), Color(0xFF2C4E68)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stick(Color color, double width) => Container(
        width: width,
        height: 6,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      );
}

// ------------------------------------------------------------- the teacher ---

class _Teacher extends StatelessWidget {
  const _Teacher();

  @override
  Widget build(BuildContext context) {
    // The standee is already sized by the Positioned that holds it.
    return Image.asset(
      'assets/characters/teacher_full.webp',
      fit: BoxFit.contain,
      alignment: Alignment.bottomRight,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

class _TeacherSays extends StatelessWidget {
  const _TeacherSays({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                  color: Colors.black.withValues(alpha: 0.25),
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
                  ],
                ),
                const SizedBox(height: 4),
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
        // Tail, pointing at her.
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: CustomPaint(
            size: const Size(16, 20),
            painter: _TailPainter(),
          ),
        ),
      ],
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
  const _CtaBar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0x00101E18),
            const Color(0xE6101E18),
            const Color(0xFF101E18),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: AppButton(
        label: 'Start the quiz',
        icon: Icons.quiz_rounded,
        variant: AppButtonVariant.primary,
        onPressed: onPressed,
      ),
    );
  }
}
