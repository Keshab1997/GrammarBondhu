import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/router.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/home/home_shell.dart';
import 'package:grammar_bondhu/features/onboarding/onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DelayedSettings extends SettingsController {
  _DelayedSettings(LocalStore store) : super(store, store.loadSettings());

  final release = Completer<void>();
  int finishCalls = 0;

  @override
  Future<void> completeOnboarding() async {
    finishCalls++;
    await release.future;
    await super.completeOnboarding();
  }
}

Future<
    ({
      LocalStore store,
      _DelayedSettings settings,
      List<String?> destinations
    })> _pumpOnboarding(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final settings = _DelayedSettings(store);
  final content = ContentController(ContentRepository());
  await content.load();
  final destinations = <String?>[];

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        ChangeNotifierProvider.value(value: content),
        ChangeNotifierProvider(
            create: (_) => ProgressController(store, store.loadProgress())),
      ],
      child: MaterialApp(
        home: const OnboardingScreen(),
        onGenerateRoute: (route) {
          destinations.add(route.name);
          return AppRouter.onGenerateRoute(route);
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (store: store, settings: settings, destinations: destinations);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('page two saves Hindi and Get Started opens HomeShell as a guest',
      (tester) async {
    final h = await _pumpOnboarding(tester);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    final hindi = find.text('हिन्दी');
    await tester.ensureVisible(hindi);
    await tester.tap(hindi);
    await tester.pumpAndSettle();
    expect(h.settings.supportLanguage, 'hi');
    expect(h.store.loadSettings().supportLanguage, 'hi');

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Started'));
    await tester.tap(find.text('Get Started'));
    expect(h.settings.finishCalls, 1);
    expect(h.destinations, isEmpty);
    h.settings.release.complete();
    await tester.pumpAndSettle();

    final saved = h.store.loadSettings();
    expect(saved.supportLanguage, 'hi');
    expect(saved.onboardingComplete, isTrue);
    expect(saved.isGuest, isTrue);
    expect(h.destinations, [HomeShell.routeName]);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.textContaining('Password'), findsNothing);
  });

  testWidgets('double Skip saves and replaces the route only once',
      (tester) async {
    final h = await _pumpOnboarding(tester);
    // Both taps land before the disabled button has rebuilt.
    await tester.tap(find.text('Skip'));
    await tester.tap(find.text('Skip'));
    expect(h.settings.finishCalls, 1);
    expect(h.destinations, isEmpty);
    h.settings.release.complete();
    await tester.pumpAndSettle();

    expect(h.destinations, [HomeShell.routeName]);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(h.store.loadSettings().onboardingComplete, isTrue);
    expect(h.store.loadSettings().isGuest, isTrue);
    expect(tester.takeException(), isNull);
  });
}
