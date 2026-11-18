import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/models/progress.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/progress/progress_screen.dart';
import 'package:grammar_bondhu/features/quiz/quiz_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a newer review clear wins until a later wrong answer', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final progress = ProgressController(store, store.loadProgress());
    final missedAt = DateTime.utc(2026, 11, 16, 13);
    final clearedAt = DateTime.utc(2026, 11, 17, 13);
    final missedAgainAt = DateTime.utc(2026, 11, 18, 13);

    await progress.markQuestionForReview('ch01', 'shared', now: missedAt);
    await progress.markQuestionForReview('ch01', 'local-only', now: missedAt);
    final stale = UserProgress(chapters: {
      'ch01': ChapterProgress(
        chapterId: 'ch01',
        missedQuestionIds: {'shared', 'remote-only'},
        reviewUpdatedAt: {'shared': missedAt, 'remote-only': missedAt},
      ),
    });
    await progress.clearQuestionForReview('ch01', 'shared',
        now: clearedAt.toLocal());
    final cleared = store.loadProgress();

    final merged = UserProgress.mergeForCloud(cleared, stale);
    expect(merged.chapter('ch01').missedQuestionIds,
        {'local-only', 'remote-only'});
    expect(merged.chapter('ch01').reviewUpdatedAt['shared'], clearedAt);
    expect(
      merged.chapter('ch01').toJson()['review_updated_at'],
      containsPair('shared', clearedAt.toIso8601String()),
    );
    expect(
      UserProgress.mergeForCloud(stale, cleared)
          .chapter('ch01')
          .missedQuestionIds,
      {'local-only', 'remote-only'},
    );

    await progress.markQuestionForReview('ch01', 'shared', now: missedAgainAt);
    final again = UserProgress.mergeForCloud(merged, store.loadProgress());
    expect(again.chapter('ch01').missedQuestionIds,
        {'shared', 'local-only', 'remote-only'});
    expect(again.chapter('ch01').reviewUpdatedAt['shared'], missedAgainAt);
  });

  test('legacy misses survive except where a newer answer clears them',
      () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final progress = ProgressController(store, store.loadProgress());
    final legacy = UserProgress.fromJson({
      'chapters': {
        'ch01': {
          'chapter_id': 'ch01',
          'missed_question_ids': ['fixed', 'keep'],
        },
      },
    });
    expect(legacy.chapter('ch01').reviewUpdatedAt, isEmpty);

    // A correct answer may precede the first restore, so there is no local
    // missed ID yet. The clear still has to be written and survive a reload.
    final correctAt = DateTime.utc(2026, 11, 18);
    await progress.clearQuestionForReview('ch01', 'fixed', now: correctAt);
    final restored = UserProgress.mergeForCloud(store.loadProgress(), legacy);
    expect(restored.chapter('ch01').missedQuestionIds, {'keep'});
    expect(restored.chapter('ch01').reviewUpdatedAt['fixed'], correctAt);
  });

  testWidgets('mistakes show answer and explanation and can be cleared',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final content = ContentController(ContentRepository());
    await content.load();
    final progress = ProgressController(store, store.loadProgress());
    final settings = SettingsController(store, store.loadSettings());
    final chapter = content.chapters.first;
    final question = chapter.quiz.first;
    await progress.markQuestionForReview(chapter.id, question.id);
    final staleBackup = store.loadProgress();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: content),
          ChangeNotifierProvider.value(value: progress),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(home: const ProgressScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text(question.question), findsOneWidget);
    expect(find.text('Answer: ${question.correctAnswer}'), findsOneWidget);
    expect(find.text(question.explanation.of('bn')), findsOneWidget);

    await tester.tap(find.text('Mark reviewed'));
    await tester.pumpAndSettle();

    expect(find.text('Nothing to review'), findsOneWidget);
    expect(progress.progress.missedQuestionCount, 0);
    expect(
      UserProgress.mergeForCloud(store.loadProgress(), staleBackup)
          .missedQuestionCount,
      0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('wrong quiz answer is saved; a later correct answer clears it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final content = ContentController(ContentRepository());
    await content.load();
    final progress = ProgressController(store, store.loadProgress());
    final settings = SettingsController(store, store.loadSettings());
    final chapter = content.chapters.first;
    final question = chapter.quiz.first;
    final wrongIndex = question.correctIndex == 0 ? 1 : 0;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: content),
          ChangeNotifierProvider.value(value: progress),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(home: QuizScreen(chapterId: chapter.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(question.options[wrongIndex]));
    await tester.pumpAndSettle();
    expect(find.text('Tap Submit when you are ready'), findsOneWidget);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(progress.progress.missedQuestionCount, 1);

    // An in-quiz retry is practice: the first miss stays queued for review
    // until the learner gets it right on a fresh attempt.
    await tester.ensureVisible(find.text('Try Again'));
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.text(question.options[question.correctIndex]));
    await tester.tap(find.text(question.options[question.correctIndex]));
    await tester.pumpAndSettle();
    expect(find.text('Tap Submit when you are ready'), findsOneWidget);
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(progress.progress.missedQuestionCount, 1);

    // Starting a new quiz attempt and answering correctly on the first try
    // clears the queued review item.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: content),
          ChangeNotifierProvider.value(value: progress),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(
          home: QuizScreen(key: UniqueKey(), chapterId: chapter.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.text(question.options[question.correctIndex]));
    await tester.tap(find.text(question.options[question.correctIndex]));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(progress.progress.missedQuestionCount, 0);
    expect(tester.takeException(), isNull);
  });
}
