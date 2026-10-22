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
    final text = Theme.of(context).textTheme;
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
          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned(
                  top: 8,
                  left: 8,
                  child: _CircleButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Pill(label: 'CHAPTER $number'),
                    if (completed) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _Pill(
                        label: 'COMPLETED',
                        color: AppColors.success,
                        icon: Icons.check_rounded,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    shadows: const [
                      Shadow(color: Color(0x66000000), blurRadius: 10),
                    ],
                  ),
                ),
                if (completed && stars > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  StarsDisplay(count: stars, size: 20),
                ],
              ],
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
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
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
    required this.chapterTitle,
    required this.grammarTopic,
    required this.sceneCount,
    required this.quizCount,
    required this.bestScore,
    required this.completed,
    required this.inProgress,
    required this.resumeStep,
  });

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
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFEFF3F9))),
      ),
      child: AppButton(
        label: label,
        icon: Icons.play_arrow_rounded,
        variant: AppButtonVariant.primary,
        onPressed: onPressed,
      ),
    );
  }
}
