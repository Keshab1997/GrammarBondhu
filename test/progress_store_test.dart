import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/models/chapter.dart';
import 'package:grammar_bondhu/data/models/localized_text.dart';
import 'package:grammar_bondhu/data/models/progress.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/progress/progress_screen.dart';
import 'package:grammar_bondhu/features/rewards/rewards_screen.dart';
import 'package:provider/provider.dart';
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
      settings
        ..supportLanguage = 'hi'
        ..cloudAccountId = 'firebase-user-1'
        ..isGuest = false;
      await store.saveSettings(settings);

      final store2 = await LocalStore.open();
      expect(store2.loadProgress().totalXp, 42);
      expect(store2.loadProgress().chapter('ch01').completed, true);
      expect(store2.loadSettings().supportLanguage, 'hi');
      expect(store2.loadSettings().cloudAccountId, 'firebase-user-1');
      expect(store2.loadSettings().isGuest, false);
    });

    test('missed quiz questions persist and can be cleared', () async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final controller = ProgressController(store, store.loadProgress());

      await controller.markQuestionForReview('ch01', 'q01');
      expect(controller.progress.missedQuestionCount, 1);

      final reopened = await LocalStore.open();
      expect(
        reopened.loadProgress().chapter('ch01').missedQuestionIds,
        {'q01'},
      );

      await controller.clearQuestionForReview('ch01', 'q01');
      expect(controller.progress.missedQuestionCount, 0);
      expect(
        (await LocalStore.open())
            .loadProgress()
            .chapter('ch01')
            .missedQuestionIds,
        isEmpty,
      );
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
      expect(controller.chapterProgress('ch01').coinsEarned, 10);
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

    test('going from two to three stars grants only the remaining coins',
        () async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final controller = ProgressController(store, store.loadProgress());
      final chapter = _testChapter();
      final now = DateTime(2026, 10, 21);

      final first = await controller.recordQuizRun(
        chapter: chapter,
        correct: 3,
        total: 4,
        now: now,
      );
      expect(first.stars, 2);
      expect(first.coinsEarned, 5);

      final improved = await controller.recordQuizRun(
        chapter: chapter,
        correct: 4,
        total: 4,
        now: now,
      );
      expect(improved.stars, 3);
      expect(improved.coinsEarned, 5);
      expect(controller.progress.coins, 10);
      expect(store.loadProgress().chapter(chapter.id).coinsEarned, 10);

      final replay = await controller.recordQuizRun(
        chapter: chapter,
        correct: 4,
        total: 4,
        now: now,
      );
      expect(replay.coinsEarned, 0);
      expect(store.loadProgress().coins, 10);
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

  group('Study streaks', () {
    test('calendar days carry across DST and decay after a missed day', () {
      final progress = UserProgress();
      // With TZ=America/New_York these adjacent midnights span just 23 hours.
      final springForward = DateTime(2026, 3, 8);
      final nextDay = DateTime(2026, 3, 9);
      expect(progress.registerStudyDay(springForward), 1);
      expect(progress.activeStreakOn(nextDay), 1);
      expect(progress.registerStudyDay(nextDay), 2);
      expect(progress.registerStudyDay(DateTime(2026, 3, 10)), 3);
      expect(progress.registerStudyDay(DateTime(2026, 3, 10, 23)), 3);
      expect(progress.activeStreakOn(DateTime(2026, 3, 11, 23)), 3);
      expect(progress.activeStreakOn(DateTime(2026, 3, 12)), 0);
      expect(progress.streakDays, 3); // Reading after decay is non-mutating.
      expect(progress.registerStudyDay(DateTime(2026, 3, 12)), 1);

      final reloaded = UserProgress.fromJson(progress.toJson());
      expect(reloaded.bestStreakDays, 3);
      expect(reloaded.streakDays, 1);
      expect(reloaded.activeStreakOn(DateTime(2026, 3, 12)), 1);
    });

    test('cloud merge keeps the freshest streak and the historical best', () {
      final legacy = UserProgress.fromJson({
        'streak_days': 7,
        'last_study_date': '2026-11-14T00:00:00.000',
      });
      expect(legacy.bestStreakDays, 7);
      final today = DateTime(2026, 11, 18);
      final fresh = UserProgress(streakDays: 1, lastStudyDate: today);

      for (final combined in [
        UserProgress.mergeForCloud(legacy, fresh),
        UserProgress.mergeForCloud(fresh, legacy),
      ]) {
        expect(combined.lastStudyDate, today);
        expect(combined.activeStreakOn(today), 1);
        expect(combined.bestStreakDays, 7);
      }

      final sameDay = UserProgress(
        streakDays: 4,
        lastStudyDate: DateTime(2026, 11, 18, 12),
        bestStreakDays: 5,
      );
      final merged = UserProgress.mergeForCloud(sameDay, fresh);
      expect(merged.activeStreakOn(today), 4);
      expect(merged.bestStreakDays, 5);
    });

    testWidgets('Progress and Rewards show the active streak, not the record',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final progress = ProgressController(
        store,
        UserProgress(streakDays: 3, lastStudyDate: DateTime(2026, 11, 15)),
      );
      final now = DateTime(2026, 11, 18);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: progress),
            ChangeNotifierProvider(
              create: (_) => ContentController(ContentRepository()),
            ),
            ChangeNotifierProvider(
              create: (_) => SettingsController(store, store.loadSettings()),
            ),
          ],
          child: MaterialApp(home: ProgressScreen(now: now)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Quizzes Finished'), findsOneWidget);
      expect(find.text('0 days'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('This week'), 150);
      expect(find.text('Start today'), findsOneWidget);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: progress,
          child: MaterialApp(home: Scaffold(body: RewardsScreen(now: now))),
        ),
      );
      await tester.pumpAndSettle();
      final streakStat = find
          .ancestor(
            of: find.text('Day Streak'),
            matching: find.byType(Column),
          )
          .first;
      expect(find.descendant(of: streakStat, matching: find.text('0')),
          findsOneWidget);
      await tester.scrollUntilVisible(find.text('3-Day Streak'), 200);
      final streakBadge = find.widgetWithText(Row, '3-Day Streak');
      expect(
        find.descendant(
          of: streakBadge,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
    });
  });
}
