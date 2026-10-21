import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/progress_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';

/// Rewards tab — streak, coins, XP and lightweight achievements.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.watch<ProgressController>().progress;

    final achievements = [
      (
        icon: Icons.auto_stories_rounded,
        title: 'First Chapter',
        detail: 'Complete your first chapter',
        earned: p.completedChapterCount >= 1,
      ),
      (
        icon: Icons.local_fire_department_rounded,
        title: '3-Day Streak',
        detail: 'Study three days in a row',
        earned: p.streakDays >= 3,
      ),
      (
        icon: Icons.star_rounded,
        title: 'Star Collector',
        detail: 'Earn 6 stars in total',
        earned: p.chapters.values.fold<int>(0, (s, c) => s + c.stars) >= 6,
      ),
      (
        icon: Icons.emoji_events_rounded,
        title: 'Grammar Explorer',
        detail: 'Reach level 3',
        earned: p.level >= 3,
      ),
    ];

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Rewards', style: text.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.rewardGradient),
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BigStat(
                    icon: Icons.monetization_on_rounded,
                    value: '${p.coins}',
                    label: 'Coins'),
                _BigStat(
                    icon: Icons.local_fire_department_rounded,
                    value: '${p.streakDays}',
                    label: 'Day Streak'),
                _BigStat(
                    icon: Icons.military_tech_rounded,
                    value: '${p.totalXp}',
                    label: 'Total XP'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Achievements', style: text.titleMedium),
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
        Text(value,
            style: text.titleLarge?.copyWith(color: AppColors.textPrimary)),
        Text(label,
            style: text.bodyMedium?.copyWith(color: AppColors.textPrimary)),
      ],
    );
  }
}
