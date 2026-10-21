import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/asset_images.dart';
import '../quiz/quiz_screen.dart';

/// Screen 10 — grammar rules with examples and character illustrations.
class GrammarLessonScreen extends StatelessWidget {
  const GrammarLessonScreen({super.key, required this.chapterId});

  static const routeName = '/lesson';

  final String chapterId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final content = context.watch<ContentController>();
    final settings = context.watch<SettingsController>();
    final chapter = content.byId(chapterId);
    if (chapter == null) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Chapter not found')));
    }

    final lesson = chapter.lesson;
    final lang = settings.supportLanguage;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Grammar Lesson'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grammar lesson hero banner (teacher pointing at board) — storyboard frame 10.
            SizedBox(
              height: 160,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                child: Image.asset(
                  'assets/illustrations/grammar_lesson.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const LanguageChip(
                              code: 'en', label: 'English', flag: '🇬🇧'),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              chapter.grammarTopic.en,
                              style: text.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(lesson.title.en, style: text.headlineMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(lesson.explanation.of(lang),
                          style: text.bodyLarge?.copyWith(height: 1.5)),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final example in lesson.examples)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: AppSpacing.md),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.check_circle_rounded,
                                            color: AppColors.success, size: 18),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(example.sentence,
                                                  style: text.bodyLarge
                                                      ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700)),
                                              const SizedBox(height: 2),
                                              Text(example.note.of(lang),
                                                  style: text.bodyMedium),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const CharacterAvatar(
                              characterId: 'teacher', size: 84),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppButton(
                label: 'Next',
                variant: AppButtonVariant.blue,
                onPressed: () => Navigator.of(context).pushNamed(
                  QuizScreen.routeName,
                  arguments: chapterId,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
