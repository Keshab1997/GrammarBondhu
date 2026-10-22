import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/core/widgets/listen_button.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/audio/audio_catalog.g.dart';
import 'package:grammar_bondhu/features/audio/audio_controller.dart';
import 'package:grammar_bondhu/features/audio/audio_port.dart';
import 'package:grammar_bondhu/features/grammar/grammar_lesson_screen.dart';
import 'package:grammar_bondhu/features/story/story_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Narration: which clip plays, when it stops, and what happens when the
/// learner has switched sound off.
///
/// No real audio device is touched — a fake port records the asset paths, so a
/// failure here means the app asked for the wrong sound, not that the CI box
/// has no speakers.
class FakeAudioPort implements AudioPort {
  final List<String> played = <String>[];
  int stops = 0;

  /// Set to make playback fail, the way a broken/undecodable clip would.
  bool failOnPlay = false;
  final StreamController<void> _completions =
      StreamController<void>.broadcast();

  @override
  Stream<void> get completions => _completions.stream;

  @override
  Future<void> playAsset(String assetPath) async {
    if (failOnPlay) throw Exception('decoder said no');
    played.add(assetPath);
  }

  @override
  Future<void> stop() async => stops++;

  /// Pretends the clip reached its end.
  void finish() => _completions.add(null);

  @override
  Future<void> dispose() async => _completions.close();
}

/// A screen inside the providers it needs, with audio wired to [port].
Future<AudioController> _pumpScreen(
  WidgetTester tester,
  Widget screen,
  Size size, {
  required FakeAudioPort port,
  bool audioEnabled = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final settings = SettingsController(store, store.loadSettings());
  await settings.setAudioEnabled(audioEnabled);
  final content = ContentController(ContentRepository());
  await content.load();
  final audio = AudioController(port: port, settings: settings);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: content),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(
          create: (_) => ProgressController(store, store.loadProgress()),
        ),
      ],
      child: AudioScope(
        controller: audio,
        // The story stage idles forever; reduced motion is how a test gets a
        // tree that settles.
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: screen,
            theme: ThemeData(useMaterial3: true),
            onUnknownRoute: (settings) => MaterialPageRoute<void>(
                builder: (_) => const SizedBox.shrink()),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return audio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioController', () {
    late FakeAudioPort port;
    late SettingsController settings;
    late AudioController audio;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      settings = SettingsController(store, store.loadSettings());
      port = FakeAudioPort();
      audio = AudioController(port: port, settings: settings);
    });

    tearDown(() async {
      audio.dispose();
    });

    test('plays the clip it was asked for, and stops on a second tap',
        () async {
      await audio.toggle('teach_1_bn');
      expect(port.played, ['assets/audio/clips/teach_1_bn.mp3']);
      expect(audio.playingId, 'teach_1_bn');

      await audio.toggle('teach_1_bn');
      expect(audio.playingId, isNull);
      expect(port.stops, 1);
    });

    test('one clip at a time: a new tap replaces the old one', () async {
      await audio.toggle('teach_1_bn');
      await audio.toggle('board_ch01_explain_bn');
      expect(audio.playingId, 'board_ch01_explain_bn');
      expect(port.played.last, 'assets/audio/clips/board_ch01_explain_bn.mp3');
    });

    test('a finished clip clears the playing state', () async {
      await audio.toggle('teach_2_en');
      port.finish();
      await Future<void>.delayed(Duration.zero);
      expect(audio.playingId, isNull);
    });

    test('nothing plays while narration is switched off', () async {
      await settings.setAudioEnabled(false);
      await audio.toggle('teach_1_bn');
      expect(port.played, isEmpty);
      expect(audio.canPlay('teach_1_bn'), isFalse);
    });

    test('switching narration off mid-sentence stops the clip', () async {
      await audio.toggle('teach_3_bn');
      await settings.setAudioEnabled(false);
      await Future<void>.delayed(Duration.zero);
      expect(audio.playingId, isNull);
      expect(port.stops, 1);
    });

    test('a clip that will not play reports failure and clears the button',
        () async {
      port.failOnPlay = true;
      final started = await audio.toggle('teach_1_bn');
      expect(started, isFalse);
      expect(audio.playingId, isNull);
      expect(audio.lastError, isNotNull);
    });

    test('a clip that is not in the bundle is never requested', () async {
      await audio.toggle('no_such_clip');
      expect(port.played, isEmpty);
      expect(audio.playingId, isNull);
    });
  });

  group('ListenButton', () {
    testWidgets('hidden when the screen has no audio scope', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenButton(clipId: 'teach_1_bn'),
          ),
        ),
      );
      expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    });

    testWidgets('tapping plays that clip and shows it is sounding',
        (tester) async {
      final port = FakeAudioPort();
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final settings = SettingsController(store, store.loadSettings());
      final audio = AudioController(port: port, settings: settings);
      addTearDown(audio.dispose);

      await tester.pumpWidget(
        AudioScope(
          controller: audio,
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: ListenButton(clipId: 'teach_1_bn')),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pumpAndSettle();

      expect(port.played, ['assets/audio/clips/teach_1_bn.mp3']);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    });
  });

  group('narration failure', () {
    testWidgets('a dead clip says so instead of staying silent',
        (tester) async {
      final port = FakeAudioPort()..failOnPlay = true;
      SharedPreferences.setMockInitialValues({});
      final store = await LocalStore.open();
      final settings = SettingsController(store, store.loadSettings());
      final audio = AudioController(port: port, settings: settings);
      addTearDown(audio.dispose);

      await tester.pumpWidget(
        AudioScope(
          controller: audio,
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: ListenButton(clipId: 'teach_1_bn')),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.volume_up_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Could not play this audio'), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq_rounded), findsNothing);
    });
  });

  group('narration in the app', () {
    testWidgets('the story bubble speaks its line, and stops when you advance',
        (tester) async {
      final port = FakeAudioPort();
      final audio = await _pumpScreen(
        tester,
        const StoryScreen(args: StoryArgs('ch01')),
        const Size(353, 784),
        port: port,
      );
      addTearDown(audio.dispose);

      await tester.tap(find.byIcon(Icons.volume_up_rounded).first);
      await tester.pumpAndSettle();
      expect(port.played, ['assets/audio/clips/story_ch01_0_0_en.mp3']);

      await tester.tapAt(const Offset(176, 120));
      await tester.pumpAndSettle();
      expect(audio.playingId, isNull);
      expect(port.stops, greaterThan(0));
    });

    testWidgets('the board reads itself in the language it is written in',
        (tester) async {
      final port = FakeAudioPort();
      final audio = await _pumpScreen(
        tester,
        const GrammarLessonScreen(chapterId: 'ch01'),
        const Size(353, 784),
        port: port,
      );
      addTearDown(audio.dispose);

      // English board first — the toggle has not been used.
      await tester.tap(find.text('Hear it'));
      await tester.pumpAndSettle();
      expect(port.played.last, 'assets/audio/clips/board_ch01_explain_en.mp3');

      // Flip the board to Bangla: the same button now asks for the Bangla read.
      await tester.tap(find.byIcon(Icons.translate_rounded));
      await tester.pumpAndSettle();
      expect(find.text('শুনে নাও'), findsOneWidget);
      await tester.tap(find.text('শুনে নাও'));
      await tester.pumpAndSettle();
      expect(port.played.last, 'assets/audio/clips/board_ch01_explain_bn.mp3');
    });

    testWidgets('turning the page silences the page you left', (tester) async {
      final port = FakeAudioPort();
      final audio = await _pumpScreen(
        tester,
        const GrammarLessonScreen(chapterId: 'ch01'),
        const Size(353, 784),
        port: port,
      );
      addTearDown(audio.dispose);

      await tester.tap(find.text('Hear it'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(audio.playingId, isNull);
      expect(port.stops, greaterThan(0));
    });

    testWidgets('every clip the UI can ask for is in the bundle',
        (tester) async {
      final content = ContentController(ContentRepository());
      await content.load();
      final missing = <String>[];

      for (final chapter in content.chapters) {
        for (var s = 0; s < chapter.scenes.length; s++) {
          final line = chapter.scenes[s].dialogue;
          for (var l = 0; l < line.length; l++) {
            for (final lang in ['en', 'bn']) {
              final id = 'story_${chapter.id}_${s}_${l}_$lang';
              if (!AudioCatalog.has(id)) missing.add(id);
            }
          }
        }
        for (final lang in ['en', 'bn']) {
          final id = 'board_${chapter.id}_explain_$lang';
          if (!AudioCatalog.has(id)) missing.add(id);
        }
        final examples = 'board_${chapter.id}_examples_en';
        if (!AudioCatalog.has(examples)) missing.add(examples);
      }
      for (final page in [1, 2, 3]) {
        for (final lang in ['en', 'bn']) {
          final id = 'teach_${page}_$lang';
          if (!AudioCatalog.has(id)) missing.add(id);
        }
      }

      expect(missing, isEmpty, reason: 'run python3 tool/tts/make_clips.py');
    });

    for (final size in const [Size(320, 640), Size(412, 915)]) {
      testWidgets(
          'speakers fit the lesson and story at ${size.width.toInt()} dp',
          (tester) async {
        final port = FakeAudioPort();
        final audio = await _pumpScreen(
          tester,
          const GrammarLessonScreen(chapterId: 'ch01'),
          size,
          port: port,
        );
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.volume_up_rounded), findsWidgets);
        audio.dispose();

        final storyAudio = await _pumpScreen(
          tester,
          const StoryScreen(args: StoryArgs('ch01')),
          size,
          port: port,
        );
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.volume_up_rounded), findsWidgets);
        storyAudio.dispose();
      });
    }
  });
}
