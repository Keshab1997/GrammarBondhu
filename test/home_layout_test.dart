import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/home/home_shell.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The home screen is a dense dashboard, so it has to survive the narrowest
/// phone it will meet. 320 dp is the floor Flutter supports; 353 dp is the
/// Pixel-class device the design was drawn for. Both used to overflow.
Future<void> _pumpHome(WidgetTester tester, Size size) async {
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
      child: MaterialApp(home: const HomeShell(), theme: ThemeData()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in const [Size(320, 640), Size(353, 784), Size(412, 915)]) {
    testWidgets('home lays out cleanly at ${size.width.toInt()} dp wide',
        (tester) async {
      await _pumpHome(tester, size);

      // A RenderFlex overflow is reported as a framework exception.
      expect(tester.takeException(), isNull);

      // The greeting must stay on one line rather than being squeezed out.
      expect(find.text('Hello, Rahul!'), findsOneWidget);

      // Scroll the whole dashboard; every card must lay out at this width.
      await tester.scrollUntilVisible(find.text('Daily Goal'), 240);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
