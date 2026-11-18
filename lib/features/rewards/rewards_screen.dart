import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../story/story_screen.dart';

/// Rewards tab — streak, coins, XP and lightweight achievements.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key, this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.watch<ProgressController>().progress;
    final chapters = Provider.of<ContentController?>(context)?.chapters ?? [];
    final totalStars =
        p.chapters.values.fold<int>(0, (sum, c) => sum + c.stars);
    final xpIntoLevel = p.xpIntoLevel;
    final xpForNextLevel = xpIntoLevel + p.xpToNextLevel;

    final achievements = [
      (
        icon: Icons.auto_stories_rounded,
        title: 'First Chapter',
        detail: 'Complete your first chapter',
        earned: p.completedChapterCount >= 1,
      ),
      (
        icon: Icons.task_alt_rounded,
        title: 'Perfect Quiz',
        detail: 'Score 100% on any chapter quiz',
        earned: p.chapters.values
            .any((c) => c.completed && c.bestScorePercent >= 100),
      ),
      (
        icon: Icons.local_fire_department_rounded,
        title: '3-Day Streak',
        detail: 'Study three days in a row',
        earned: p.bestStreakDays >= 3,
      ),
      (
        icon: Icons.star_rounded,
        title: 'Star Collector',
        detail: 'Earn 6 stars in total',
        earned: totalStars >= 6,
      ),
      (
        icon: Icons.emoji_events_rounded,
        title: 'Grammar Explorer',
        detail: 'Reach level 3',
        earned: p.level >= 3,
      ),
      (
        icon: Icons.workspace_premium_rounded,
        title: 'English Champion',
        detail: 'Reach level 5',
        earned: p.level >= 5,
      ),
      (
        icon: Icons.flag_rounded,
        title: 'Story Finisher',
        detail: 'Complete every chapter in the course',
        earned: chapters.isNotEmpty &&
            chapters
                .every((chapter) => p.chapters[chapter.id]?.completed ?? false),
      ),
    ];
    final earnedCount = achievements.where((a) => a.earned).length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          108,
        ),
        children: [
          Text('Rewards', style: text.titleLarge),
          const SizedBox(height: AppSpacing.md),
          // A trophy above a row of zeroes reads as "nothing here, with paint
          // on top". Before the first chapter it is a door instead of a shelf.
          if (p.totalXp == 0 && p.completedChapterCount == 0)
            _StartHereCard()
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  'assets/illustrations/rewards_trophy.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient:
                          LinearGradient(colors: AppColors.rewardGradient),
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        size: 72, color: Colors.white),
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.rewardGradient),
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            // Three stats in a row fit at default type and overflow by 88 px
            // at 200%. Each stat takes an equal share and its label yields a
            // line before the row does.
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _BigStat(
                      icon: Icons.monetization_on_rounded,
                      value: '${p.coins}',
                      label: 'Coins'),
                ),
                Expanded(
                  child: _BigStat(
                      icon: Icons.local_fire_department_rounded,
                      value: '${p.activeStreakOn(now ?? DateTime.now())}',
                      label: 'Day Streak'),
                ),
                Expanded(
                  child: _BigStat(
                      icon: Icons.military_tech_rounded,
                      value: '${p.totalXp}',
                      label: 'Total XP'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Level progress',
                    style: text.labelLarge?.copyWith(color: AppColors.primary)),
                const SizedBox(height: AppSpacing.xs),
                Text('Level ${p.level} · ${p.levelTitle}',
                    style: text.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(
                  value: xpForNextLevel > 0
                      ? (xpIntoLevel / xpForNextLevel).clamp(0.0, 1.0)
                      : 0.0,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                  backgroundColor: AppColors.primarySoft,
                  color: AppColors.primary,
                  semanticsLabel: 'Level progress',
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('$xpIntoLevel / $xpForNextLevel XP to next level',
                    style: text.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Achievements', style: text.titleMedium),
              Text('$earnedCount of ${achievements.length} unlocked',
                  style: text.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final a in achievements)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: a.earned
                            ? AppColors.accent.withValues(alpha: 0.2)
                            : AppColors.primarySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        a.icon,
                        color: a.earned
                            ? AppColors.accentDark
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title, style: text.titleMedium),
                          Text(a.detail, style: text.bodyMedium),
                        ],
                      ),
                    ),
                    Icon(
                      a.earned
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: a.earned
                          ? AppColors.success
                          : AppColors.textSecondary,
                      semanticLabel: a.earned ? 'Unlocked' : 'Locked',
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat(
      {required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Icon(icon, color: AppColors.textPrimary, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: text.titleLarge?.copyWith(color: AppColors.textPrimary),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

/// Zero state for the rewards tab: one clear way in, and what waits behind the
/// first finished chapter.
class _StartHereCard extends StatelessWidget {
  const _StartHereCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.card),
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    color: AppColors.accent, size: 24),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  'Your first trophy is one chapter away',
                  style: text.titleLarge?.copyWith(
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Finish The New Student to bank coins, XP and your first badge. '
            'Every quiz answer counts toward the daily goal.',
            style: text.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Start chapter 1',
            icon: Icons.play_arrow_rounded,
            variant: AppButtonVariant.primary,
            onPressed: () => Navigator.of(context).pushNamed(
              StoryScreen.routeName,
              arguments: const StoryArgs('ch01'),
            ),
          ),
        ],
      ),
    );
  }
}
