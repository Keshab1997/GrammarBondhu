import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/asset_images.dart';
import '../story/story_screen.dart';

/// Screen 17 — chapter intro, learning objectives, Start button.
class ChapterDetailScreen extends StatelessWidget {
  const ChapterDetailScreen({super.key, required this.chapterId});

  static const routeName = '/chapter-detail';

  final String chapterId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final content = context.watch<ContentController>();
    final progress = context.watch<ProgressController>();
    final chapter = content.byId(chapterId);
    if (chapter == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Chapter not found')),
      );
    }

    final record = progress.chapterProgress(chapterId);
    final resume = record.resumeSceneIndex ?? 0;

    return Scaffold(
      body: SceneBackground(
        backgroundId:
            chapter.backgroundAsset?.split('/').last.replaceAll(RegExp(r'\.[a-z]+$'), ''),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.sheet),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chapter ${content.chapters.indexOf(chapter) + 1}',
                          style: text.bodyMedium),
                      Text(chapter.title.en, style: text.headlineMedium),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Grammar Focus', style: text.bodyMedium),
                      Text(chapter.grammarTopic.en, style: text.titleLarge),
                      const SizedBox(height: AppSpacing.lg),
                      _CheckRow(label: 'Story', detail: '${chapter.scenes.length} scenes'),
                      _CheckRow(label: 'Grammar Lesson', detail: 'Rules & examples'),
                      _CheckRow(
                        label: 'Quiz (${chapter.quiz.length} Questions)',
                        detail: record.completed
                            ? 'Best score ${record.bestScorePercent}%'
                            : 'Test yourself',
                      ),
                      const Spacer(),
                      if (record.completed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Center(child: StarsDisplay(count: record.stars)),
                        ),
                      AppButton(
                        label: record.started && !record.completed ? 'Resume' : 'Start',
                        icon: Icons.play_arrow_rounded,
                        variant: AppButtonVariant.primary,
                        onPressed: () => Navigator.of(context).pushNamed(
                          StoryScreen.routeName,
                          arguments: StoryArgs(chapterId, startScene: resume),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label, style: text.bodyLarge)),
          Text(detail, style: text.bodyMedium),
        ],
      ),
    );
  }
}
