import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/models/progress.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/home/home_screen.dart';
import 'package:grammar_bondhu/features/home/home_shell.dart';
import 'package:grammar_bondhu/features/quiz/review_practice_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The home screen is a dense dashboard, so it has to survive the narrowest
/// phone it will meet. 320 dp is the floor Flutter supports; 353 dp is the
/// Pixel-class device the design was drawn for. Both used to overflow.
Future<({ContentController content, ProgressController progress})> _pumpHome(
  WidgetTester tester,
  Size size, {
  bool allChaptersComplete = false,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final content = ContentController(ContentRepository());
  await content.load();
  final initialProgress = allChaptersComplete
      ? UserProgress(
          chapters: {
            for (final chapter in content.chapters)
              chapter.id: ChapterProgress(
                chapterId: chapter.id,
                completed: true,
              ),
          },
        )
      : store.loadProgress();
  final progress = ProgressController(store, initialProgress);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: content),
        ChangeNotifierProvider(
          create: (_) => SettingsController(store, store.loadSettings()),
        ),
        ChangeNotifierProvider.value(value: progress),
      ],
      child: MaterialApp(
        home: const HomeShell(),
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
  return (content: content, progress: progress);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bottom navigation exposes button and selected semantics',
      (tester) async {
    await _pumpHome(tester, const Size(353, 784));
    final semantics = tester.ensureSemantics();

    final home =
        tester.getSemantics(find.bySemanticsLabel('Home')).flagsCollection;
    expect(home.isButton, isTrue);
    expect(home.isSelected.toBoolOrNull(), isTrue);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    final library =
        tester.getSemantics(find.bySemanticsLabel('Library')).flagsCollection;
    expect(library.isButton, isTrue);
    expect(library.isSelected.toBoolOrNull(), isTrue);
    semantics.dispose();
  });

  testWidgets('completed course offers a clear chapter review path',
      (tester) async {
    await _pumpHome(
      tester,
      const Size(353, 784),
      allChaptersComplete: true,
    );

    expect(find.text('Course complete!'), findsOneWidget);
    expect(find.text('Review chapters'), findsOneWidget);
    expect(find.text('Continue Your Journey'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('course counts only loaded chapters and bounds the resume step',
      (tester) async {
    final harness = await _pumpHome(tester, const Size(412, 915));
    final chapters = harness.content.chapters;
    final chapter = chapters.first;
    for (var i = 0; i < chapters.length; i++) {
      harness.progress.chapterProgress('archived-$i').completed = true;
    }
    await harness.progress.openChapter(chapter.id, chapter.scenes.length + 20);
    await tester.pumpAndSettle();

    final lastStep = chapter.scenes.length + 1;
    expect(find.text('Course complete!'), findsNothing);
    expect(find.text('Step $lastStep of $lastStep'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Your Course'), 180);
    expect(find.text('0/${chapters.length}'), findsOneWidget);
    expect(find.text('Current chapter · Step $lastStep of $lastStep'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('Home shows a tappable review nudge at ${scale * 100}% text',
        (tester) async {
      final harness = await _pumpHome(
        tester,
        const Size(320, 640),
        textScale: scale,
      );
      final homeScroll = find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(find.text('Daily Goal'), 240,
          scrollable: homeScroll);
      final position = tester.state<ScrollableState>(homeScroll).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final review = find.text('Review Mistakes');
      expect(review, findsNothing);

      final chapter = harness.content.chapters.first;
      final question = chapter.quiz.first;
      // Leftover IDs from old content should not inflate the nudge.
      await harness.progress
          .markQuestionForReview(chapter.id, 'retired-question');
      await tester.pumpAndSettle();
      expect(review, findsNothing);
      await harness.progress.markQuestionForReview(chapter.id, question.id);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(review, 180, scrollable: homeScroll);
      expect(find.text('1 question waiting for another try'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(find.byType(ReviewPracticeScreen), findsOneWidget);
      expect(find.text(question.question), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in const [Size(320, 640), Size(353, 784), Size(412, 915)]) {
    testWidgets('home lays out cleanly at ${size.width.toInt()} dp wide',
        (tester) async {
      await _pumpHome(tester, size);

      // A RenderFlex overflow is reported as a framework exception.
      expect(tester.takeException(), isNull);

      // The greeting must stay on one line rather than being squeezed out.
      expect(find.text('Hello, Rahul!'), findsOneWidget);

      // Scroll the whole dashboard; every card must lay out at this width.
      await tester.scrollUntilVisible(find.text('Daily Goal'), 240);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
