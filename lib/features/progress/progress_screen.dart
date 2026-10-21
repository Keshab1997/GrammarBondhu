import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/asset_images.dart';
import '../../data/models/progress.dart';

/// Screen 14 — overview, per-chapter history and stats.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  static const routeName = '/progress';

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentController>();
    final progress = context.watch<ProgressController>();
    final p = progress.progress;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('My Progress'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  _TabChip(label: 'Overview', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
                  const SizedBox(width: AppSpacing.sm),
                  _TabChip(label: 'Chapters', selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
                  const SizedBox(width: AppSpacing.sm),
                  _TabChip(label: 'Stats', selected: _tab == 2, onTap: () => setState(() => _tab = 2)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  if (_tab == 0) ...[
                    _LevelCard(
                      level: p.level,
                      title: p.levelTitle,
                      xpIntoLevel: p.xpIntoLevel,
                      xpPerLevel: UserProgress.xpPerLevel,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 1.5,
                      children: [
                        _StatTile(
                          icon: Icons.menu_book_rounded,
                          color: AppColors.primary,
                          label: 'Chapters',
                          value: '${p.completedChapterCount}/${content.chapters.length}',
                        ),
                        _StatTile(
                          icon: Icons.quiz_rounded,
                          color: AppColors.success,
                          label: 'Quiz Answers',
                          value: '${p.totalQuizAnswered}',
                        ),
                        _StatTile(
                          icon: Icons.local_fire_department_rounded,
                          color: AppColors.accentDark,
                          label: 'Streak',
                          value: '${p.streakDays} ${p.streakDays == 1 ? 'day' : 'days'}',
                        ),
                        _StatTile(
                          icon: Icons.military_tech_rounded,
                          color: AppColors.primaryDark,
                          label: 'Total Points',
                          value: '${p.totalXp}',
                        ),
                      ],
                    ),
                  ] else if (_tab == 1) ...[
                    for (final chapter in content.chapters)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          child: Row(
                            children: [
                              ChapterThumbnail(
                                assetPath: chapter.thumbnailAsset,
                                fallbackIcon: Icons.auto_stories_rounded,
                                size: 48,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(chapter.title.en,
                                        style: Theme.of(context).textTheme.titleMedium),
                                    Text(
                                      progress.chapterProgress(chapter.id).completed
                                          ? 'Best ${progress.chapterProgress(chapter.id).bestScorePercent}%'
                                          : 'Not finished yet',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              StarsDisplay(
                                count: progress.chapterProgress(chapter.id).stars,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ] else ...[
                    AppCard(
                      child: Column(
                        children: [
                          _StatRow(label: 'Total XP', value: '${p.totalXp}'),
                          _StatRow(label: 'Coins', value: '${p.coins}'),
                          _StatRow(label: 'Current streak', value: '${p.streakDays} days'),
                          _StatRow(label: 'Questions today', value: '${p.questionsAnsweredToday}'),
                          _StatRow(label: 'Daily goal', value: '${p.dailyGoalQuestions} questions'),
                          _StatRow(label: 'Level', value: '${p.level} — ${p.levelTitle}'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.title,
    required this.xpIntoLevel,
    required this.xpPerLevel,
  });

  final int level;
  final String title;
  final int xpIntoLevel;
  final int xpPerLevel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: [
          const CharacterAvatar(characterId: 'rahul', size: 64),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Level $level', style: text.titleLarge),
                Text(title, style: text.bodyMedium),
                const SizedBox(height: AppSpacing.sm),
                AppProgressBar(value: xpIntoLevel / xpPerLevel),
                const SizedBox(height: 4),
                Text('$xpIntoLevel / $xpPerLevel XP', style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label, style: text.bodyMedium, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: text.titleLarge),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.bodyLarge)),
          Text(value, style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
