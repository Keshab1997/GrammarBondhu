import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The login screen is the last gate before the app, so it has to work on the
/// narrowest phone the app supports and stay guest-first.
Future<void> _pump(WidgetTester tester, Size size) async {
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
      child: MaterialApp(
        home: const LoginScreen(),
        theme: ThemeData(useMaterial3: true),
        // No route table in the test: the guest path can navigate on, we only
        // care that it *does* navigate and does not throw on the way.
        onUnknownRoute: (settings) =>
            MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in const [Size(320, 640), Size(353, 784), Size(412, 915)]) {
    testWidgets('login lays out cleanly at ${size.width.toInt()} dp wide',
        (tester) async {
      await _pump(tester, size);
      expect(tester.takeException(), isNull);

      // The form must be reachable without horizontal overflow.
      expect(find.text('Welcome Back!'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Sign Up'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsOneWidget);
    });
  }

  testWidgets('guest path is reachable on the smallest phone', (tester) async {
    await _pump(tester, const Size(320, 640));
    // Scroll the form into view, then take the guest route — the whole point
    // of the screen is that this never requires an account.
    await tester.scrollUntilVisible(
      find.text('Continue as Guest'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue as Guest'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Guest mode persisted: the app remembers we chose it.
    expect(find.text('Continue as Guest'), findsNothing);
  });

  testWidgets('empty submit shows validation instead of leaving the screen',
      (tester) async {
    await _pump(tester, const Size(353, 784));
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your email or phone'), findsOneWidget);
    expect(find.text('Password needs 4+ characters'), findsOneWidget);
  });

  testWidgets('password visibility toggle flips', (tester) async {
    await _pump(tester, const Size(353, 784));
    bool passwordObscured() => tester
        .widgetList<EditableText>(find.byType(EditableText))
        .last
        .obscureText;

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(passwordObscured(), isTrue);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    // The field really is revealed, not just the icon swapped.
    expect(passwordObscured(), isFalse);
  });
}
