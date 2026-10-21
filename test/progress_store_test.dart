import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/models/chapter.dart';
import 'package:grammar_bondhu/data/models/localized_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

Chapter _testChapter() => Chapter(
      id: 'ch01',
      title: const LocalizedText(en: 'The New Student'),
      description: const LocalizedText(en: 'd'),
      grammarTopic: const LocalizedText(en: 'am / is / are'),
      difficulty: 'beginner',
      estimatedDurationMinutes: 10,
      rewards: const ChapterRewards(xp: 50, coins: 10, maxStars: 3),
      scenes: [
        StoryScene(
          sceneId: 's1',
          dialogue: [
            DialogueLine(
                characterId: 'rahul', text: const LocalizedText(en: 'Hi')),
          ],
        ),
      ],
      lesson: GrammarLesson(
        title: const LocalizedText(en: 't'),
        explanation: const LocalizedText(en: 'e'),
        examples: [
          LessonExample(sentence: 'I am.', note: const LocalizedText(en: 'n'))
        ],
      ),
      quiz: [
        QuizQuestion(
          id: 'q1',
          question: 'I ___ a student.',
          options: const ['am', 'is'],
          correctIndex: 0,
          explanation: const LocalizedText(en: 'x'),
        ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalStore persistence', () {
    test('progress and settings round-trip', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();

      final progress = store.loadProgress();
      progress.totalXp = 42;
      progress.chapter('ch01').completed = true;
      await store.saveProgress(progress);

      final settings = store.loadSettings();
      settings.supportLanguage = 'hi';
      await store.saveSettings(settings);

      final store2 = await LocalStore.open();
      expect(store2.loadProgress().totalXp, 42);
      expect(store2.loadProgress().chapter('ch01').completed, true);
      expect(store2.loadSettings().supportLanguage, 'hi');
    });

    test('corrupt records degrade to fresh state instead of crashing',
        () async {
      SharedPreferences.setMockInitialValues({
        'user_progress_v1': '{not json',
        'app_settings_v1': '{not json',
      });
      final store = await LocalStore.open();
      expect(store.loadProgress().totalXp, 0);
      expect(store.loadSettings().supportLanguage, 'bn');
    });
  });

  group('ProgressController', () {
    test('first completion grants XP, coins and stars; resume cleared',
        () async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final controller = ProgressController(store, store.loadProgress());
      final chapter = _testChapter();

      controller.openChapter('ch01', 0);
      expect(controller.chapterProgress('ch01').resumeSceneIndex, 0);

      final result = await controller.recordQuizRun(
        chapter: chapter,
        correct: 1,
        total: 1,
        now: DateTime(2026, 10, 21),
      );

      expect(result.percent, 100);
      expect(result.stars, 3);
      expect(result.xpEarned, 50);
      expect(result.coinsEarned, 10);
      expect(result.firstCompletion, true);
      expect(controller.isCompleted('ch01'), true);
      expect(controller.chapterProgress('ch01').resumeSceneIndex, isNull);
      expect(controller.progress.totalXp, 50);
      expect(controller.progress.coins, 10);
    });

    test('worse rerun does not double-grant rewards', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final controller = ProgressController(store, store.loadProgress());
      final chapter = _testChapter();

      await controller.recordQuizRun(
        chapter: chapter,
        correct: 1,
        total: 1,
        now: DateTime(2026, 10, 21),
      );
      final second = await controller.recordQuizRun(
        chapter: chapter,
        correct: 0,
        total: 1,
        now: DateTime(2026, 10, 21),
      );

      expect(second.firstCompletion, false);
      expect(second.xpEarned, 0);
      expect(controller.progress.totalXp, 50);
      expect(controller.progress.coins, 10);
      expect(controller.chapterProgress('ch01').attempts, 2);
    });

    test('better rerun grants only the XP difference', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final controller = ProgressController(store, store.loadProgress());
      final chapter = _testChapter();

      await controller.recordQuizRun(
        chapter: chapter,
        correct: 0,
        total: 1,
        now: DateTime(2026, 10, 21),
      );
      expect(controller.progress.totalXp, 10); // floor for a finished run

      final better = await controller.recordQuizRun(
        chapter: chapter,
        correct: 1,
        total: 1,
        now: DateTime(2026, 10, 21),
      );
      expect(better.isPersonalBest, true);
      expect(better.xpEarned, 40); // 50 target - 10 already earned
      expect(controller.progress.totalXp, 50);
    });

    test('recommendedChapterId points at first unfinished chapter', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final controller = ProgressController(store, store.loadProgress());
      final chapters = [
        _testChapter(),
        Chapter.fromJson({
          'chapter_id': 'ch02',
          'title': {'en': 'A New Friend'},
          'description': {'en': 'd'},
          'grammar_topic': {'en': 'present'},
          'difficulty': 'beginner',
          'estimated_duration_minutes': 10,
          'rewards': {'xp': 50, 'coins': 10, 'max_stars': 3},
          'scenes': [
            {
              'scene_id': 's',
              'dialogue': [
                {
                  'character_id': 'rahul',
                  'text': {'en': 'hi'}
                }
              ],
            }
          ],
          'lesson': {
            'title': {'en': 't'},
            'explanation': {'en': 'e'},
            'examples': [
              {
                'sentence': 's',
                'note': {'en': 'n'}
              }
            ],
          },
          'quiz': [
            {
              'question_id': 'q',
              'question': '?',
              'options': ['a', 'b'],
              'correct_index': 0,
              'explanation': {'en': 'x'},
            }
          ],
        }),
      ];

      expect(controller.recommendedChapterId(chapters), 'ch01');
      await controller.recordQuizRun(
        chapter: chapters[0],
        correct: 1,
        total: 1,
        now: DateTime(2026, 10, 21),
      );
      expect(controller.recommendedChapterId(chapters), 'ch02');
    });
  });
}
