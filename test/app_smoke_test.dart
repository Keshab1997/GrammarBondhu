import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/app.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:grammar_bondhu/core/widgets/brand_logo.dart';
import 'package:grammar_bondhu/features/chapters/chapter_list_screen.dart';
import 'package:grammar_bondhu/features/home/home_shell.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final content = ContentController(ContentRepository());
  await content.load();
  await tester.pumpWidget(GrammarBondhuApp(
    contentController: content,
    settingsController: SettingsController(store, store.loadSettings()),
    progressController: ProgressController(store, store.loadProgress()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('splash shows branding and starts onboarding on first run',
      (tester) async {
    await _pumpApp(tester);

    // Both words are drawn twice on purpose in the splash wordmark:
    // 'Grammar' is a blue fill over a white outline, 'Bondhu' a gold fill
    // over a dark outline (BrandLogo compact lockup).
    expect(find.text('Grammar'), findsNWidgets(2));
    expect(find.text('Bondhu'), findsNWidgets(2));
    expect(find.text("Let's Begin"), findsOneWidget);

    await tester.tap(find.text("Let's Begin"));
    await tester.pumpAndSettle();

    // The heading is rendered as 'Welcome to\nGrammarBondhu!'.
    expect(find.textContaining('Welcome to'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets(
      'home shell shows greeting and continue journey after content loads',
      (tester) async {
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
        child: MaterialApp(
          home: const HomeShell(),
          theme: ThemeData(useMaterial3: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hello, Rahul!'), findsOneWidget);
    expect(find.text('Start Your Journey'), findsOneWidget);
    // The daily-goal card sits below the fold in the home ListView; it is
    // only built once scrolled into view.
    await tester.scrollUntilVisible(find.text('Daily Goal'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Daily Goal'), findsOneWidget);
    expect(find.text('Chapter 1'), findsWidgets);
  });

  testWidgets('splash fits short and tall phones on one screen',
      (tester) async {
    for (final size in [const Size(360, 640), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pumpApp(tester);

      // Logo lockup and CTA are both fully on screen, with the CTA clear
      // of the top of the screen and inside the bottom edge — no scroll.
      final logo = tester.getRect(find.byType(BrandLogo));
      final cta = tester.getRect(find.text("Let's Begin"));
      expect(logo.top, greaterThanOrEqualTo(0));
      expect(logo.bottom, lessThan(size.height * 0.35));
      expect(cta.bottom, lessThanOrEqualTo(size.height));
      expect(cta.top, greaterThan(logo.bottom));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('chapter list works as a standalone route (Material ancestor)',
      (tester) async {
    // Regression: /chapters is pushed on its own (Home quick action), where
    // the route LookupBoundary hides outer Materials — the filter chips'
    // InkWell threw "No Material widget found" there.
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
        child: MaterialApp(
          home: const ChapterListScreen(),
          theme: ThemeData(useMaterial3: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chapters'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Tap a filter chip: the InkWell needs its own Material ancestor, which
    // is what broke when this screen was pushed as a standalone route.
    await tester.tap(find.text('Locked'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Filtering actually filters now: only locked chapters remain.
    expect(find.textContaining('to unlock'), findsWidgets);
  });

  testWidgets('onboarding flow reaches login screen', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text("Let's Begin"));
    await tester.pumpAndSettle();

    // Three onboarding pages.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3 Languages'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Explore the Story World'), findsOneWidget);

    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);
  });
}
