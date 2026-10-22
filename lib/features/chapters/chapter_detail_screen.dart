import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../story/story_screen.dart';

/// Screen 17 — chapter intro: what it is, what you will learn, and one way in.
///
/// The hero keeps the artwork's own 1376 × 768 ratio instead of being stretched
/// over the whole screen: a full-bleed cover crop sliced both characters'
/// faces in half on every phone. The sheet below scrolls, and the CTA is
/// pinned outside the scroll — a fixed-height `Column` with a `Spacer` (the old
/// layout) overflowed by 368 px at 353 dp.
class ChapterDetailScreen extends StatelessWidget {
  const ChapterDetailScreen({super.key, required this.chapterId});

  static const routeName = '/chapter-detail';

  final String chapterId;

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentController>();
    final progress = context.watch<ProgressController>();
    final chapter = content.byId(chapterId);

    if (chapter == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Chapter not found')),
      );
    }

    final record = progress.chapterProgress(chapterId);
    final resume = record.resumeSceneIndex ?? 0;
    final number = content.chapters.indexOf(chapter) + 1;
    final started = record.started && !record.completed;

    return Scaffold(
      // Surface, not background: the sheet is nudged up 24 dp to overlap the
      // hero, which would otherwise leave a pale strip along the bottom edge.
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _Hero(
            title: chapter.title.en,
            number: number,
            stars: record.stars,
            completed: record.completed,
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadii.sheet),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 24,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                        child: _SheetBody(
                          number: number,
                          chapterTitle: chapter.title.en,
                          grammarTopic: chapter.grammarTopic.en,
                          sceneCount: chapter.scenes.length,
                          quizCount: chapter.quiz.length,
                          bestScore: record.bestScorePercent,
                          completed: record.completed,
                          inProgress: started,
                          resumeStep: resume + 1,
                        ),
                      ),
                    ),
                    _CtaBar(
                      label: started
                          ? 'Resume'
                          : record.completed
                              ? 'Play again'
                              : 'Start',
                      onPressed: () => Navigator.of(context).pushNamed(
                        StoryScreen.routeName,
                        arguments: StoryArgs(chapterId, startScene: resume),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.number,
    required this.stars,
    required this.completed,
  });

  final String title;
  final int number;
  final int stars;
  final bool completed;

  /// The artwork is 1376 × 768; laying it out at its own ratio means nothing
  /// is cropped away.
  static const _aspect = 1376 / 768;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _aspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/illustrations/chapter_detail_hero.webp',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: AppColors.skyTop,
            ),
          ),
          // Scrim under the caption. It starts higher than the text does:
          // white type over a sunlit roof and a white shirt needs real depth,
          // not a 25 % wash.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0, 0.10),
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00000000),
                  Color(0x73000000),
                  Color(0xCC000000),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          // Chapter identity lives in the top row, with the back button. It used
          // to sit at the bottom of the artwork, on top of a face.
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  _CircleButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  if (completed && stars > 0)
                    StarsDisplay(count: stars, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    this.color = Colors.white,
    this.onLight = false,
    this.icon,
  });

  final String label;
  final Color color;

  /// True when the pill sits on the sheet rather than on artwork: dark type on
  /// a tinted fill instead of white on a translucent one.
  final bool onLight;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = onLight ? color : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onLight
            ? color.withValues(alpha: 0.12)
            : color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border:
            Border.all(color: color.withValues(alpha: onLight ? 0.3 : 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
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
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: const Color(0x33000000),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 20, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.number,
    required this.chapterTitle,
    required this.grammarTopic,
    required this.sceneCount,
    required this.quizCount,
    required this.bestScore,
    required this.completed,
    required this.inProgress,
    required this.resumeStep,
  });

  final int number;
  final String chapterTitle;
  final String grammarTopic;
  final int sceneCount;
  final int quizCount;
  final int bestScore;
  final bool completed;
  final bool inProgress;
  final int resumeStep;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The sheet opens with the chapter it belongs to. It used to open with
        // the grammar chip over the hero's title, so the first thing read was
        // the least important thing on the screen.
        Row(
          children: [
            _Pill(
              label: 'CHAPTER $number',
              color: AppColors.primary,
              onLight: true,
            ),
            if (completed) ...[
              const SizedBox(width: AppSpacing.sm),
              _Pill(
                label: 'COMPLETED',
                color: AppColors.success,
                onLight: true,
                icon: Icons.check_rounded,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          chapterTitle,
          style: text.displaySmall?.copyWith(fontSize: 30, height: 1.15),
        ),
        const SizedBox(height: 6),
        Text(
          completed
              ? 'Finished — replay the story or beat your best score.'
              : inProgress
                  ? 'You are on step $resumeStep. Pick up where you left off.'
                  : 'A short story, one grammar point, and five questions.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        // What the learner is about to practise, in their own language of
        // progress: one grammar point, not a description of the app.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadii.card - 4),
            border: Border.all(color: const Color(0xFFD8E6FB)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: const Icon(Icons.school_rounded,
                    size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GRAMMAR FOCUS',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      grammarTopic,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text("What's inside", style: text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        _StepRow(
          icon: Icons.auto_stories_rounded,
          color: AppColors.primary,
          title: 'Story',
          detail: '$sceneCount scenes',
          status: inProgress ? 'Step $resumeStep' : null,
        ),
        _StepRow(
          icon: Icons.school_rounded,
          color: AppColors.success,
          title: 'Grammar lesson',
          detail: 'Rules & examples',
          status: null,
        ),
        _StepRow(
          icon: Icons.quiz_rounded,
          color: AppColors.accentDark,
          title: 'Quiz',
          detail: '$quizCount questions',
          status: completed
              ? 'Best $bestScore%'
              : inProgress
                  ? 'Unlocks at the end'
                  : null,
          trailingStars: completed ? 3 : 0,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Icon(Icons.info_outline_rounded,
                size: 14, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Rahul and Priya practise this grammar point as the chapter '
                'unfolds — read the story, then answer the quiz.',
                style: text.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    this.status,
    this.trailingStars = 0,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final String? status;
  final int trailingStars;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: text.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )),
                Text(detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        text.bodySmall?.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          if (trailingStars > 0) StarsDisplay(count: trailingStars, size: 15),
          if (status != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.backgroundAlt,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status!,
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pinned CTA — outside the scroll view, so it can never be pushed off screen.
class _CtaBar extends StatelessWidget {
  const _CtaBar({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg + 6,
            AppSpacing.lg,
            AppSpacing.md + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 18,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: AppButton(
            label: label,
            icon: Icons.play_arrow_rounded,
            variant: AppButtonVariant.primary,
            onPressed: onPressed,
          ),
        ),
        // A short fade above the bar: without it the last paragraph is sliced
        // mid-sentence by a hard edge and reads as a layout bug.
        Positioned(
          left: 0,
          right: 0,
          top: -26,
          height: 26,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00FFFFFF), AppColors.surface],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
