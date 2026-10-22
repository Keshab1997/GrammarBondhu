import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/asset_images.dart';
import '../../data/models/chapter.dart';
import '../chapters/chapter_list_screen.dart';
import '../grammar/grammar_lesson_screen.dart';
import '../progress/progress_screen.dart';
import '../quiz/quiz_screen.dart';
import '../settings/settings_screen.dart';
import '../story/story_screen.dart';

/// Screen 6 — continue journey, quick actions, progress, daily goal.
///
/// The dashboard is deliberately built from *flexible* pieces: greeting,
/// chapter title, stat pills and goal numbers all shrink or ellipsize. On the
/// narrow phones this app targets (320–360 dp) a fixed-width row overflows by
/// a few pixels and the row turns into the black-and-yellow overflow stripes.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentController>();
    final progress = context.watch<ProgressController>();
    final settings = context.watch<SettingsController>();

    final chapters = content.chapters;
    final currentId = progress.recommendedChapterId(chapters);
    final current = content.byId(currentId);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, 108),
        children: [
          _Header(name: settings.greetingName),
          const SizedBox(height: AppSpacing.lg),
          if (current != null)
            _ContinueCard(chapter: current, chapters: chapters),
          const SizedBox(height: AppSpacing.lg),
          _QuickActions(current: current),
          const SizedBox(height: AppSpacing.lg),
          if (current != null)
            _ProgressCard(
              chapterTitle: current.title.en,
              step: progress.chapterProgress(current.id).resumeSceneIndex ?? 0,
              steps: current.scenes.length + 1,
              value: chapters.isEmpty
                  ? 0
                  : progress.progress.completedChapterCount / chapters.length,
              completedChapters: progress.progress.completedChapterCount,
              totalChapters: chapters.length,
            ),
          const SizedBox(height: AppSpacing.md),
          _DailyGoalCard(
            done: progress.progress.questionsAnsweredToday,
            target: progress.progress.dailyGoalQuestions,
          ),
        ],
      ),
    );
  }
}

/// Greeting, avatar and the coins/settings toolbar.
///
/// Everything after the avatar is either [Expanded] or [Flexible]: the old
/// fixed-width greeting column pushed the toolbar off-screen by ~8 px on a
/// 353 dp device, swallowing the motivational line.
class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final coins = context.watch<ProgressController>().progress.coins;
    return Row(
      children: [
        // Avatar with the brand gradient ring.
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: AppShadows.cardSoft,
          ),
          child: ClipOval(
            child: SizedBox(
              width: 46,
              height: 46,
              child: Image.asset(
                'assets/illustrations/progress_avatar.webp',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.primary,
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $name!',
                style: text.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.favorite_rounded,
                      size: 13, color: AppColors.error),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      // Short enough to survive a 320 dp header: the old line
                      // was ellipsized on every phone in the target range.
                      "You're doing great!",
                      style: text.bodySmall?.copyWith(
                          color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _HeaderToolbar(coins: coins),
      ],
    );
  }
}

/// One rounded toolbar holding the coin counter and the settings button —
/// two separate pills cost ~12 px of header width and two competing shadows.
class _HeaderToolbar extends StatelessWidget {
  const _HeaderToolbar({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.chip + 4),
        boxShadow: AppShadows.cardSoft,
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.goldTop, AppColors.accent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(AppRadii.chip),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on_rounded,
                    size: 15, color: AppColors.accentDeep),
                const SizedBox(width: 4),
                Text(
                  '$coins',
                  maxLines: 1,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          _ToolbarButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: () =>
                Navigator.of(context).pushNamed(SettingsScreen.routeName),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 21, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// Blue hero card: the next chapter, its artwork and one full-width CTA.
///
/// The CTA spans the card instead of sitting under the text: at 320 dp the
/// left column is too narrow for a button *and* a thumbnail, and the old
/// arrangement left a dead corner under the title.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.chapter, required this.chapters});

  final Chapter chapter;
  final List<Chapter> chapters;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final progress = context.watch<ProgressController>();
    final record = progress.chapterProgress(chapter.id);
    final number = chapters.indexOf(chapter) + 1;
    final steps = chapter.scenes.length + 1;
    final resume = record.resumeSceneIndex ?? 0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary, AppColors.skyTop],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.card + 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.34),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card + 2),
        child: Stack(
          children: [
            // Soft light blooms — they give the flat gradient some depth.
            Positioned(
              top: -46,
              right: -30,
              child: _Bloom(size: 150, opacity: 0.16),
            ),
            Positioned(
              bottom: -60,
              left: -28,
              child: _Bloom(size: 130, opacity: 0.10),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.20),
                                borderRadius:
                                    BorderRadius.circular(AppRadii.chip),
                              ),
                              child: Text(
                                record.started
                                    ? 'Continue Your Journey'
                                    : 'Start Your Journey',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm + 2),
                            Text(
                              'Chapter $number',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              chapter.title.en,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(AppRadii.card - 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ChapterThumbnail(
                          assetPath: chapter.thumbnailAsset,
                          fallbackIcon: Icons.auto_stories_rounded,
                          size: 100,
                          radius: AppRadii.card - 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  Row(
                    children: [
                      Icon(
                        record.started
                            ? Icons.play_circle_outline_rounded
                            : Icons.list_alt_rounded,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          record.started
                              ? 'Step ${resume + 1} of $steps'
                              : '$steps steps · story + quiz',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: record.started ? 'Continue' : 'Start',
                    icon: Icons.play_arrow_rounded,
                    variant: AppButtonVariant.primary,
                    onPressed: () {
                      Navigator.of(context).pushNamed(
                        StoryScreen.routeName,
                        arguments: StoryArgs(chapter.id, startScene: resume),
                      );
                    },
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

class _Bloom extends StatelessWidget {
  const _Bloom({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.current});

  final Chapter? current;

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.menu_book_rounded,
        label: 'Chapters',
        color: AppColors.primary,
        onTap: () =>
            Navigator.of(context).pushNamed(ChapterListScreen.routeName),
      ),
      _QuickAction(
        icon: Icons.school_rounded,
        label: 'Grammar',
        color: AppColors.success,
        onTap: current == null
            ? null
            : () => Navigator.of(context).pushNamed(
                  GrammarLessonScreen.routeName,
                  arguments: current!.id,
                ),
      ),
      _QuickAction(
        icon: Icons.quiz_rounded,
        label: 'Quiz',
        color: AppColors.accentDark,
        onTap: current == null
            ? null
            : () => Navigator.of(context).pushNamed(
                  QuizScreen.routeName,
                  arguments: current!.id,
                ),
      ),
      _QuickAction(
        icon: Icons.insights_rounded,
        label: 'Progress',
        color: AppColors.purpleTop,
        onTap: () => Navigator.of(context).pushNamed(ProgressScreen.routeName),
      ),
    ];

    // Equal columns keep the four buttons on an exact grid at every width;
    // spaceBetween sized them from their labels and drifted at 320 dp.
    return Row(
      children: [
        for (final action in actions)
          Expanded(child: _ActionChip(action: action)),
      ],
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final disabled = action.onTap == null;
    final color = disabled ? AppColors.textMuted : action.color;

    return Semantics(
      button: true,
      enabled: !disabled,
      label: action.label,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxs, vertical: AppSpacing.xs),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md - 1),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: disabled ? 0.12 : 0.20),
                      color.withValues(alpha: disabled ? 0.05 : 0.07),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: disabled
                      ? null
                      : [
                          BoxShadow(
                            color: color.withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                ),
                child: Icon(action.icon, color: color, size: 26),
              ),
              const SizedBox(height: 7),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: disabled ? AppColors.textMuted : AppColors.textPrimary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chapter progress: what is in flight, how far along it is.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.chapterTitle,
    required this.step,
    required this.steps,
    required this.value,
    required this.completedChapters,
    required this.totalChapters,
  });

  final String chapterTitle;
  final int step;
  final int steps;
  final double value;
  final int completedChapters;
  final int totalChapters;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final percent = (value * 100).round();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: const Icon(Icons.trending_up_rounded,
                    color: AppColors.primary, size: 19),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Progress',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall),
                    const SizedBox(height: 1),
                    Text(
                      chapterTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          text.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: Text(
                  '$step/$steps',
                  maxLines: 1,
                  style: text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md - 2),
          AppProgressBar(
            value: step / steps,
            height: 10,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.skyTop],
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            children: [
              Flexible(
                child: Text(
                  '$percent% complete',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  '$completedChapters of $totalChapters chapters',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: text.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Warm daily-goal card with a full-width bar so the target reads at a glance.
class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({required this.done, required this.target});

  final int done;
  final int target;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pct = target == 0 ? 0.0 : (done / target).clamp(0.0, 1.0);
    final remaining = (target - done).clamp(0, target);

    return AppCard(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFF7E2), Color(0xFFFFE3B8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      elevation: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.warning, AppColors.accentDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentDark.withValues(alpha: 0.42),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.local_fire_department_rounded,
                    size: 24, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Goal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Complete $target quiz questions today',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          text.bodySmall?.copyWith(color: AppColors.accentDeep),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$done/$target',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(
                  color: AppColors.accentDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md - 2),
          AppProgressBar(
            value: pct,
            height: 10,
            color: AppColors.accentDark,
            trackColor: Colors.white.withValues(alpha: 0.85),
            gradient: const LinearGradient(
              colors: [AppColors.accent, AppColors.accentDark],
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text(
            remaining == 0
                ? 'Goal complete — nicely done!'
                : '$remaining more to reach today\'s goal',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(
              color: AppColors.accentDeep,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
