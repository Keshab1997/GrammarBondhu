import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/router.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/core/utils/asset_lookup.dart';
import 'package:grammar_bondhu/features/chapters/chapter_detail_screen.dart';
import 'package:grammar_bondhu/features/grammar/grammar_lesson_screen.dart';
import 'package:grammar_bondhu/features/chapters/chapter_list_screen.dart';
import 'package:grammar_bondhu/features/home/home_shell.dart';
import 'package:grammar_bondhu/features/profile/profile_screen.dart';
import 'package:grammar_bondhu/features/progress/progress_screen.dart';
import 'package:grammar_bondhu/features/rewards/rewards_screen.dart';
import 'package:grammar_bondhu/features/settings/offline_download_screen.dart';
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
          onGenerateRoute: AppRouter.onGenerateRoute,
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

  testWidgets('Resume opens the next unread scene, then the grammar lesson',
      (tester) async {
    await _pump(tester, const ChapterDetailScreen(chapterId: 'ch01'),
        const Size(353, 784));
    final detail = tester.element(find.byType(ChapterDetailScreen));
    final chapter = detail.read<ContentController>().byId('ch01')!;
    final progress = detail.read<ProgressController>();
    final scenes = chapter.scenes;

    Future<void> finishScene(int index) async {
      for (final _ in scenes[index].dialogue) {
        // The stage advances on tap, whether or not the scene offers choices.
        await tester.tapAt(const Offset(176, 120));
        await tester.pumpAndSettle();
      }
      expect(progress.chapterProgress(chapter.id).resumeSceneIndex, index + 1);
    }

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    await finishScene(0);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Scene 2 of ${scenes.length}'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(tester.widget<StoryScreen>(find.byType(StoryScreen)).args.startScene,
        1);
    expect(find.text(scenes[1].dialogue.first.text.en), findsOneWidget);

    for (var i = 1; i < scenes.length; i++) {
      await finishScene(i);
    }
    expect(find.byType(GrammarLessonScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.textContaining('Ready for the grammar lesson'), findsOneWidget);
    expect(find.textContaining('Scene ${scenes.length + 1}'), findsNothing);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    final lesson = tester.element(find.byType(GrammarLessonScreen));
    expect(ModalRoute.of(lesson)!.settings.name, GrammarLessonScreen.routeName);
    expect(ModalRoute.of(lesson)!.settings.arguments, chapter.id);
  });

  for (final standalone in [false, true]) {
    testWidgets(
        'Profile → Achievements opens Rewards (standalone: $standalone)',
        (tester) async {
      await _pump(
          tester,
          standalone
              ? const Scaffold(body: ProfileScreen())
              : const HomeShell(initialTab: 99),
          const Size(412, 915));
      final profile = find.byType(ProfileScreen);
      final achievements =
          find.descendant(of: profile, matching: find.text('Achievements'));
      await tester.scrollUntilVisible(achievements, 240,
          scrollable:
              find.descendant(of: profile, matching: find.byType(Scrollable)));
      await tester.tap(achievements);
      await tester.pumpAndSettle();
      final rewards = tester.element(find.byType(RewardsScreen));
      expect(Navigator.of(rewards).canPop(), standalone);
      if (standalone) {
        final route = ModalRoute.of(rewards)!.settings;
        expect(route.name, HomeShell.routeName);
        expect(route.arguments, 2);
      } else {
        // An in-shell jump keeps the original route, even on repeated jumps.
        expect(HomeShell.selectTab(rewards, -1), isTrue);
        await tester.pumpAndSettle();
        expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);
      }
    });
  }

  testWidgets('offline chapters are included, not waiting to download',
      (tester) async {
    await _pump(tester, const OfflineDownloadScreen(), const Size(353, 784));
    expect(find.textContaining('no download needed'), findsOneWidget);
    expect(find.text('Included'), findsWidgets);
    expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
    expect(find.text('Download'), findsNothing);
  });

  testWidgets('chapter list filters by real chapter state', (tester) async {
    await _pump(tester, const ChapterListScreen(), const Size(353, 784));

    final list = tester.element(find.byType(ChapterListScreen));
    final chapters = list.read<ContentController>().chapters;
    final progress = list.read<ProgressController>();

    // ch01 starts unlocked; the remaining chapters stay locked in a fresh run.
    expect(find.text(chapters.first.title.en), findsOneWidget);
    expect(find.textContaining('to unlock'), findsWidgets);

    await tester.tap(find.text('Locked'));
    await tester.pumpAndSettle();
    expect(find.text(chapters.first.title.en), findsNothing);
    expect(find.text(chapters[1].title.en), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(chapters.last.title.en),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(chapters.last.title.en), findsOneWidget);

    await tester.tap(find.text('Started'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No chapters in progress'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.textContaining('to unlock'), findsNothing);
    expect(find.textContaining('No completed chapters'), findsOneWidget);

    for (final chapter in chapters) {
      await progress.recordQuizRun(chapter: chapter, correct: 1, total: 1);
    }
    await tester.tap(find.text('Locked'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Every chapter is unlocked'), findsOneWidget);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text(chapters.first.title.en), findsOneWidget);
  });

  testWidgets(
      'grammar lesson shows dynamic chapter examples and tap-to-reveal answers',
      (tester) async {
    await _pump(
      tester,
      const GrammarLessonScreen(chapterId: 'ch11'),
      const Size(390, 844),
    );
    final ctx = tester.element(find.byType(GrammarLessonScreen));
    final ch11 = ctx.read<ContentController>().byId('ch11')!;

    // Page 1 shows ch11's own grammar rule, never ch01's hardcoded am/is/are.
    expect(find.text(ch11.lesson.title.en), findsOneWidget);

    // Page 2 shows ch11's real example sentences and trilingual notes.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(
      find.text(ch11.lesson.examples.first.sentence),
      findsOneWidget,
    );
    expect(find.text('Rahul is my friend.'), findsNothing);

    // Page 3 hides the answer key until the learner taps "Show answers".
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Answers:'), findsNothing);
    expect(find.text('Show answers'), findsOneWidget);

    await tester.ensureVisible(find.text('Show answers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show answers'));
    await tester.pumpAndSettle();
    expect(find.text('Hide answers'), findsOneWidget);
    expect(
      find.textContaining('Answers: ${ch11.quiz.first.correctAnswer}'),
      findsOneWidget,
    );

    // Switching the board language flips the answer toggle to Bengali cleanly.
    await tester.tap(find.text('বাংলা'));
    await tester.pumpAndSettle();
    expect(find.text('উত্তর লুকাও'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress screen renders chapter XP bars cleanly with semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pump(
        tester,
        ProgressScreen(now: DateTime(2026, 11, 18, 10)),
        const Size(390, 844),
      );
      final ctx = tester.element(find.byType(ProgressScreen));
      final content = ctx.read<ContentController>();
      final progress = ctx.read<ProgressController>();
      await progress.recordQuizRun(
        chapter: content.byId('ch01')!,
        correct: 5,
        total: 5,
        now: DateTime(2026, 11, 18, 9),
      );
      await progress.recordQuizRun(
        chapter: content.byId('ch02')!,
        correct: 4,
        total: 5,
        now: DateTime(2026, 11, 18, 10),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final tab in ['Chapters', 'Stats', 'Review', 'Overview']) {
        await tester.tap(find.text(tab).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.scrollUntilVisible(
        find.text(content.byId('ch01')!.title.en),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text(content.byId('ch01')!.title.en), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
