import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/accessible_layout.dart';
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

  /// A chapter unlocks when the previous one is completed — unless the learner
  /// turned practice mode on, which opens the whole course at once.
  bool _isUnlocked(
    List<Chapter> chapters,
    int index,
    ProgressController progress, {
    bool unlockAll = false,
  }) {
    if (index == 0 || unlockAll) return true;
    return progress.isCompleted(chapters[index - 1].id);
  }

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentController>();
    final progress = context.watch<ProgressController>();
    final lang = context.select(
        (SettingsController? settings) => settings?.supportLanguage ?? 'en');
    final chapters = content.chapters;
    final unlockAll = context
        .select((SettingsController? s) => s?.unlockAllChapters ?? false);

    final cards = <Widget>[];
    for (var index = 0; index < chapters.length; index++) {
      final chapter = chapters[index];
      final unlocked =
          _isUnlocked(chapters, index, progress, unlockAll: unlockAll);
      final record = progress.chapterProgress(chapter.id);
      final isLocked = !unlocked;

      final inProgress = unlocked && record.started && !record.completed;
      final matches = switch (_filter) {
        _ChapterFilter.all => true,
        _ChapterFilter.inProgress => inProgress,
        _ChapterFilter.completed => record.completed,
        _ChapterFilter.locked => isLocked,
      };
      if (!matches) continue;

      cards.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: _ChapterCard(
          chapter: chapter,
          supportLanguage: lang,
          number: index + 1,
          locked: isLocked,
          completed: record.completed,
          inProgress: inProgress,
          stars: record.stars,
          resumeStep: record.resumeSceneIndex,
          sceneCount: chapter.scenes.length,
          unlocksAfter: isLocked ? _unlockHint(chapters, index) : null,
          onTap: isLocked
              ? null
              : () => Navigator.of(context).pushNamed(
                    ChapterDetailScreen.routeName,
                    arguments: chapter.id,
                  ),
        ),
      ));
    }

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
                      tooltip: 'Back',
                      style: IconButton.styleFrom(
                          minimumSize: const Size.square(
                              AccessibleLayout.minTouchTarget),
                          visualDensity: VisualDensity.standard),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  // At 200% type the page title alone no longer fits beside
                  // the back button, so it takes the remaining width and may
                  // wrap rather than pushing the row past the screen edge.
                  Flexible(
                    child: Text(
                      'Chapters',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
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
                    label: 'Started',
                    selected: _filter == _ChapterFilter.inProgress,
                    onTap: () =>
                        setState(() => _filter = _ChapterFilter.inProgress),
                  ),
                  _FilterChip(
                    label: 'Done',
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
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, 108),
                      children: cards.isNotEmpty
                          ? cards
                          : [
                              AppCard(
                                  child: Text(switch (_filter) {
                                _ChapterFilter.inProgress =>
                                  'No chapters in progress. Choose one from All to get started.',
                                _ChapterFilter.completed =>
                                  'No completed chapters yet. Finish a quiz to see it here.',
                                _ChapterFilter.locked =>
                                  'Every chapter is unlocked. Pick one from All to practise.',
                                _ChapterFilter.all =>
                                  'No chapters available yet.',
                              })),
                            ],
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
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size.square(AccessibleLayout.minTouchTarget),
          visualDensity: VisualDensity.standard,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          foregroundColor: selected ? Colors.white : AppColors.primaryDark,
          backgroundColor: selected ? AppColors.primary : AppColors.primarySoft,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.chip)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        child: Text(label),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.chapter,
    required this.supportLanguage,
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
  final String supportLanguage;
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
    final topic = chapter.grammarTopic.of(supportLanguage);
    final level = chapter.difficultyLabel;
    final step = (resumeStep ?? 0).clamp(0, sceneCount) + 1;
    final steps = sceneCount + 1;
    final thumbnail = ChapterThumbnail(
      assetPath: chapter.thumbnailAsset,
      // The solid lock badge, not a faded fallback illustration, marks locks.
      fallbackIcon: Icons.auto_stories_rounded,
      size: 64,
    );
    return Material(
      color: AppColors.surface,
      elevation: 2,
      shadowColor: AppColors.primary.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: inProgress
            ? BorderSide(
                color: AppColors.primary.withValues(alpha: 0.35), width: 1.5)
            : completed
                ? BorderSide(color: AppColors.success.withValues(alpha: 0.30))
                : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (locked)
                    ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                            Color(0x4D1E293B), BlendMode.srcATop),
                        child: thumbnail)
                  else
                    thumbnail,
                  if (locked)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.textPrimary,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.lock_rounded,
                                size: 12, color: Colors.white)),
                      ),
                    ),
                  Positioned(
                    left: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      constraints:
                          const BoxConstraints(minWidth: 22, minHeight: 22),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: locked
                            ? AppColors.textSecondary
                            : AppColors.primary,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        '$number',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
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
                            chapter.title.en,
                            style: text.titleMedium,
                          ),
                        ),
                        if (!locked && !completed && !inProgress)
                          const _Badge(
                            label: 'NEW',
                            color: Color(0xFF854D0E),
                          ),
                        if (completed)
                          const Icon(Icons.check_circle_rounded,
                              size: 18, color: AppColors.success),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(chapter.grammarTopic.en, style: text.bodyMedium),
                    if (supportLanguage != 'en' &&
                        topic != chapter.grammarTopic.en)
                      Text(topic,
                          style: text.bodySmall
                              ?.copyWith(color: AppColors.textSecondary)),
                    if (level.isNotEmpty && level != 'Beginner')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child:
                            _Badge(label: level, color: AppColors.primaryDark),
                      ),
                    const SizedBox(height: 6),
                    if (completed)
                      Wrap(
                        spacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Completed',
                              style: text.bodySmall?.copyWith(
                                  color: const Color(0xFF065F46),
                                  fontWeight: FontWeight.w700)),
                          StarsDisplay(count: stars, size: 15),
                        ],
                      )
                    else if (inProgress) ...[
                      Wrap(
                        spacing: AppSpacing.sm,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const _Badge(
                              label: 'IN PROGRESS',
                              color: AppColors.primaryDark),
                          Text(
                            'Step $step of $steps',
                            style: text.bodySmall
                                ?.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      AppProgressBar(value: step / steps, height: 5),
                    ] else if (locked)
                      Row(
                        children: [
                          const Icon(Icons.lock_rounded,
                              size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              unlocksAfter ?? 'Locked',
                              style: text.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      )
                    else
                      Text('Ready to start',
                          style: text.bodySmall
                              ?.copyWith(color: AppColors.textSecondary)),
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
        ),
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
