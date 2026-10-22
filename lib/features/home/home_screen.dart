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
/// Polished with soft shadows, gradient hero card, pill quick actions
/// and vibrant daily-streak fire card.
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
            AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
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
              title: 'Your Progress',
              subtitle: current.title.en,
              trailing:
                  '${progress.chapterProgress(current.id).resumeSceneIndex ?? 0}'
                  '/${current.scenes.length + 1}',
              value: chapters.isEmpty
                  ? 0
                  : progress.progress.completedChapterCount / chapters.length,
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

class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final coins = context.watch<ProgressController>().progress.coins;
    return Row(
      children: [
        // Rahul avatar with a subtle glow ring.
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
              width: 48,
              height: 48,
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
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, $name!', style: text.titleLarge),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.favorite_rounded,
                      size: 14, color: AppColors.error.withValues(alpha: 0.8)),
                  const SizedBox(width: 4),
                  Text("Keep going, you're doing great!",
                      style: text.bodyMedium),
                ],
              ),
            ],
          ),
        ),
        _CoinBadge(coins: coins),
        const SizedBox(width: AppSpacing.xs),
        _IconPill(
          icon: Icons.settings_outlined,
          onTap: () =>
              Navigator.of(context).pushNamed(SettingsScreen.routeName),
        ),
      ],
    );
  }
}

class _IconPill extends StatelessWidget {
  const _IconPill({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.chip),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            boxShadow: AppShadows.cardSoft,
          ),
          child: Icon(icon, size: 20, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _CoinBadge extends StatelessWidget {
  const _CoinBadge({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.goldTop, AppColors.accentDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(AppRadii.chip),
        boxShadow: AppShadows.buttonYellow,
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on_rounded,
              size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Text('$coins',
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontSize: 14)),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.chapter, required this.chapters});

  final Chapter chapter;
  final List<Chapter> chapters;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final progress = context.watch<ProgressController>();
    final record = progress.chapterProgress(chapter.id);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary, AppColors.skyTop],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: AppShadows.button,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: Text(
                    record.started
                        ? 'Continue Your Journey'
                        : 'Start Your Journey',
                    style: text.bodySmall?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Chapter ${chapters.indexOf(chapter) + 1}',
                  style: text.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  chapter.title.en,
                  style: text.headlineSmall?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: record.started ? 'Play' : 'Start',
                  icon: Icons.play_arrow_rounded,
                  expand: false,
                  variant: AppButtonVariant.primary,
                  onPressed: () {
                    final resume = record.resumeSceneIndex ?? 0;
                    Navigator.of(context).pushNamed(
                      StoryScreen.routeName,
                      arguments: StoryArgs(chapter.id, startScene: resume),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.card - 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            child: ChapterThumbnail(
              assetPath: chapter.thumbnailAsset,
              fallbackIcon: Icons.auto_stories_rounded,
              size: 110,
              radius: AppRadii.card - 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.current});

  final Chapter? current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ActionChip(
          icon: Icons.menu_book_rounded,
          label: 'Chapters',
          color: AppColors.primary,
          onTap: () =>
              Navigator.of(context).pushNamed(ChapterListScreen.routeName),
        ),
        _ActionChip(
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
        _ActionChip(
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
        _ActionChip(
          icon: Icons.insights_rounded,
          label: 'Progress',
          color: AppColors.purpleTop,
          onTap: () =>
              Navigator.of(context).pushNamed(ProgressScreen.routeName),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.18),
                    color.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.value,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final double value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: const Icon(Icons.trending_up_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: text.titleMedium)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: Text(trailing,
                    style: text.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppProgressBar(
            value: value,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.skyTop],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(subtitle, style: text.bodyMedium),
        ],
      ),
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({required this.done, required this.target});

  final int done;
  final int target;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pct = target == 0 ? 0.0 : (done / target).clamp(0.0, 1.0);
    return AppCard(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFF4D6), Color(0xFFFFE0B2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      elevation: false,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accentDark, AppColors.warning],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentDark.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.local_fire_department_rounded,
                size: 28, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily Goal', style: text.titleMedium),
                const SizedBox(height: 2),
                Text('Complete $target quiz questions today',
                    style: text.bodyMedium),
                const SizedBox(height: AppSpacing.sm),
                AppProgressBar(
                  value: pct,
                  color: AppColors.accentDark,
                  trackColor: Colors.white,
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, AppColors.accentDark],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$done/$target',
                  style:
                      text.titleLarge?.copyWith(color: AppColors.accentDeep)),
              Text('questions',
                  style: text.bodySmall?.copyWith(color: AppColors.accentDeep)),
            ],
          ),
        ],
      ),
    );
  }
}
