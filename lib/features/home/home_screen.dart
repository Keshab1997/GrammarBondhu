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
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _Header(name: settings.greetingName),
          const SizedBox(height: AppSpacing.md),
          if (current != null)
            _ContinueCard(chapter: current, chapters: chapters),
          const SizedBox(height: AppSpacing.md),
          _QuickActions(current: current),
          const SizedBox(height: AppSpacing.md),
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
          const SizedBox(height: AppSpacing.md),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, $name!', style: text.titleLarge),
              Text("Keep going, you're doing great!", style: text.bodyMedium),
            ],
          ),
        ),
        _CoinBadge(coins: coins),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          tooltip: 'Settings',
          onPressed: () =>
              Navigator.of(context).pushNamed(SettingsScreen.routeName),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
    );
  }
}

class _CoinBadge extends StatelessWidget {
  const _CoinBadge({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on_rounded,
              size: 16, color: AppColors.textPrimary),
          const SizedBox(width: 4),
          Text('$coins', style: const TextStyle(fontWeight: FontWeight.w800)),
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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.chapterGradient),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.started
                      ? 'Continue Your Journey'
                      : 'Start Your Journey',
                  style: text.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  'Chapter ${chapters.indexOf(chapter) + 1}',
                  style: text.bodyMedium?.copyWith(color: Colors.white70),
                ),
                Text(
                  chapter.title.en,
                  style: text.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: record.started ? 'Play' : 'Start',
                  icon: Icons.play_arrow_rounded,
                  expand: false,
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
          const SizedBox(width: AppSpacing.sm),
          ChapterThumbnail(
            assetPath: chapter.thumbnailAsset,
            fallbackIcon: Icons.auto_stories_rounded,
            size: 96,
            radius: AppRadii.card,
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
          color: AppColors.primaryDark,
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
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
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
              Expanded(child: Text(title, style: text.titleMedium)),
              Text(trailing,
                  style:
                      text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppProgressBar(value: value),
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
    return AppCard(
      color: AppColors.accent.withValues(alpha: 0.16),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded,
              size: 36, color: AppColors.accentDark),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily Goal', style: text.titleMedium),
                Text('Complete $target quiz today', style: text.bodyMedium),
                const SizedBox(height: AppSpacing.sm),
                AppProgressBar(
                  value: target == 0 ? 0 : done / target,
                  color: AppColors.accentDark,
                  trackColor: Colors.white,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text('$done/$target', style: text.titleLarge),
        ],
      ),
    );
  }
}
