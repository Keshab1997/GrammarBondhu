import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/core/utils/asset_lookup.dart';
import 'package:grammar_bondhu/features/chapters/chapter_detail_screen.dart';
import 'package:grammar_bondhu/features/grammar/grammar_lesson_screen.dart';
import 'package:grammar_bondhu/features/chapters/chapter_list_screen.dart';
import 'package:grammar_bondhu/features/story/story_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layout regressions from the screen audit.
///
/// Before these tests: chapter detail overflowed its card by 368 px at 353 dp
/// (687 px at 320 dp), the story's language chips were 135 px wider than the
/// screen, and the chapter list's filter chips overflowed by 30 px. All three
/// shipped because nothing measured them.
Future<void> _pump(WidgetTester tester, Widget screen, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final content = ContentController(ContentRepository());
  await content.load();

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: content),
        ChangeNotifierProvider(
          create: (_) => SettingsController(store, store.loadSettings()),
        ),
        ChangeNotifierProvider(
          create: (_) => ProgressController(store, store.loadProgress()),
        ),
      ],
      // The story stage has a continuous idle bob; asking for reduced motion is
      // how a test gets a tree that settles (and how the OS gets a still app).
      child: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: screen,
          theme: ThemeData(useMaterial3: true),
          onUnknownRoute: (settings) =>
              MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final screens = <String, Widget>{
    'chapter detail': const ChapterDetailScreen(chapterId: 'ch01'),
    'chapter list': const ChapterListScreen(),
    'story': const StoryScreen(args: StoryArgs('ch01')),
  };

  for (final size in const [Size(320, 640), Size(353, 784), Size(412, 915)]) {
    for (final entry in screens.entries) {
      testWidgets(
          '${entry.key} has no layout error at ${size.width.toInt()} dp',
          (tester) async {
        await _pump(tester, entry.value, size);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('chapter detail keeps its call to action on screen',
      (tester) async {
    await _pump(tester, const ChapterDetailScreen(chapterId: 'ch01'),
        const Size(320, 640));

    final start = find.text('Start');
    expect(start, findsOneWidget);
    // Pinned outside the scroll view, so it is visible without scrolling.
    final rect = tester.getRect(start);
    expect(rect.bottom, lessThanOrEqualTo(640));
  });

  testWidgets('chapter detail names what the chapter teaches', (tester) async {
    await _pump(tester, const ChapterDetailScreen(chapterId: 'ch01'),
        const Size(353, 784));
    final content = ContentController(ContentRepository());
    await content.load();
    final chapter = content.byId('ch01')!;

    expect(find.text(chapter.grammarTopic.en), findsOneWidget);
    expect(find.text('GRAMMAR FOCUS'), findsOneWidget);
    expect(find.text('Story'), findsOneWidget);
    expect(find.text('Quiz'), findsOneWidget);
  });

  testWidgets('story translation is opt-in and sticks once chosen',
      (tester) async {
    await _pump(tester, const StoryScreen(args: StoryArgs('ch01')),
        const Size(353, 784));

    final content = ContentController(ContentRepository());
    await content.load();
    final english = content.byId('ch01')!.scenes.first.dialogue.first.text.en;

    // English only at first: no second-language line under the dialogue.
    expect(find.text(english), findsOneWidget);
    expect(find.text('BENGALI'), findsNothing);

    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();

    expect(find.text('BENGALI'), findsOneWidget);
  });

  testWidgets('story bubble sits above the speaker, not over them',
      (tester) async {
    await _pump(tester, const StoryScreen(args: StoryArgs('ch01')),
        const Size(353, 784));

    final bubble = tester.getRect(find.byType(AnimatedOpacity).first);
    // The bubble must end above the stage floor, with the speaker drawn below.
    expect(bubble.bottom, lessThan(784));

    // Every character asset for the scene resolves from the full-body map.
    expect(AssetLookup.fullBodyPath('rahul'), isNotNull);
    expect(AssetLookup.fullBodyPath('teacher'), isNotNull);
    expect(AssetLookup.fullBodyPath('priya'), isNotNull);

    // The blurred foreground plate is what gives the scene depth; every
    // background ch01 uses must have one.
    expect(AssetLookup.foregroundPath('bg_school_gate'), isNotNull);
    expect(AssetLookup.foregroundPath('bg_classroom'), isNotNull);
    expect(AssetLookup.foregroundPath('bg_does_not_exist'), isNull);
  });

  testWidgets('grammar lesson turns its three board pages', (tester) async {
    await _pump(tester, const GrammarLessonScreen(chapterId: 'ch01'),
        const Size(353, 784));
    await tester.pump(const Duration(seconds: 2));

    // Page 1: the rule, written on the board.
    expect(find.text('TODAY’S RULE'), findsOneWidget);
    expect(find.text('am / is / are'), findsOneWidget);
    expect(find.textContaining('We use am with I'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    // Page 2: examples, with the translation under each one.
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('I am a student.'), findsOneWidget);
    expect(find.text('He is my friend.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Page 3: the learner's turn, and only then the quiz.
    await tester.tap(find.text('Next'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Say it yourself'), findsOneWidget);
    expect(find.text('Start the quiz'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(320, 640), Size(412, 915)]) {
    testWidgets('grammar lesson fits ${size.width.toInt()} dp', (tester) async {
      await _pump(tester, const GrammarLessonScreen(chapterId: 'ch01'), size);
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('chapter list filters by real chapter state', (tester) async {
    await _pump(tester, const ChapterListScreen(), const Size(353, 784));

    // All five chapters, four of them locked in a fresh profile.
    expect(find.textContaining('to unlock'), findsNWidgets(4));

    await tester.tap(find.text('Locked'));
    await tester.pumpAndSettle();
    expect(find.textContaining('to unlock'), findsNWidgets(4));

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.textContaining('to unlock'), findsNothing);
  });
}
