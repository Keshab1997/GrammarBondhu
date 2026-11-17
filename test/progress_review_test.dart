import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/progress/progress_screen.dart';
import 'package:grammar_bondhu/features/quiz/quiz_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    expect(progress.progress.missedQuestionCount, 0);
    expect(tester.takeException(), isNull);
  });
}
