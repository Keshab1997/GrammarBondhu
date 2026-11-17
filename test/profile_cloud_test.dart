import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/auth/login_screen.dart';
import 'package:grammar_bondhu/features/profile/profile_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsController> _pumpProfile(WidgetTester tester,
    {bool connected = false}) async {
  tester.view.physicalSize = const Size(353, 784);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final content = ContentController(ContentRepository());
  await content.load();
  final settings = SettingsController(store, store.loadSettings());
  if (connected) {
    await settings.signInWithGoogle(
      displayName: 'Mina',
      userId: 'firebase-user-1',
    );
  }
  final progress = ProgressController(store, store.loadProgress());

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: content),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: progress),
      ],
      child: MaterialApp(
        home: const Scaffold(body: ProfileScreen()),
        onGenerateRoute: (route) => route.name == LoginScreen.routeName
            ? MaterialPageRoute<void>(builder: (_) => const LoginScreen())
            : null,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return settings;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guest can find optional Google connection from Profile',
      (tester) async {
    await _pumpProfile(tester);

    expect(find.text('Learning as a guest'), findsOneWidget);
    await tester.ensureVisible(find.text('Connect Google'));
    await tester.tap(find.text('Connect Google'));
    await tester.pumpAndSettle();

    expect(find.text('Make it yours'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('connected account can disconnect without deleting local data',
      (tester) async {
    final settings = await _pumpProfile(tester, connected: true);

    expect(find.text('Google account connected'), findsOneWidget);
    await tester.ensureVisible(find.text('Disconnect Google account'));
    await tester.tap(find.text('Disconnect Google account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();

    expect(settings.settings.isGuest, isTrue);
    expect(settings.cloudConnected, isFalse);
    expect(find.text('Learning as a guest'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
