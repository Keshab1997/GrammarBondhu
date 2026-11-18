import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/router.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/models/chapter.dart';
import 'package:grammar_bondhu/data/models/progress.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/progress/progress_screen.dart';
import 'package:grammar_bondhu/features/quiz/review_practice_screen.dart';
import 'package:grammar_bondhu/features/rewards/rewards_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<({ContentController content, LocalStore store})> _pump(
  WidgetTester tester,
  Widget screen, {
  UserProgress Function(List<Chapter>)? seed,
  bool provideContent = true,
  Size size = const Size(800, 600),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final content = ContentController(ContentRepository());
  if (provideContent) await content.load();
  final initial = seed?.call(content.chapters) ?? store.loadProgress();
  await store.saveProgress(initial);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        if (provideContent) ChangeNotifierProvider.value(value: content),
        ChangeNotifierProvider(
          create: (_) => ProgressController(store, initial),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsController(store, store.loadSettings()),
        ),
      ],
      child: MaterialApp(
        home: screen,
        onGenerateRoute: AppRouter.onGenerateRoute,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (content: content, store: store);
}

Future<void> _tapText(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

UserProgress _oneMistake(List<Chapter> chapters) =>
    UserProgress(bestStreakDays: 4)
      ..chapter(chapters.first.id)
          .missedQuestionIds
          .add(chapters.first.quiz.first.id);

String _optionLabel(QuizQuestion question, int index) =>
    'Option ${String.fromCharCode(65 + index)}. ${question.options[index]}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('practice keeps the deck stable and counts answers, not rewards',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final harness = await _pump(
        tester,
        const ReviewPracticeScreen(),
        seed: (chapters) {
          final initial = UserProgress(totalXp: 80, coins: 12);
          // Add them in reverse order: the deck follows the course, not the
          // order in which the local snapshot happened to record the misses.
          initial
              .chapter(chapters[1].id)
              .missedQuestionIds
              .add(chapters[1].quiz.first.id);
          initial.chapter(chapters[0].id)
            ..completed = true
            ..attempts = 1
            ..xpEarned = 80
            ..coinsEarned = 12
            ..missedQuestionIds.add(chapters[0].quiz.first.id);
          return initial;
        },
      );
      final firstChapter = harness.content.chapters[0];
      final secondChapter = harness.content.chapters[1];
      final first = firstChapter.quiz.first;
      final second = secondChapter.quiz.first;

      expect(find.text('Question 1 of 2'), findsOneWidget);
      expect(find.text(firstChapter.title.en), findsOneWidget);
      expect(find.text(first.question), findsOneWidget);
      final firstChoice =
          find.bySemanticsLabel(_optionLabel(first, first.correctIndex));
      await _tapText(tester, first.correctAnswer);
      final selected = tester.getSemantics(firstChoice).flagsCollection;
      expect(selected.isButton, isTrue);
      expect(selected.isEnabled.toBoolOrNull(), isTrue);
      expect(selected.isSelected.toBoolOrNull(), isTrue);
      expect(tester.getSize(firstChoice).height, greaterThanOrEqualTo(48));

      final submit = find.text('Submit');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester
          .tap(submit); // Both taps arrive before the locked UI rebuilds.
      await tester.pumpAndSettle();
      expect(find.text(first.explanation.of('bn')), findsOneWidget);
      await _tapText(tester, 'हिन्दी');
      expect(find.text(first.explanation.of('hi')), findsOneWidget);
      expect(harness.store.loadSettings().supportLanguage, 'bn');
      final savedFirst = harness.store.loadProgress();
      expect(savedFirst.chapter(firstChapter.id).missedQuestionIds, isEmpty);
      expect(savedFirst.questionsAnsweredToday, 1);
      expect(find.text('Question 1 of 2'), findsOneWidget);

      await _tapText(tester, 'Next Question');
      expect(find.text('Question 2 of 2'), findsOneWidget);
      expect(find.text(secondChapter.title.en), findsOneWidget);
      expect(find.text(second.question), findsOneWidget);
      final wrong = second.correctIndex == 0 ? 1 : 0;
      await _tapText(tester, second.options[wrong]);
      await _tapText(tester, 'Submit');
      await tester.ensureVisible(find.text(second.options[wrong]));
      await tester.pumpAndSettle();
      final wrongLabel =
          '${_optionLabel(second, wrong)}, your answer, incorrect';
      final reviewed = tester
          .getSemantics(find.bySemanticsLabel(wrongLabel))
          .flagsCollection;
      expect(reviewed.isEnabled.toBoolOrNull(), isFalse);
      expect(
          find.bySemanticsLabel(
            '${_optionLabel(second, second.correctIndex)}, correct answer',
          ),
          findsOneWidget);

      final savedBoth = harness.store.loadProgress();
      expect(savedBoth.questionsAnsweredToday, 2);
      expect(
          savedBoth.chapter(secondChapter.id).missedQuestionIds, {second.id});
      expect(savedBoth.totalXp, 80);
      expect(savedBoth.coins, 12);
      expect(savedBoth.totalQuizAnswered, 1);
      expect(savedBoth.chapter(secondChapter.id).completed, isFalse);

      await _tapText(tester, 'Finish Practice');
      expect(find.text('Cleared 1 of 2'), findsOneWidget);
      expect(find.text('1 left for next time'), findsOneWidget);
      await _tapText(tester, 'Practise Remaining');
      expect(find.text('Question 1 of 1'), findsOneWidget);
      expect(find.text(second.question), findsOneWidget);
      await _tapText(tester, second.correctAnswer);
      await _tapText(tester, 'Submit');
      await _tapText(tester, 'Finish Practice');
      expect(find.text('Cleared 1 of 1'), findsOneWidget);
      expect(find.text('Every mistake cleared!'), findsOneWidget);
      expect(find.text('Practise Remaining'), findsNothing);
      expect(find.text('Done'), findsOneWidget);
      expect(harness.store.loadProgress().missedQuestionCount, 0);
      expect(harness.store.loadProgress().questionsAnsweredToday, 3);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('empty practice takes the learner back without a submission',
      (tester) async {
    await _pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                  builder: (_) => const ReviewPracticeScreen()),
            ),
            child: const Text('Open practice'),
          ),
        ),
      ),
    );
    await _tapText(tester, 'Open practice');
    expect(find.text('Nothing to review'), findsOneWidget);
    expect(find.text('Submit'), findsNothing);
    await _tapText(tester, 'Back');
    expect(find.text('Open practice'), findsOneWidget);
    expect(find.byType(ReviewPracticeScreen), findsNothing);
  });

  testWidgets('Progress opens practice from Review and shows the best streak',
      (tester) async {
    await _pump(
      tester,
      const ProgressScreen(initialTab: 3),
      seed: _oneMistake,
    );
    expect(find.text('1 question ready to practise'), findsOneWidget);
    await _tapText(tester, 'Practise Mistakes');
    expect(find.byType(ReviewPracticeScreen), findsOneWidget);
    expect(find.text('Question 1 of 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await _tapText(tester, 'Stats');
    final bestRow = find.widgetWithText(Row, 'Best streak');
    expect(bestRow, findsOneWidget);
    expect(find.descendant(of: bestRow, matching: find.text('4 days')),
        findsOneWidget);
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets(
        'practice fits 320 dp through feedback at ${(scale * 100).round()}%',
        (tester) async {
      final harness = await _pump(
        tester,
        const ReviewPracticeScreen(),
        seed: _oneMistake,
        size: const Size(320, 640),
        textScale: scale,
      );
      expect(tester.takeException(), isNull);
      final question = harness.content.chapters.first.quiz.first;
      final wrong = question.correctIndex == 0 ? 1 : 0;
      await _tapText(tester, question.options[wrong]);
      await _tapText(tester, 'Submit');
      expect(find.text(question.explanation.of('bn')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _tapText(tester, 'Finish Practice');
      expect(find.text('Cleared 0 of 1'), findsOneWidget);
      expect(find.text('Practise Remaining'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Rewards shows level progress and seven badges at 320 dp / 200%',
      (tester) async {
    await _pump(
      tester,
      const Scaffold(body: RewardsScreen()),
      size: const Size(320, 640),
      textScale: 2,
      seed: (chapters) => UserProgress(
        totalXp: 450,
        bestStreakDays: 3,
        chapters: {
          for (final chapter in chapters)
            chapter.id: ChapterProgress(
              chapterId: chapter.id,
              completed: true,
              stars: 3,
              bestScorePercent: 100,
            ),
        },
      ),
    );
    await tester.scrollUntilVisible(find.text('Level progress'), 200);
    expect(find.text('Level 5 · English Champion'), findsOneWidget);
    expect(find.text('50 / 100 XP to next level'), findsOneWidget);
    final bar = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, 0.5);

    await tester.scrollUntilVisible(find.text('7 of 7 unlocked'), 200);
    for (final badge in [
      'First Chapter',
      'Perfect Quiz',
      '3-Day Streak',
      'Star Collector',
      'Grammar Explorer',
      'English Champion',
      'Story Finisher',
    ]) {
      await tester.scrollUntilVisible(find.text(badge), 180);
      final row = find.widgetWithText(Row, badge);
      expect(
          find.descendant(
              of: row, matching: find.byIcon(Icons.check_circle_rounded)),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Rewards can stand alone and does not award Story Finisher',
      (tester) async {
    await _pump(
      tester,
      const Scaffold(body: RewardsScreen()),
      provideContent: false,
      seed: (_) => UserProgress()..chapter('old-chapter').completed = true,
    );
    await tester.scrollUntilVisible(find.text('1 of 7 unlocked'), 200);
    await tester.scrollUntilVisible(find.text('Story Finisher'), 200);
    final row = find.widgetWithText(Row, 'Story Finisher');
    expect(
        find.descendant(
            of: row,
            matching: find.byIcon(Icons.radio_button_unchecked_rounded)),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
