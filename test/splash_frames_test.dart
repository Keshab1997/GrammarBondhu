import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/splash/hero_frames.dart';
import 'package:grammar_bondhu/features/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The splash is "fixed chrome, moving scene": these tests pin both halves of
/// that promise — the illustration advances through every frame, and nothing
/// else on the screen moves while it does.
Future<void> _pump(WidgetTester tester,
    {Size size = const Size(360, 780)}) async {
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
        home: const SplashScreen(),
        theme: ThemeData(useMaterial3: true),
      ),
    ),
  );
  await tester.pump();
}

/// The frame index currently on screen, read from the widget's ValueKey.
int _currentFrame(WidgetTester tester) {
  final images = tester.widgetList<Image>(find.byType(Image));
  for (final image in images) {
    final provider = image.image;
    if (provider is AssetImage &&
        provider.assetName.contains('assets/frames/')) {
      final key = (tester.widget(find.byWidget(image)) as Image).key;
      if (key is ValueKey<int>) return key.value;
    }
  }
  return -1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the scene advances through all ten frames, then holds',
      (tester) async {
    await _pump(tester);
    expect(_currentFrame(tester), 0);

    // Step the clock in small slices and record every frame we land on. Small
    // slices matter: a single big jump can contain two timer fires, and the
    // test would then report a skip that never happened on screen.
    final seen = <int>[0];
    for (var t = 0; t < 45000; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
      final frame = _currentFrame(tester);
      if (frame != seen.last) seen.add(frame);
    }

    expect(seen, List<int>.generate(10, (i) => i),
        reason: 'every frame should play once, in order');

    // One pass only: it must hold the last frame rather than loop back.
    for (var t = 0; t < 20000; t += 500) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(_currentFrame(tester), 9);
  });

  testWidgets('chrome does not move while the scene plays', (tester) async {
    await _pump(tester);

    final logo = tester.getRect(find.text('Grammar').first);
    final tagline = tester.getRect(find.text('LEARN ENGLISH THROUGH STORIES'));
    final cta = tester.getRect(find.text("Let's Begin"));
    final frame = tester.getRect(find.byType(HeroFrames));

    // Advance three frames and re-measure.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 2600));
      await tester.pumpAndSettle();
    }

    expect(tester.getRect(find.text('Grammar').first), logo);
    expect(tester.getRect(find.text('LEARN ENGLISH THROUGH STORIES')), tagline);
    expect(tester.getRect(find.text("Let's Begin")), cta);
    expect(tester.getRect(find.byType(HeroFrames)), frame);
  });

  testWidgets('every frame asset is declared and decodable', (tester) async {
    await _pump(tester);
    for (var i = 0; i < 10; i++) {
      final path = HeroFrames.assetFor(i);
      expect(path, endsWith('frame_${i.toString().padLeft(2, '0')}.webp'));
      // A missing asset throws here, which is the point of the test.
      await tester.runAsync(() async {
        final data = await rootBundleLoad(path);
        expect(data.lengthInBytes, greaterThan(1000),
            reason: '$path looks empty');
      });
    }
  });
}

/// Loads an asset through the test bundle; a missing one throws.
Future<ByteData> rootBundleLoad(String path) => rootBundle.load(path);
