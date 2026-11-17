import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/features/home/home_shell.dart';
import 'package:grammar_bondhu/features/onboarding/onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsController> _pumpOnboarding(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final settings = SettingsController(store, store.loadSettings());

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
        home: const OnboardingScreen(),
        onGenerateRoute: (route) {
          if (route.name == HomeShell.routeName) {
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Home dashboard')),
            );
          }
          return null;
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('finishing onboarding opens the app without a login gate',
      (tester) async {
    final settings = await _pumpOnboarding(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Home dashboard'), findsOneWidget);
    expect(settings.settings.onboardingComplete, isTrue);
    expect(find.textContaining('Password'), findsNothing);
  });

  testWidgets('skipping onboarding opens the app as a guest', (tester) async {
    final settings = await _pumpOnboarding(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Home dashboard'), findsOneWidget);
    expect(settings.settings.onboardingComplete, isTrue);
    expect(settings.settings.isGuest, isTrue);
  });
}
