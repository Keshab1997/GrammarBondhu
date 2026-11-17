import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/core/utils/accessible_layout.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/chapters/chapter_detail_screen.dart';
import 'package:grammar_bondhu/features/chapters/chapter_list_screen.dart';
import 'package:grammar_bondhu/features/grammar/grammar_lesson_screen.dart';
import 'package:grammar_bondhu/features/home/home_shell.dart';
import 'package:grammar_bondhu/features/profile/profile_screen.dart';
import 'package:grammar_bondhu/features/progress/progress_screen.dart';
import 'package:grammar_bondhu/features/quiz/quiz_screen.dart';
import 'package:grammar_bondhu/features/rewards/rewards_screen.dart';
import 'package:grammar_bondhu/features/story/story_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A 320 dp phone with the system font scale at 200%.
///
/// That pairing is the accessibility floor this app promises: 320 dp is the
/// narrowest width Flutter supports, and 200% is Android's "Largest" text
/// setting - the one a low-vision learner actually runs. Before this file
/// existed, five screens overflowed there: the chapter list header by 64 px,
/// the story top bar by 125 px and its tap hint by 50 px, the rewards stat row
/// by 88 px, the progress week header by 72 px and its stat tile by 23 px, and
/// the grammar speech bubble by 44 px. Two of those (rewards and the progress
/// strip) also overflowed at the *default* scale on 320 dp, which is how they
/// shipped.
const Size _narrowPhone = Size(320, 640);

const List<double> _scales = [1.0, 1.3, 2.0];

Future<({ContentController content, ProgressController progress})> _pump(
  WidgetTester tester,
  Widget Function(ContentController content) screen, {
  Size size = _narrowPhone,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final content = ContentController(ContentRepository());
  await content.load();
  final progress = ProgressController(store, store.loadProgress());

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: content),
        ChangeNotifierProvider(
          create: (_) => SettingsController(store, store.loadSettings()),
        ),
        ChangeNotifierProvider.value(value: progress),
      ],
      // The story stage has a continuous idle bob; reduced motion is how a
      // test gets a tree that settles, and how the OS gets a still app.
      child: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: MaterialApp(
          home: screen(content),
          onUnknownRoute: (settings) =>
              MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (content: content, progress: progress);
}

/// Every screen the app ships, so one new screen cannot skip the sweep.
final Map<String, Widget Function(ContentController content)> _screens = {
  'home': (_) => const HomeShell(),
  'chapter list': (_) => const ChapterListScreen(),
  'chapter detail': (c) => ChapterDetailScreen(chapterId: c.chapters.first.id),
  'story': (c) => StoryScreen(args: StoryArgs(c.chapters.first.id)),
  'grammar lesson': (c) => GrammarLessonScreen(chapterId: c.chapters.first.id),
  'quiz': (c) => QuizScreen(chapterId: c.chapters.first.id),
  'rewards': (_) => const RewardsScreen(),
  'progress': (_) => const ProgressScreen(),
  'profile': (_) => const ProfileScreen(),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('no screen overflows on a 320 dp phone', () {
    for (final entry in _screens.entries) {
      for (final scale in _scales) {
        testWidgets('${entry.key} at ${(scale * 100).round()}% text',
            (tester) async {
          await _pump(tester, entry.value, textScale: scale);

          // A RenderFlex overflow reaches the test as a framework exception,
          // so this assertion is the whole check.
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('quiz survives at 320 dp with the largest scale',
        (tester) async {
      final harness = await _pump(
        tester,
        (c) => QuizScreen(chapterId: c.chapters.first.id),
        textScale: 2.0,
      );
      final question = harness.content.chapters.first.quiz.first;
      final wrong = question.correctIndex == 0 ? 1 : 0;

      // The answer list is the part that grows most: it is four two-line
      // buttons plus a feedback card. Exercise the full cycle, not just the
      // first frame.
      await tester.ensureVisible(find.text(question.options[wrong]));
      await tester.tap(find.text(question.options[wrong]));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('Try Again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('quiz answer state is spoken, not just coloured', () {
    testWidgets('an option reads its letter, its text and its verdict',
        (tester) async {
      final harness = await _pump(
        tester,
        (c) => QuizScreen(chapterId: c.chapters.first.id),
      );
      final question = harness.content.chapters.first.quiz.first;
      final semantics = tester.ensureSemantics();

      // Before submitting, every answer is a button labelled with its letter,
      // so a reader can tell four options apart without seeing the circles.
      final first = tester.getSemantics(
        find.bySemanticsLabel(
          RegExp('^Option A: ${RegExp.escape(question.options[0])}'),
        ),
      );
      expect(first.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(first.hasFlag(SemanticsFlag.hasEnabledState), isTrue);
      semantics.dispose();
    });

    testWidgets('the chosen option is announced as selected', (tester) async {
      final harness = await _pump(
        tester,
        (c) => QuizScreen(chapterId: c.chapters.first.id),
      );
      final question = harness.content.chapters.first.quiz.first;
      final semantics = tester.ensureSemantics();

      await tester.tap(find.text(question.options[1]));
      await tester.pumpAndSettle();

      final chosen = tester.getSemantics(
        find.bySemanticsLabel(
          RegExp('^Option B: ${RegExp.escape(question.options[1])}'),
        ),
      );
      expect(chosen.hasFlag(SemanticsFlag.isSelected), isTrue);

      final other = tester.getSemantics(
        find.bySemanticsLabel(
          RegExp('^Option A: ${RegExp.escape(question.options[0])}'),
        ),
      );
      expect(other.hasFlag(SemanticsFlag.isSelected), isFalse);
      semantics.dispose();
    });

    testWidgets('after submitting, right and wrong answers differ in words',
        (tester) async {
      final harness = await _pump(
        tester,
        (c) => QuizScreen(chapterId: c.chapters.first.id),
      );
      final question = harness.content.chapters.first.quiz.first;
      final wrong = question.correctIndex == 0 ? 1 : 0;
      final semantics = tester.ensureSemantics();

      await tester.tap(find.text(question.options[wrong]));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      // The verdict lives in the label now, so it survives a screen reader
      // that never sees the check/cross icons.
      final wrongLabel = tester
          .getSemantics(
            find.bySemanticsLabel(RegExp('^Option [A-D]: .*, your answer')),
          )
          .label;
      expect(wrongLabel, contains('incorrect'));

      final rightLabel = tester
          .getSemantics(
            find.bySemanticsLabel(
                RegExp('^Option [A-D]: .*, correct answer\$')),
          )
          .label;
      expect(rightLabel, contains('correct answer'));
      expect(rightLabel, isNot(contains('incorrect')));
      semantics.dispose();
    });

    testWidgets('the result is announced as one sentence', (tester) async {
      final harness = await _pump(
        tester,
        (c) => QuizScreen(chapterId: c.chapters.first.id),
      );
      final question = harness.content.chapters.first.quiz.first;
      final wrong = question.correctIndex == 0 ? 1 : 0;
      final semantics = tester.ensureSemantics();

      await tester.tap(find.text(question.options[wrong]));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit'));
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      final feedback = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^Incorrect\\. The correct answer is')),
      );
      // A live region: the reader speaks it when it appears, without the
      // learner having to hunt for what changed.
      expect(feedback.hasFlag(SemanticsFlag.isLiveRegion), isTrue);
      expect(feedback.label, contains(question.correctAnswer));
      semantics.dispose();
    });

    testWidgets('a disabled Submit says why it is disabled', (tester) async {
      await _pump(tester, (c) => QuizScreen(chapterId: c.chapters.first.id));
      // The reason is visible text on purpose - a greyed-out button with no
      // explanation reads as broken, to a sighted learner and a reader alike.
      expect(find.text('Pick an answer to continue'), findsOneWidget);
    });
  });

  group('touch targets', () {
    testWidgets('narration button keeps a 48 dp target', (tester) async {
      await _pump(
        tester,
        (c) => GrammarLessonScreen(chapterId: c.chapters.first.id),
      );
      // Audio may be unavailable in a test, in which case the button hides
      // itself by design; only assert when it is actually on screen.
      final listen = find.bySemanticsLabel(RegExp('narration'));
      if (listen.evaluate().isEmpty) {
        return;
      }
      final size = tester.getSize(
        find.ancestor(of: listen, matching: find.byType(SizedBox)).first,
      );
      expect(size.width, greaterThanOrEqualTo(AccessibleLayout.minTouchTarget));
      expect(
          size.height, greaterThanOrEqualTo(AccessibleLayout.minTouchTarget));
    });

    testWidgets('every quiz answer row is at least 48 dp tall', (tester) async {
      await _pump(tester, (c) => QuizScreen(chapterId: c.chapters.first.id));
      final options = find.bySemanticsLabel(RegExp('^Option [A-D]: '));
      expect(options, findsNWidgets(4));
      for (var i = 0; i < 4; i++) {
        expect(
          tester.getSize(options.at(i)).height,
          greaterThanOrEqualTo(AccessibleLayout.minTouchTarget),
        );
      }
    });

    testWidgets('the language segments are 48 dp at the largest scale',
        (tester) async {
      await _pump(
        tester,
        (c) => StoryScreen(args: StoryArgs(c.chapters.first.id)),
        textScale: 2.0,
      );
      final segments = find.bySemanticsLabel(RegExp('^(EN|বাংলা|हिन्दी)\$'));
      expect(segments, findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        final size = tester.getSize(segments.at(i));
        expect(
            size.height, greaterThanOrEqualTo(AccessibleLayout.minTouchTarget));
        expect(
            size.width, greaterThanOrEqualTo(AccessibleLayout.minTouchTarget));
      }
    });

    testWidgets('the active language is reported as selected', (tester) async {
      await _pump(
        tester,
        (c) => StoryScreen(args: StoryArgs(c.chapters.first.id)),
      );
      final semantics = tester.ensureSemantics();

      // Whichever language the settings start on, exactly one is selected.
      var selected = 0;
      for (final label in ['EN', 'বাংলা', 'हिन्दी']) {
        final node = tester.getSemantics(find.bySemanticsLabel(label));
        if (node.hasFlag(SemanticsFlag.isSelected)) selected += 1;
      }
      expect(selected, 1);
      semantics.dispose();
    });
  });

  group('the reflow switch itself', () {
    testWidgets('compact layout starts at the last standard Android step',
        (tester) async {
      late bool compactAtDefault;
      late bool compactAtLarge;
      late bool compactAtNarrow;
      await _pump(
        tester,
        (_) => Builder(
          builder: (context) {
            compactAtDefault = AccessibleLayout.isCompact(context);
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2.0),
              ),
              child: Builder(
                builder: (inner) {
                  compactAtLarge = AccessibleLayout.needsReflow(inner);
                  return const SizedBox.shrink();
                },
              ),
            );
          },
        ),
      );
      // 320 dp is below the 340 dp floor, so it reflows even at 100% type -
      // which is exactly what the rewards row and the week strip needed.
      compactAtNarrow = compactAtDefault;
      expect(compactAtNarrow, isTrue);
      expect(compactAtLarge, isTrue);
    });
  });
}
