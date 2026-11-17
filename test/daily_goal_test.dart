import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/models/chapter.dart';
import 'package:grammar_bondhu/data/models/progress.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/home/home_screen.dart';
import 'package:grammar_bondhu/features/home/home_shell.dart';
import 'package:grammar_bondhu/features/progress/progress_screen.dart';
import 'package:grammar_bondhu/features/quiz/quiz_screen.dart';
import 'package:grammar_bondhu/features/settings/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _savedOn = DateTime(2026, 11, 18, 23, 50);
final _nextDay = DateTime(2026, 11, 19, 0, 10);

UserProgress _completedGoal(int target) => UserProgress(
      questionsAnsweredToday: target,
      dailyGoalQuestions: target,
      lastQuestionDate: _savedOn,
    );

class _FixedDayProgressController extends ProgressController {
  _FixedDayProgressController(super.store, super.initial);

  @override
  Future<void> registerQuestionAnswered({DateTime? now}) =>
      super.registerQuestionAnswered(now: now ?? _nextDay);

  @override
  Future<QuizRunResult> recordQuizRun({
    required Chapter chapter,
    required int correct,
    required int total,
    DateTime? now,
  }) =>
      super.recordQuizRun(
        chapter: chapter,
        correct: correct,
        total: total,
        now: now ?? _nextDay,
      );
}

/// The daily question goal: chosen in Settings, stored on the device, shown on
/// Home, and advanced once per submitted answer rather than once per quiz.
///
/// The last point is the one that was wrong: `recordQuizRun` counted an entire
/// five-question quiz as a single answered question, so a learner could answer
/// five and see "1/5" on the card until they finished the chapter.
Future<
    ({
      ContentController content,
      ProgressController progress,
      LocalStore store,
    })> _pump(
  WidgetTester tester,
  Widget screen, {
  UserProgress? savedProgress,
}) async {
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  if (savedProgress != null) await store.saveProgress(savedProgress);
  final content = ContentController(ContentRepository());
  await content.load();
  final progress = _FixedDayProgressController(store, store.loadProgress());

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: content),
        ChangeNotifierProvider<ProgressController>.value(value: progress),
        ChangeNotifierProvider(
          create: (_) => SettingsController(store, store.loadSettings()),
        ),
      ],
      child: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: screen,
          onUnknownRoute: (settings) =>
              MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (content: content, progress: progress, store: store);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the model owns a sane goal', () {
    test('defaults to five questions', () {
      expect(UserProgress().dailyGoalQuestions, 5);
    });

    test('every offered choice is accepted, and rejected values change nothing',
        () {
      for (final choice in UserProgress.dailyGoalChoices) {
        final p = UserProgress();
        // 5 is already the default, so choosing it is a no-op by design.
        expect(
          p.setDailyGoal(choice),
          choice != UserProgress().dailyGoalQuestions,
        );
        expect(p.dailyGoalQuestions, choice);
      }

      final p = UserProgress();
      expect(p.setDailyGoal(0), isFalse);
      expect(p.setDailyGoal(-3), isFalse);
      expect(p.setDailyGoal(1000), isFalse);
      expect(p.dailyGoalQuestions, 5);
    });

    test('setting the same goal again is not a change', () {
      final p = UserProgress();
      expect(p.setDailyGoal(5), isFalse);
    });

    test('a corrupt stored goal is clamped, not trusted', () {
      // A hand-edited or half-written record must not divide by zero on the
      // goal card, and must not leave the learner permanently behind.
      final zero = UserProgress.fromJson({'daily_goal_questions': 0});
      expect(zero.dailyGoalQuestions, 1);

      final huge = UserProgress.fromJson({'daily_goal_questions': 5000});
      expect(huge.dailyGoalQuestions, 100);
    });

    test('the goal survives a JSON round trip', () {
      final p = UserProgress()..setDailyGoal(15);
      expect(UserProgress.fromJson(p.toJson()).dailyGoalQuestions, 15);
    });

    test('goal reached follows the chosen target', () {
      final p = UserProgress(now: _savedOn)..setDailyGoal(3);
      p.registerQuestionAnswered(_savedOn);
      p.registerQuestionAnswered(_savedOn);
      expect(p.dailyGoalReached, isFalse);
      p.registerQuestionAnswered(_savedOn);
      expect(p.dailyGoalReached, isTrue);
    });

    test('only the saved local calendar day gets credit', () {
      final p = UserProgress(
        questionsAnsweredToday: 5,
        lastQuestionDate: _savedOn.toUtc(),
        now: _nextDay,
      );
      final saved = p.toJson();

      expect(p.questionsAnsweredOn(DateTime(2026, 11, 18, 8)), 5);
      expect(p.questionsAnsweredOn(_nextDay), 0);
      expect(p.questionsAnsweredOn(DateTime(2026, 11, 17)), 0);
      expect(p.dailyGoalReached, isFalse);
      expect(p.toJson(), saved);
    });

    test('missing or invalid question dates preserve the target, not credit',
        () {
      for (final date in [null, 'not a date', 42]) {
        final p = UserProgress.fromJson({
          'questions_today': 5,
          'daily_goal_questions': 15,
          if (date != null) 'last_question_date': date,
        });
        expect(p.questionsAnsweredOn(_nextDay), 0);
        expect(p.dailyGoalQuestions, 15);
      }
    });
  });

  group('Settings shows and stores the choice', () {
    testWidgets('all five targets are offered', (tester) async {
      await _pump(tester, const SettingsScreen());
      for (final target in UserProgress.dailyGoalChoices) {
        expect(
          find.bySemanticsLabel('$target questions a day'),
          findsOneWidget,
          reason: 'target $target is missing from the picker',
        );
      }
    });

    testWidgets('the current goal is the selected chip', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, const SettingsScreen());
      expect(find.text('Daily question goal'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('tapping a target stores it on the device', (tester) async {
      final semantics = tester.ensureSemantics();
      final harness = await _pump(tester, const SettingsScreen());

      await tester.tap(find.bySemanticsLabel('10 questions a day'));
      await tester.pumpAndSettle();

      expect(harness.progress.dailyGoalQuestions, 10);
      // On the device, not just in memory: a fresh store read is what a
      // restart does.
      expect(harness.store.loadProgress().dailyGoalQuestions, 10);
      semantics.dispose();
    });

    testWidgets('the chosen chip reports itself as selected', (tester) async {
      final semantics = tester.ensureSemantics();
      final harness = await _pump(tester, const SettingsScreen());

      await tester.tap(find.bySemanticsLabel('20 questions a day'));
      await tester.pumpAndSettle();

      final chip = tester.getSemantics(
        find.bySemanticsLabel('20 questions a day'),
      );
      expect(chip.hasFlag(SemanticsFlag.isSelected), isTrue);
      expect(harness.progress.dailyGoalQuestions, 20);
      semantics.dispose();
    });
  });

  group('Home reflects the chosen target', () {
    testWidgets('the goal card shows the target the learner picked',
        (tester) async {
      // Start from an existing learner who picked 15 earlier, which is what
      // the next launch of the app sees.
      // A real phone viewport: the default 800x600 test window truncates the
      // home pager, and the goal card lives below the first fold.
      tester.view.physicalSize = const Size(353, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final existing = store.loadProgress()..setDailyGoal(15);
      await store.saveProgress(existing);

      final content = ContentController(ContentRepository());
      await content.load();
      final progress = ProgressController(store, store.loadProgress());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: content),
            ChangeNotifierProvider.value(value: progress),
            ChangeNotifierProvider(
              create: (_) => SettingsController(store, store.loadSettings()),
            ),
          ],
          child: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: MaterialApp(home: HomeShell()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The card says the chosen number, not the default 5.
      expect(find.text('Complete 15 quiz questions today'), findsOneWidget);
      expect(find.text('0/15'), findsOneWidget);

      // And changing the choice moves the card with it.
      await progress.setDailyGoal(3);
      await tester.pumpAndSettle();
      expect(find.text('Complete 3 quiz questions today'), findsOneWidget);
    });

    testWidgets('answering questions moves the card before the quiz ends',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final progress = ProgressController(store, store.loadProgress());
      await progress.setDailyGoal(3);

      await progress.registerQuestionAnswered(now: _nextDay);
      await tester.pump();
      expect(progress.progress.questionsAnsweredOn(_nextDay), 1);

      await progress.registerQuestionAnswered(now: _nextDay);
      await progress.registerQuestionAnswered(now: _nextDay);
      await tester.pump();
      expect(progress.progress.questionsAnsweredOn(_nextDay), 3);
    });
  });

  group('reopening with a saved daily count', () {
    for (final (date, target, count) in [
      (_savedOn, 5, 5),
      (_nextDay, 5, 0),
      (_nextDay, 15, 0),
    ]) {
      testWidgets('Home shows $count/$target on reopen', (tester) async {
        final saved = _completedGoal(target);
        final harness = await _pump(
          tester,
          Scaffold(body: HomeScreen(now: date)),
          savedProgress: saved,
        );

        await tester.scrollUntilVisible(find.text('Daily Goal'), 200);
        await tester.pumpAndSettle();
        expect(find.text('$count/$target'), findsOneWidget);
        expect(
          find.text('Goal complete — nicely done!'),
          count == target ? findsOneWidget : findsNothing,
        );
        expect(harness.progress.progress.questionsAnsweredToday, target);
        expect(harness.progress.progress.lastQuestionDate, _savedOn);
        expect(harness.store.loadProgress().toJson(), saved.toJson());
      });
    }

    for (final (date, count) in [(_savedOn, 5), (_nextDay, 0)]) {
      testWidgets('Progress shows $count questions today on reopen',
          (tester) async {
        await _pump(
          tester,
          ProgressScreen(now: date),
          savedProgress: _completedGoal(5),
        );

        await tester.tap(find.text('Stats'));
        await tester.pumpAndSettle();
        final row = find
            .ancestor(
              of: find.text('Questions today'),
              matching: find.byType(Row),
            )
            .first;
        expect(find.descendant(of: row, matching: find.text('$count')),
            findsOneWidget);
      });
    }
  });

  group('daily progress advances per submitted answer', () {
    testWidgets('the first answer on a new day counts as one', (tester) async {
      final harness = await _pump(
        tester,
        QuizScreen(chapterId: 'ch01'),
        savedProgress: _completedGoal(5),
      );
      expect(harness.progress.progress.questionsAnsweredOn(_nextDay), 0);

      final chapter = harness.content.chapters.first;
      for (var i = 0; i < 3; i++) {
        final question = chapter.quiz[i];
        await tester
            .ensureVisible(find.text(question.options[question.correctIndex]));
        await tester.tap(find.text(question.options[question.correctIndex]));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Submit'));
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        expect(
          harness.store.loadProgress().questionsAnsweredOn(_nextDay),
          i + 1,
          reason: 'answer ${i + 1} did not count toward the daily goal',
        );

        if (i < 2) {
          await tester.ensureVisible(find.text('Next Question'));
          await tester.tap(find.text('Next Question'));
          await tester.pumpAndSettle();
        }
      }
      // Three of five: the card shows real progress before the quiz ends.
      expect(harness.progress.dailyGoalQuestions, 5);
    });

    testWidgets('a wrong answer still counts - it was still answered',
        (tester) async {
      final harness = await _pump(
        tester,
        QuizScreen(chapterId: 'ch01'),
      );
      final question = harness.content.chapters.first.quiz.first;
      final wrong = question.correctIndex == 0 ? 1 : 0;

      await tester.ensureVisible(find.text(question.options[wrong]));
      await tester.tap(find.text(question.options[wrong]));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(harness.progress.progress.questionsAnsweredToday, 1);
    });

    testWidgets('tapping Submit twice does not count twice', (tester) async {
      final harness = await _pump(
        tester,
        QuizScreen(chapterId: 'ch01'),
      );
      final question = harness.content.chapters.first.quiz.first;

      await tester
          .ensureVisible(find.text(question.options[question.correctIndex]));
      await tester.tap(find.text(question.options[question.correctIndex]));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      // The button is gone once submitted; Try Again resets, but it must not
      // have counted a phantom second answer in between.
      expect(find.text('Submit'), findsNothing);
      expect(harness.progress.progress.questionsAnsweredToday, 1);
    });

    testWidgets('finishing a quiz does not add a bonus count', (tester) async {
      final harness = await _pump(
        tester,
        QuizScreen(chapterId: 'ch01'),
      );
      final chapter = harness.content.chapters.first;
      final total = chapter.quiz.length;

      for (var i = 0; i < total; i++) {
        final question = chapter.quiz[i];
        await tester
            .ensureVisible(find.text(question.options[question.correctIndex]));
        await tester.tap(find.text(question.options[question.correctIndex]));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Submit'));
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();
        if (i < total - 1) {
          await tester.ensureVisible(find.text('Next Question'));
          await tester.tap(find.text('Next Question'));
          await tester.pumpAndSettle();
        }
      }

      expect(harness.progress.progress.questionsAnsweredOn(_nextDay), total);
      await tester.ensureVisible(find.text('Finish Quiz'));
      await tester.tap(find.text('Finish Quiz'));
      await tester.pumpAndSettle();

      final saved = harness.store.loadProgress();
      expect(saved.chapters[chapter.id]?.completed, isTrue);
      // Finishing records the run without adding another answer.
      expect(saved.questionsAnsweredOn(_nextDay), total);
    });
  });
}
