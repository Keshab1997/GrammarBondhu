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

    expect(find.text('Grammar'), findsOneWidget);
    expect(find.text('Bondhu'), findsOneWidget);
    expect(find.text("Let's Begin"), findsOneWidget);

    await tester.tap(find.text("Let's Begin"));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to GrammarBondhu!'), findsOneWidget);
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
    expect(find.text('Daily Goal'), findsOneWidget);
    expect(find.text('Chapter 1'), findsWidgets);
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
