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

/// Filters that describe an actual chapter state.
///
/// The old set was `story / grammar / locked`, but no `Chapter` carries a
/// grammar dimension — the "Grammar" tab only hid locked chapters, so it
/// showed exactly the same list as "Story". These four are all real.
enum _ChapterFilter { all, inProgress, completed, locked }

class _ChapterListScreenState extends State<ChapterListScreen> {
  _ChapterFilter _filter = _ChapterFilter.all;

  /// What the learner has to finish to open this chapter.
  String? _unlockHint(List<Chapter> chapters, int index) {
    if (index == 0) return null;
    return 'Finish “${chapters[index - 1].title.en}” to unlock';
  }

  /// A chapter unlocks when the previous one is completed.
  bool _isUnlocked(
      List<Chapter> chapters, int index, ProgressController progress) {
    if (index == 0) return true;
    return progress.isCompleted(chapters[index - 1].id);
  }

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentController>();
    final progress = context.watch<ProgressController>();
    final chapters = content.chapters;

    // Own Scaffold/Material: this screen is both a tab inside HomeShell
    // and a standalone route (/chapters, from the Home quick action), and
    // a route's LookupBoundary hides any Material above it — the filter
    // chips' InkWell crashed there with "No Material widget found".
    // The background matches the home shell's wash so the tab looks the
    // same nested as it does standalone.
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5FB),
      body: SafeArea(
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
                  Text('Chapters',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            // Wrap, not Row: four chips do not fit on a 353 dp phone, and a
            // horizontally scrolling row would hide the last filter off the
            // edge. Wrapping keeps every filter visible and tappable.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _filter == _ChapterFilter.all,
                    onTap: () => setState(() => _filter = _ChapterFilter.all),
                  ),
                  _FilterChip(
                    label: 'In progress',
                    selected: _filter == _ChapterFilter.inProgress,
                    onTap: () =>
                        setState(() => _filter = _ChapterFilter.inProgress),
                  ),
                  _FilterChip(
                    label: 'Completed',
                    selected: _filter == _ChapterFilter.completed,
                    onTap: () =>
                        setState(() => _filter = _ChapterFilter.completed),
                  ),
                  _FilterChip(
                    label: 'Locked',
                    selected: _filter == _ChapterFilter.locked,
                    onTap: () =>
                        setState(() => _filter = _ChapterFilter.locked),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: chapters.isEmpty
                  ? const Center(child: Text('Chapters are loading…'))
                  : ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      itemCount: chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = chapters[index];
                        final unlocked = _isUnlocked(chapters, index, progress);
                        final record = progress.chapterProgress(chapter.id);
                        final isLocked = !unlocked;

                        final inProgress =
                            unlocked && record.started && !record.completed;
                        final matches = switch (_filter) {
                          _ChapterFilter.all => true,
                          _ChapterFilter.inProgress => inProgress,
                          _ChapterFilter.completed => record.completed,
                          _ChapterFilter.locked => isLocked,
                        };
                        if (!matches) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _ChapterCard(
                            chapter: chapter,
                            number: index + 1,
                            locked: isLocked,
                            completed: record.completed,
                            inProgress: inProgress,
                            stars: record.stars,
                            resumeStep: record.resumeSceneIndex,
                            sceneCount: chapter.scenes.length,
                            unlocksAfter:
                                isLocked ? _unlockHint(chapters, index) : null,
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
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Material + InkWell (same pattern as AppCard): the ink needs its own
    // Material to paint on, and the colour lives on the Material so the
    // splash is not hidden under the chip's fill.
    return Material(
      color: selected ? AppColors.primary : AppColors.primarySoft,
      borderRadius: BorderRadius.circular(AppRadii.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 8),
          decoration: BoxDecoration(
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
    required this.resumeStep,
    required this.sceneCount,
    this.unlocksAfter,
    this.onTap,
  });

  final Chapter chapter;
  final int number;
  final bool locked;
  final bool completed;
  final bool inProgress;
  final int stars;
  final int? resumeStep;
  final int sceneCount;
  final String? unlocksAfter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Locked art is dimmed: a locked chapter shouldn't look as
              // inviting as the one you can actually open.
              Opacity(
                opacity: locked ? 0.55 : 1,
                child: ChapterThumbnail(
                  assetPath: chapter.thumbnailAsset,
                  fallbackIcon:
                      locked ? Icons.lock_rounded : Icons.auto_stories_rounded,
                  size: 64,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$number. ${chapter.title.en}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium,
                          ),
                        ),
                        if (!locked && !completed && !inProgress)
                          _Badge(
                            label: 'NEW',
                            color: AppColors.accentDark,
                          ),
                        if (completed)
                          const Icon(Icons.check_circle_rounded,
                              size: 18, color: AppColors.success),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chapter.grammarTopic.en,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    if (completed)
                      Row(
                        children: [
                          Text('Completed',
                              style: text.bodySmall?.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: AppSpacing.sm),
                          StarsDisplay(count: stars, size: 15),
                        ],
                      )
                    else if (inProgress)
                      Row(
                        children: [
                          _Badge(
                              label: 'IN PROGRESS', color: AppColors.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Step ${(resumeStep ?? 0) + 1} of ${sceneCount + 1}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall
                                  ?.copyWith(color: AppColors.primary),
                            ),
                          ),
                        ],
                      )
                    else if (locked)
                      Row(
                        children: [
                          Icon(Icons.lock_rounded,
                              size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              unlocksAfter ?? 'Locked',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      )
                    else
                      Text('Ready to start',
                          style: text.bodySmall
                              ?.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              if (!locked)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
