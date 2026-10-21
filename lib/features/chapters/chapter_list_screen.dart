import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/asset_images.dart';
import '../../data/models/chapter.dart';
import 'chapter_detail_screen.dart';

/// Screen 7 — chapter list with completion status and locked chapters.
class ChapterListScreen extends StatefulWidget {
  const ChapterListScreen({super.key});

  static const routeName = '/chapters';

  @override
  State<ChapterListScreen> createState() => _ChapterListScreenState();
}

enum _ChapterFilter { story, grammar, locked }

class _ChapterListScreenState extends State<ChapterListScreen> {
  _ChapterFilter _filter = _ChapterFilter.story;

  /// A chapter unlocks when the previous one is completed.
  bool _isUnlocked(List<Chapter> chapters, int index, ProgressController progress) {
    if (index == 0) return true;
    return progress.isCompleted(chapters[index - 1].id);
  }

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentController>();
    final progress = context.watch<ProgressController>();
    final chapters = content.chapters;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                if (Navigator.of(context).canPop())
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Text('Chapters', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Story',
                  selected: _filter == _ChapterFilter.story,
                  onTap: () => setState(() => _filter = _ChapterFilter.story),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: 'Grammar',
                  selected: _filter == _ChapterFilter.grammar,
                  onTap: () => setState(() => _filter = _ChapterFilter.grammar),
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: 'Locked',
                  selected: _filter == _ChapterFilter.locked,
                  onTap: () => setState(() => _filter = _ChapterFilter.locked),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: chapters.isEmpty
                ? const Center(child: Text('Chapters are loading…'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: chapters.length,
                    itemBuilder: (context, index) {
                      final chapter = chapters[index];
                      final unlocked = _isUnlocked(chapters, index, progress);
                      final record = progress.chapterProgress(chapter.id);
                      final isLocked = !unlocked;

                      if (_filter == _ChapterFilter.locked && !isLocked) {
                        return const SizedBox.shrink();
                      }
                      if (_filter == _ChapterFilter.grammar && isLocked) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: _ChapterCard(
                          chapter: chapter,
                          number: index + 1,
                          locked: isLocked,
                          completed: record.completed,
                          inProgress: unlocked && record.started && !record.completed,
                          stars: record.stars,
                          onTap: isLocked
                              ? null
                              : () => Navigator.of(context).pushNamed(
                                    ChapterDetailScreen.routeName,
                                    arguments: chapter.id,
                                  ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.chip),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadii.chip),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.chapter,
    required this.number,
    required this.locked,
    required this.completed,
    required this.inProgress,
    required this.stars,
    this.onTap,
  });

  final Chapter chapter;
  final int number;
  final bool locked;
  final bool completed;
  final bool inProgress;
  final int stars;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          ChapterThumbnail(
            assetPath: chapter.thumbnailAsset,
            fallbackIcon: locked ? Icons.lock_rounded : Icons.auto_stories_rounded,
            size: 64,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$number. ${chapter.title.en}', style: text.titleMedium),
                Text(chapter.grammarTopic.en, style: text.bodyMedium),
                const SizedBox(height: 4),
                if (completed)
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text('Completed', style: text.bodyMedium?.copyWith(color: AppColors.success)),
                      const SizedBox(width: AppSpacing.sm),
                      StarsDisplay(count: stars, size: 16),
                    ],
                  )
                else if (inProgress)
                  Row(
                    children: [
                      const Icon(Icons.play_circle_fill_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text('In Progress', style: text.bodyMedium?.copyWith(color: AppColors.primary)),
                    ],
                  )
                else if (locked)
                  Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 16, color: AppColors.textSecondary.withValues(alpha: 0.6)),
                      const SizedBox(width: 4),
                      Text('Locked', style: text.bodyMedium),
                    ],
                  ),
              ],
            ),
          ),
          if (!locked)
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
