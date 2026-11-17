import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/models/chapter.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/completion/chapter_completed_screen.dart';
import 'package:grammar_bondhu/features/quiz/quiz_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Both async races in the quiz screen, held open on purpose.
///
/// Saving an answer and finishing a run are the only two places the screen
/// waits on the store. Each had a window where a second gesture was still
/// accepted: the answer tiles stayed tappable while the first answer was being
/// saved, and Finish Quiz stayed tappable while the run was being recorded.
/// The first swapped the answer under the feedback that had already judged it;
/// the second recorded two attempts, granted the reward twice and pushed the
/// completed screen twice.
///
/// A plain controller finishes those futures before the next tap can land, so
/// these tests use [DelayedProgressController]: it parks the next call on a
/// [Completer] the test releases by hand. That is what makes the race
/// reachable — no sleeps, no timers, no guessing at a pump duration.
class DelayedProgressController extends ProgressController {
  DelayedProgressController(super.store, super.initial);

  Completer<void>? _pendingQuestion;
  Completer<void>? _pendingRun;
  Object? _runError;
  int questionSaves = 0;
  int runRecords = 0;

  /// Makes the next answer save wait until the returned completer completes.
  Completer<void> holdNextQuestionSave() {
    final gate = Completer<void>();
    _pendingQuestion = gate;
    return gate;
  }

  /// Makes the next run record wait, and then throw [error] if one is given.
  ///
  /// A failure is not held open: the test wants the tap to come back with the
  /// error and the retry button live again, not a gate it has to release.
  Completer<void> holdNextRunRecord({Object? error}) {
    final gate = Completer<void>();
    _pendingRun = gate;
    _runError = error;
    if (error != null) gate.complete();
    return gate;
  }

  @override
  Future<void> registerQuestionAnswered({DateTime? now}) async {
    questionSaves += 1;
    final gate = _pendingQuestion;
    if (gate != null) await gate.future;
    await super.registerQuestionAnswered(now: now);
  }

  @override
  Future<QuizRunResult> recordQuizRun({
    required Chapter chapter,
    required int correct,
    required int total,
    DateTime? now,
  }) async {
    runRecords += 1;
    final gate = _pendingRun;
    if (gate != null) await gate.future;
    final error = _runError;
    if (error != null) {
      _runError = null;
      throw error;
    }
    return super.recordQuizRun(
      chapter: chapter,
      correct: correct,
      total: total,
      now: now,
    );
  }
}

/// A phone big enough that a five-option quiz and its feedback card fit
/// without scrolling, so "the button is still there" means the same thing
/// before and after a save and a tap always lands on the widget it names.
void _useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<
    ({
      ContentController content,
      DelayedProgressController progress,
      LocalStore store,
      List<String?> routes,
    })> _pump(
  WidgetTester tester,
  Widget screen,
) async {
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final content = ContentController(ContentRepository());
  await content.load();
  final progress = DelayedProgressController(store, store.loadProgress());
  // Every route the screen asks for, in order. A destination that renders is
  // not the point here — a second push is, and this records exactly that.
  final routes = <String?>[];

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
          onGenerateRoute: (settings) {
            routes.add(settings.name);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const SizedBox.shrink(),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (
    content: content,
    progress: progress,
    store: store,
    routes: routes,
  );
}

/// The "am" of ch01: correct index 0, every wrong option a different word.
bool _isRight(QuizQuestion question, String option) =>
    option == question.correctAnswer;

Future<void> _tapAnswer(WidgetTester tester, String option) async {
  await tester.ensureVisible(find.text(option));
  await tester.tap(find.text(option));
  await tester.pumpAndSettle();
}

/// Answers every question up to the last one, leaving the quiz on its final
/// question with one verdict on screen and nothing left to select.
Future<void> _answerUpToLastQuestion(
  WidgetTester tester,
  Chapter chapter,
) async {
  final total = chapter.quiz.length;
  for (var i = 0; i < total - 1; i++) {
    final question = chapter.quiz[i];
    await _tapAnswer(tester, question.correctAnswer);
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Next Question'));
    await tester.tap(find.text('Next Question'));
    await tester.pumpAndSettle();
  }
  final last = chapter.quiz[total - 1];
  await _tapAnswer(tester, last.correctAnswer);
  await tester.ensureVisible(find.text('Submit'));
  await tester.tap(find.text('Submit'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Finish Quiz'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a submitted answer is frozen while it is saved', () {
    testWidgets(
        'changing the answer mid-save cannot move the verdict, the score or '
        'the daily count', (tester) async {
      _useTallPhone(tester);
      final harness = await _pump(tester, QuizScreen(chapterId: 'ch01'));
      final question = harness.content.chapters.first.quiz.first;
      final wrong =
          question.options.firstWhere((option) => !_isRight(question, option));

      await _tapAnswer(tester, question.correctAnswer);
      final gate = harness.progress.holdNextQuestionSave();
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pump();

      // The save is still in flight: the verdict is not on screen yet, so
      // without the guard the tiles are still live. They must not be — and
      // `_selected` must still be the answer that was submitted.
      expect(find.text('Submit'), findsOneWidget);
      expect(find.text(question.correctAnswer), findsOneWidget);
      expect(
        tester.widget<InkWell>(_optionInkWell(wrong)).onTap,
        isNull,
        reason: 'an answer tile stayed tappable while the submitted answer '
            'was being saved',
      );
      await tester.tap(find.text(wrong), warnIfMissed: false);
      await tester.pump();

      gate.complete();
      await tester.pumpAndSettle();

      // Submit is gone: the save completed and the verdict is on screen.
      expect(find.text('Submit'), findsNothing);
      expect(find.text('Incorrect'), findsNothing);
      expect(harness.progress.questionSaves, 1);
      expect(harness.progress.progress.questionsAnsweredToday, 1);
      expect(
          harness.store.loadProgress().questionsAnsweredOn(DateTime.now()), 1);

      // Review state agrees with the verdict: nothing was marked missed.
      final chapter = harness.content.chapters.first;
      expect(
        harness.progress.progress.chapter(chapter.id).missedQuestionIds,
        isEmpty,
        reason: 'a correct answer was recorded for the daily count but a wrong '
            'one was recorded for review',
      );

      // The score carries that same answer into the run: five correct.
      for (var i = 1; i < chapter.quiz.length; i++) {
        final next = chapter.quiz[i];
        await _tapAnswer(tester, next.correctAnswer);
        await tester.ensureVisible(find.text('Submit'));
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();
        if (i < chapter.quiz.length - 1) {
          await tester.ensureVisible(find.text('Next Question'));
          await tester.tap(find.text('Next Question'));
          await tester.pumpAndSettle();
        }
      }
      await tester.ensureVisible(find.text('Finish Quiz'));
      await tester.tap(find.text('Finish Quiz'));
      await tester.pumpAndSettle();

      final record = harness.progress.progress.chapter(chapter.id);
      expect(record.bestScorePercent, 100);
      expect(record.missedQuestionIds, isEmpty);
    });
  });

  group('Finish Quiz is guarded while the run is being recorded', () {
    testWidgets('a double tap records one attempt and navigates once',
        (tester) async {
      _useTallPhone(tester);
      final harness = await _pump(tester, QuizScreen(chapterId: 'ch01'));
      final chapter = harness.content.chapters.first;
      await _answerUpToLastQuestion(tester, chapter);

      final gate = harness.progress.holdNextRunRecord();
      await tester.tap(find.text('Finish Quiz'));
      await tester.pump();

      // Second tap while the first is still saving: the expected numbers are
      // still on the button, so this is a real reach, not a miss.
      expect(find.text('Finish Quiz'), findsOneWidget);
      await tester.tap(find.text('Finish Quiz'), warnIfMissed: false);
      await tester.pump();

      expect(harness.progress.runRecords, 1,
          reason: 'a second finish started while the first was saving');

      gate.complete();
      await tester.pumpAndSettle();

      expect(harness.progress.runRecords, 1);
      expect(harness.progress.progress.chapter(chapter.id).attempts, 1);
      expect(harness.store.loadProgress().chapter(chapter.id).attempts, 1);
      expect(harness.routes, [ChapterCompletedScreen.routeName]);
      expect(find.text('Finish Quiz'), findsNothing);

      // Nothing is waiting behind the completed screen to push it again.
      await tester.pump(const Duration(milliseconds: 500));
      expect(harness.routes, [ChapterCompletedScreen.routeName]);
      expect(harness.progress.runRecords, 1);
    });

    testWidgets('the reward is granted once, not once per tap', (tester) async {
      _useTallPhone(tester);
      final harness = await _pump(tester, QuizScreen(chapterId: 'ch01'));
      final chapter = harness.content.chapters.first;
      await _answerUpToLastQuestion(tester, chapter);

      final gate = harness.progress.holdNextRunRecord();
      await tester.tap(find.text('Finish Quiz'));
      await tester.pump();
      await tester.tap(find.text('Finish Quiz'), warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();

      // A perfect five-question run: one completion, one reward.
      final record = harness.progress.progress.chapter(chapter.id);
      expect(record.attempts, 1);
      expect(record.stars, 3);
      expect(record.bestScorePercent, 100);
      expect(harness.progress.progress.totalXp, chapter.rewards.xp);
      expect(harness.progress.progress.coins, chapter.rewards.coins);
    });

    testWidgets('a failed finish releases the guard so it can be retried',
        (tester) async {
      _useTallPhone(tester);
      final harness = await _pump(tester, QuizScreen(chapterId: 'ch01'));
      final chapter = harness.content.chapters.first;
      await _answerUpToLastQuestion(tester, chapter);

      harness.progress
          .holdNextRunRecord(error: StateError('store unavailable'));
      await tester.tap(find.text('Finish Quiz'));
      await tester.pumpAndSettle();

      // The learner is still on the quiz, and the button is live again.
      expect(harness.routes, isEmpty);
      expect(find.text('Finish Quiz'), findsOneWidget);
      expect(tester.widget<InkWell>(_buttonInkWell('Finish Quiz')).onTap,
          isNotNull);

      // Retry: this one is accepted, and navigates exactly once.
      final retryGate = harness.progress.holdNextRunRecord();
      await tester.tap(find.text('Finish Quiz'));
      await tester.pump();
      expect(harness.progress.runRecords, 2);
      retryGate.complete();
      await tester.pumpAndSettle();

      expect(harness.routes, [ChapterCompletedScreen.routeName]);
      expect(harness.progress.progress.chapter(chapter.id).attempts, 1);
    });
  });
}

/// The InkWell that carries a button label — the tappable for [label].
Finder _buttonInkWell(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(InkWell),
    );

/// The tappable of the answer tile whose text is [option].
Finder _optionInkWell(String option) => _buttonInkWell(option);
