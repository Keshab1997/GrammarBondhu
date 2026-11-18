import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/auth/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    testWidgets('profile setup lays out at ${size.width.toInt()} dp wide',
        (tester) async {
      await _pump(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.text('Make it yours'), findsOneWidget);
      expect(find.text('Your name (optional)'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Continue without a name'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Password'), findsNothing);
      expect(find.text('Login'), findsNothing);
      expect(find.text('Sign Up'), findsNothing);
    });
  }

  testWidgets('learner can continue without a name as a guest', (tester) async {
    await _pump(tester, const Size(320, 640));
    await tester.ensureVisible(find.text('Continue without a name'));
    await tester.tap(find.text('Continue without a name'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Continue without a name'), findsNothing);
  });

  testWidgets('optional name is saved as a local profile', (tester) async {
    await _pump(tester, const Size(353, 784));
    await tester.enterText(find.byType(TextField), 'Mina');
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Make it yours'), findsNothing);
  });
}
