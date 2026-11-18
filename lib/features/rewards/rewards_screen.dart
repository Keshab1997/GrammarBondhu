import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/accessible_layout.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/progress.dart';
import '../story/story_screen.dart';

/// Rewards tab — streak, coins, XP and lightweight achievements.
class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key, this.now, this.standalone = false});

  final DateTime? now;

  /// Add a scaffold and back action when opened outside the tab shell.
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = context.watch<ProgressController>().progress;
    final chapters = Provider.of<ContentController?>(context)?.chapters ?? [];
    final totalStars =
        p.chapters.values.fold<int>(0, (sum, c) => sum + c.stars);
    final bestQuiz = p.chapters.values.where((c) => c.completed).fold<int>(
        0, (best, c) => c.bestScorePercent > best ? c.bestScorePercent : best);
    final courseDone = chapters
        .where((chapter) => p.chapters[chapter.id]?.completed ?? false)
        .length;
    final xpIntoLevel = p.xpIntoLevel;
    final xpForNextLevel = xpIntoLevel + p.xpToNextLevel;

    // Level 1 starts at zero XP. Count partial XP, not just whole levels.
    double progressToLevel(int target) =>
        p.totalXp / ((target - 1) * UserProgress.xpPerLevel);

    final achievements = [
      _Achievement(
        icon: Icons.auto_stories_rounded,
        title: 'First Chapter',
        detail: 'Complete your first chapter',
        progress: p.completedChapterCount.toDouble(),
      ),
      _Achievement(
        icon: Icons.task_alt_rounded,
        title: 'Perfect Quiz',
        detail: 'Score 100% on any chapter quiz',
        progress: bestQuiz / 100,
      ),
      _Achievement(
        icon: Icons.local_fire_department_rounded,
        title: '3-Day Streak',
        detail: 'Study three days in a row',
        progress: p.bestStreakDays / 3,
      ),
      _Achievement(
        icon: Icons.star_rounded,
        title: 'Star Collector',
        detail: 'Earn 6 stars in total',
        progress: totalStars / 6,
      ),
      _Achievement(
        icon: Icons.emoji_events_rounded,
        title: 'Grammar Explorer',
        detail: 'Reach level 3',
        progress: progressToLevel(3),
      ),
      _Achievement(
        icon: Icons.workspace_premium_rounded,
        title: 'English Champion',
        detail: 'Reach level 5',
        progress: progressToLevel(5),
      ),
      _Achievement(
        icon: Icons.flag_rounded,
        title: 'Story Finisher',
        detail: 'Complete every chapter in the course',
        progress: chapters.isEmpty ? null : courseDone / chapters.length,
      ),
    ];
    final earnedCount = achievements.where((a) => a.earned).length;

    final body = SafeArea(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          standalone ? AppSpacing.lg : 108,
        ),
        children: [
          if (!standalone) ...[
            Text('Rewards', style: text.titleLarge),
            const SizedBox(height: AppSpacing.md),
          ],
          if (p.totalXp == 0 && p.completedChapterCount == 0)
            const _StartHereCard()
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  'assets/illustrations/rewards_trophy.webp',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                  errorBuilder: (_, __, ___) => const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [AppColors.accentSoft, AppColors.accent]),
                    ),
                    child: Icon(Icons.emoji_events_rounded,
                        size: 72, color: AppColors.accentDeep),
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          _RewardsStats(
            coins: p.coins,
            streak: p.activeStreakOn(now ?? DateTime.now()),
            xp: p.totalXp,
          ),
          const SizedBox(height: AppSpacing.md),
          _RewardsPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _RewardsPill(
                  label: 'Level progress',
                  tint: AppColors.primarySoft,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Level ${p.level} · ${p.levelTitle}',
                    style: text.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                LinearProgressIndicator(
                  value: xpForNextLevel > 0
                      ? (xpIntoLevel / xpForNextLevel).clamp(0.0, 1.0)
                      : 0.0,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                  backgroundColor: AppColors.primarySoft,
                  color: AppColors.primary,
                  semanticsLabel: 'Level progress',
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('$xpIntoLevel / $xpForNextLevel XP to next level',
                    style: text.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Achievements', style: text.titleLarge),
              _RewardsPill(
                label: '$earnedCount of ${achievements.length} unlocked',
                tint: AppColors.accentSoft,
                color: AppColors.textPrimary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final a in achievements)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _AchievementCard(achievement: a),
            ),
        ],
      ),
    );
    if (!standalone) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rewards'),
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          visualDensity: VisualDensity.standard,
          constraints: const BoxConstraints(
            minHeight: AccessibleLayout.minTouchTarget,
            minWidth: AccessibleLayout.minTouchTarget,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: body,
    );
  }
}

class _RewardsStats extends StatelessWidget {
  const _RewardsStats(
      {required this.coins, required this.streak, required this.xp});

  final int coins;
  final int streak;
  final int xp;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final stacked = AccessibleLayout.isCompact(context) ||
          constraints.maxWidth < 340 - 2 * AppSpacing.md;
      final stats = [
        _BigStat(
          icon: Icons.monetization_on_rounded,
          value: '$coins',
          label: 'Coins',
          tint: AppColors.accentSoft,
          color: AppColors.accentDeep,
          stacked: stacked,
        ),
        _BigStat(
          icon: Icons.local_fire_department_rounded,
          value: '$streak',
          label: 'Day Streak',
          tint: Color.alphaBlend(
              AppColors.warning.withValues(alpha: 0.14), AppColors.surface),
          color: AppColors.accentDeep,
          stacked: stacked,
        ),
        _BigStat(
          icon: Icons.military_tech_rounded,
          value: '$xp',
          label: 'Total XP',
          tint: AppColors.primarySoft,
          color: AppColors.primaryDark,
          stacked: stacked,
        ),
      ];
      return _RewardsPanel(
        child: stacked
            ? Column(children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0)
                    Divider(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      height: AppSpacing.md,
                    ),
                  stats[i],
                ],
              ])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final stat in stats) Expanded(child: stat)],
              ),
      );
    });
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.tint,
    required this.color,
    required this.stacked,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color tint;
  final Color color;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final align = stacked ? TextAlign.start : TextAlign.center;
    final badge = _RewardsMedallion(icon: icon, tint: tint, color: color);
    final count = Column(
      crossAxisAlignment:
          stacked ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(value,
            textAlign: align,
            style: text.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 26,
              height: 1.15,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
        const SizedBox(height: AppSpacing.xxs),
        Text(label,
            textAlign: align,
            style: text.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            )),
      ],
    );

    if (stacked) {
      return Row(children: [
        badge,
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(child: count),
      ]);
    }
    return Column(
        children: [badge, const SizedBox(height: AppSpacing.sm), count]);
  }
}

class _Achievement {
  const _Achievement({
    required this.icon,
    required this.title,
    required this.detail,
    required this.progress,
  });

  final IconData icon;
  final String title;
  final String detail;

  /// Null when the target is unknown, such as a course that has not loaded.
  final double? progress;

  bool get earned => (progress ?? 0) >= 1;
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement});

  final _Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final a = achievement;
    final earned = a.earned;
    final progress = a.progress;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: earned
            ? Color.lerp(AppColors.surface, AppColors.accentSoft, 0.35)!
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: earned
            ? Border.all(
                color: AppColors.accent.withValues(alpha: 0.55), width: 1.5)
            : Border.all(color: AppColors.textMuted.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          _RewardsMedallion(
            icon: a.icon,
            tint: earned ? AppColors.accentSoft : AppColors.background,
            color: earned ? AppColors.accentDeep : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.title,
                    style: text.titleMedium
                        ?.copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: AppSpacing.xxs),
                Text(a.detail,
                    style: text.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary)),
                if (!earned && progress != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    backgroundColor: AppColors.backgroundAlt,
                    color: AppColors.primary,
                    semanticsLabel: '${a.title} progress',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            earned ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            color: earned ? AppColors.successDark : AppColors.textSecondary,
            semanticLabel: earned ? 'Unlocked' : 'Locked',
          ),
        ],
      ),
    );
  }
}

class _RewardsMedallion extends StatelessWidget {
  const _RewardsMedallion(
      {required this.icon, required this.tint, required this.color});

  final IconData icon;
  final Color tint;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 24),
      );
}

class _RewardsPanel extends StatelessWidget {
  const _RewardsPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
          boxShadow: AppShadows.cardSoft,
        ),
        child: child,
      );
}

class _RewardsPill extends StatelessWidget {
  const _RewardsPill(
      {required this.label, required this.tint, required this.color});

  final String label;
  final Color tint;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.xs),
        decoration: ShapeDecoration(color: tint, shape: const StadiumBorder()),
        child: Text(label,
            style:
                Theme.of(context).textTheme.labelLarge?.copyWith(color: color)),
      );
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
          colors: [AppColors.primaryDeeper, AppColors.primaryDark],
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
                  color: AppColors.textOnDark.withValues(alpha: 0.18),
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
                    color: AppColors.textOnDark,
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
              color: AppColors.textOnDark.withValues(alpha: 0.94),
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
