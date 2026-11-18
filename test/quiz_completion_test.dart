import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/router.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/app/theme/app_theme.dart';
import 'package:grammar_bondhu/data/local/json_loader.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/models/chapter.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/chapters/chapter_list_screen.dart';
import 'package:grammar_bondhu/features/completion/chapter_completed_screen.dart';
import 'package:grammar_bondhu/features/quiz/quiz_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hold a save open across taps without relying on timers. The real
/// controller still computes the reward, updates review and saves progress.
class _ControlledProgress extends ProgressController {
  _ControlledProgress(LocalStore store) : super(store, store.loadProgress());

  Completer<void>? answerSave;
  Completer<void>? finishSave;
  int finishCalls = 0;

  @override
  Future<void> registerQuestionAnswered({DateTime? now}) async {
    await answerSave?.future;
    await super.registerQuestionAnswered(now: now);
  }

  @override
  Future<QuizRunResult> recordQuizRun({
    required Chapter chapter,
    required int correct,
    required int total,
    DateTime? now,
  }) async {
    finishCalls++;
    await finishSave?.future;
    return super.recordQuizRun(
        chapter: chapter, correct: correct, total: total, now: now);
  }
}

/// Exercise a level that is not in this checkpoint's bundled manifest. Keep
/// the real chapter, translations and navigation; only the difficulty differs.
class _IntermediateChapterLoader extends JsonLoader {
  _IntermediateChapterLoader(this.chapterId);

  final String chapterId;

  @override
  Future<Map<String, dynamic>> loadJsonMap(String assetPath) async {
    final json = await super.loadJsonMap(assetPath);
    return json['chapter_id'] == chapterId
        ? {...json, 'difficulty': '  InTeRmEdIaTe  '}
        : json;
  }
}

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<
        ({
          Chapter chapter,
          SettingsController settings,
          _ControlledProgress progress,
          List<CompletedArgs> completions
        })>
    _pumpQuiz(WidgetTester tester,
        {bool emptyQuiz = false, String supportLanguage = 'en'}) async {
  _viewport(tester, const Size(412, 915));
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final progress = _ControlledProgress(store);
  final settings = SettingsController(
      store, store.loadSettings()..supportLanguage = supportLanguage);
  final content = ContentController(ContentRepository());
  await content.load();
  final chapter = content.chapters.first;
  if (emptyQuiz) chapter.quiz.clear();
  final completions = <CompletedArgs>[];
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<ProgressController>.value(value: progress),
      ChangeNotifierProvider.value(value: content),
      ChangeNotifierProvider.value(value: settings),
    ],
    child: MaterialApp(
      home: QuizScreen(chapterId: chapter.id),
      onGenerateRoute: (settings) {
        if (settings.name == ChapterCompletedScreen.routeName) {
          completions.add(settings.arguments! as CompletedArgs);
        }
        return AppRouter.onGenerateRoute(settings);
      },
    ),
  ));
  await tester.pumpAndSettle();
  return (
    chapter: chapter,
    settings: settings,
    progress: progress,
    completions: completions
  );
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _answerRemaining(
    WidgetTester tester, Iterable<QuizQuestion> questions) async {
  for (final q in questions) {
    await _tap(tester, q.correctAnswer);
    await _tap(tester, 'Submit');
    if (find.text('Next Question').evaluate().isNotEmpty) {
      await _tap(tester, 'Next Question');
    }
  }
}

void main() {
  testWidgets('Finish records and celebrates once, even while saving',
      (tester) async {
    final h = await _pumpQuiz(tester);
    await _answerRemaining(tester, h.chapter.quiz);
    final save = h.progress.finishSave = Completer<void>();
    final finish = find.text('Finish Quiz');
    await tester.ensureVisible(finish);
    await tester.tap(finish);
    await tester.tap(finish); // Before the disabled button has rebuilt.
    await tester.pump();
    await tester.tap(finish); // Still saving, but after the rebuild.
    expect(h.progress.finishCalls, 1);
    expect(h.completions, isEmpty);

    save.complete();
    await tester.pumpAndSettle();
    expect(h.completions.single.chapterId, h.chapter.id);
    expect(find.byType(ChapterCompletedScreen), findsOneWidget);
    expect(h.progress.chapterProgress(h.chapter.id).attempts, 1);
    expect(h.progress.progress.totalXp, h.chapter.rewards.xp);
    expect(h.progress.progress.coins, h.chapter.rewards.coins);
  });

  testWidgets('Finish can be retried after a failed save', (tester) async {
    final h = await _pumpQuiz(tester);
    await _answerRemaining(tester, h.chapter.quiz);
    final save = h.progress.finishSave = Completer<void>();
    await _tap(tester, 'Finish Quiz');
    save.completeError(StateError('save unavailable'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Could not save your quiz'), findsOneWidget);
    expect(h.completions, isEmpty);

    h.progress.finishSave = null;
    await tester
        .pump(const Duration(seconds: 5)); // Let the error snackbar leave.
    await tester.pumpAndSettle();
    await _tap(tester, 'Finish Quiz');
    expect(h.progress.finishCalls, 2);
    expect(h.completions, hasLength(1));
    expect(h.progress.chapterProgress(h.chapter.id).attempts, 1);
  });

  testWidgets('option taps cannot change an answer during submission',
      (tester) async {
    final h = await _pumpQuiz(tester);
    final q = h.chapter.quiz.first;
    final other = find.text(q.options[(q.correctIndex + 1) % q.options.length]);
    await _tap(tester, q.correctAnswer);
    final save = h.progress.answerSave = Completer<void>();
    await tester.tap(find.text('Submit'));
    await tester.tap(other); // Stale tile callback from the previous frame.
    await tester.pump();
    await tester.tap(other);
    save.complete();
    await tester.pumpAndSettle();
    expect(find.text('Correct!'), findsOneWidget);
    expect(find.text('Try Again'), findsNothing);
    expect(h.progress.progress.questionsAnsweredToday, 1);
  });

  testWidgets('Try Again updates feedback, not the first-attempt result',
      (tester) async {
    final h = await _pumpQuiz(tester);
    final quiz = h.chapter.quiz;
    final q = quiz.first;
    await _tap(tester, q.options[(q.correctIndex + 1) % q.options.length]);
    await _tap(tester, 'Submit');
    expect(find.text('Incorrect'), findsOneWidget);
    await _tap(tester, 'हिन्दी');
    expect(find.text(q.explanation.hi!), findsOneWidget);
    await _tap(tester, 'Try Again');
    await _tap(tester, q.correctAnswer);
    await _tap(tester, 'Submit');
    expect(find.text('Correct!'), findsOneWidget);
    expect(find.text(q.explanation.en), findsOneWidget);
    expect(h.progress.chapterProgress(h.chapter.id).missedQuestionIds,
        contains(q.id));
    expect(h.progress.progress.questionsAnsweredToday, 1);

    await _tap(tester, 'Next Question');
    await _answerRemaining(tester, quiz.skip(1));
    await _tap(tester, 'Finish Quiz');
    expect(h.completions.single.result.percent,
        (100 * (quiz.length - 1) / quiz.length).round());
    expect(h.progress.progress.questionsAnsweredToday, quiz.length);
  });

  testWidgets('explanations switch for one question, not the global preference',
      (tester) async {
    final h = await _pumpQuiz(tester, supportLanguage: 'bn');
    final q = h.chapter.quiz.first;
    expect(find.text('हिन्दी'), findsNothing);
    await _tap(tester, q.correctAnswer);
    await _tap(tester, 'Submit');
    expect(find.text(q.explanation.bn!), findsOneWidget);

    for (final (label, code) in [
      ('EN', 'en'),
      ('বাংলা', 'bn'),
      ('हिन्दी', 'hi')
    ]) {
      await _tap(tester, label);
      for (final language in ['en', 'bn', 'hi']) {
        expect(find.text(q.explanation.of(language)),
            language == code ? findsOneWidget : findsNothing);
      }
      expect(h.settings.supportLanguage, 'bn');
    }
    await _tap(tester, 'Next Question');
    expect(find.text('हिन्दी'), findsNothing);
    final next = h.chapter.quiz[1];
    await _tap(tester, next.correctAnswer);
    await _tap(tester, 'Submit');
    expect(find.text(next.explanation.bn!), findsOneWidget);
    expect(find.text(next.explanation.hi!), findsNothing);
    expect(h.settings.supportLanguage, 'bn');
  });

  testWidgets('chapter list and detail follow the support language and level',
      (tester) async {
    _viewport(tester, const Size(320, 640));
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    final settings = SettingsController(store, store.loadSettings());
    const chapterId = 'ch03';
    final content = ContentController(
        ContentRepository(_IntermediateChapterLoader(chapterId)));
    await content.load();
    final progress = ProgressController(store, store.loadProgress());
    final chapter = content.byId(chapterId)!;
    for (final previous
        in content.chapters.takeWhile((c) => c.id != chapter.id)) {
      await progress.recordQuizRun(chapter: previous, correct: 1, total: 1);
    }
    await progress.openChapter(chapter.id, -5);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: content),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: progress),
      ],
      child: MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const ChapterListScreen(),
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    ));
    await tester.pumpAndSettle();
    final beginner = content.chapters.first;
    // This chapter's Bengali grammar topic is identical to the English one.
    expect(find.text(beginner.grammarTopic.en), findsOneWidget);
    expect(find.text('Beginner'), findsNothing);
    await _tap(tester, 'Started');
    final steps = chapter.scenes.length + 1;
    expect(find.text('Step 1 of $steps'), findsOneWidget);
    await progress.openChapter(chapter.id, steps + 10);
    await tester.pumpAndSettle();
    expect(find.text('Step $steps of $steps'), findsOneWidget);
    expect(find.text(chapter.grammarTopic.en), findsOneWidget);
    expect(find.text(chapter.grammarTopic.bn!), findsOneWidget);
    expect(find.text('Intermediate'), findsOneWidget);
    await settings.setSupportLanguage('en');
    await tester.pumpAndSettle();
    expect(find.text(chapter.grammarTopic.bn!), findsNothing);
    await settings.setSupportLanguage('hi');
    await tester.pumpAndSettle();
    expect(find.text(chapter.grammarTopic.hi!), findsOneWidget);

    await _tap(tester, chapter.title.en);
    expect(find.text('Intermediate'), findsOneWidget);
    expect(find.text(chapter.title.en), findsOneWidget);
    expect(find.text(chapter.description.en), findsOneWidget);
    expect(find.text(chapter.title.hi!), findsOneWidget);
    expect(find.text(chapter.description.hi!), findsOneWidget);
    await settings.setSupportLanguage('bn');
    await tester.pumpAndSettle();
    expect(find.text(chapter.title.bn!), findsOneWidget);
    expect(find.text(chapter.description.bn!), findsOneWidget);
    await settings.setSupportLanguage('en');
    await tester.pumpAndSettle();
    expect(find.text(chapter.title.bn!), findsNothing);
    expect(find.text(chapter.description.bn!), findsNothing);
    expect(find.text(chapter.description.en), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty quiz offers no submit or reward', (tester) async {
    final h = await _pumpQuiz(tester, emptyQuiz: true);
    expect(find.textContaining('No quiz questions'), findsOneWidget);
    expect(find.text('Submit'), findsNothing);
    expect(h.progress.finishCalls, 0);
    expect(tester.takeException(), isNull);
  });

  for (final (percent, praise) in [
    (89, 'You did a great job!'),
    (90, 'You did an amazing job!')
  ]) {
    testWidgets('completion at $percent% fits a 320 dp phone at 200% text',
        (tester) async {
      _viewport(tester, const Size(320, 640));
      final content = ContentController(ContentRepository());
      await content.load();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: content,
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ChapterCompletedScreen(
              args: CompletedArgs(
            chapterId: content.chapters.first.id,
            result: QuizRunResult(
                percent: percent,
                stars: 3,
                xpEarned: 50,
                coinsEarned: 10,
                isPersonalBest: true,
                firstCompletion: true),
          )),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.text(praise), findsOneWidget);
      expect(find.text('+50 XP'), findsOneWidget);
      expect(find.text('+10 Coins'), findsOneWidget);
      final finish = find.text('Finish for now');
      await tester.ensureVisible(finish);
      expect(finish.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
