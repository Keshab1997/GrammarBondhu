import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/app/state/content_controller.dart';
import 'package:grammar_bondhu/app/state/progress_controller.dart';
import 'package:grammar_bondhu/app/state/settings_controller.dart';
import 'package:grammar_bondhu/app/theme/app_theme.dart';
import 'package:grammar_bondhu/core/utils/accessible_layout.dart';
import 'package:grammar_bondhu/core/utils/speech_cadence.dart';
import 'package:grammar_bondhu/core/widgets/talking_character.dart';
import 'package:grammar_bondhu/data/local/local_store.dart';
import 'package:grammar_bondhu/data/repositories/content_repository.dart';
import 'package:grammar_bondhu/features/audio/audio_controller.dart';
import 'package:grammar_bondhu/features/audio/audio_port.dart';
import 'package:grammar_bondhu/features/grammar/grammar_lesson_screen.dart';
import 'package:grammar_bondhu/features/story/story_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ControlledAudioPort implements AudioPort {
  final _done = StreamController<void>.broadcast(sync: true);
  final List<String> played = <String>[];
  int stops = 0;

  @override
  Stream<void> get completions => _done.stream;

  @override
  Future<void> playAsset(String assetPath) async {
    played.add(assetPath);
  }

  @override
  Future<void> stop() async {
    stops += 1;
  }

  void finishCurrentClip() => _done.add(null);

  @override
  Future<void> dispose() => _done.close();
}

Set<String> _visibleCharacterAssets(WidgetTester tester) {
  final out = <String>{};
  for (final img in tester.widgetList<Image>(
    find.descendant(
      of: find.byType(TalkingCharacter),
      matching: find.byType(Image),
    ),
  )) {
    final provider = img.image;
    if (provider is AssetImage) out.add(provider.assetName);
  }
  return out;
}

Future<
    ({
      ContentController content,
      SettingsController settings,
      LocalStore store,
      AudioController audio,
      _ControlledAudioPort port,
      List<String> pushedRoutes,
    })> _pumpLiveStory(
  WidgetTester tester, {
  String chapterId = 'ch01',
  int startScene = 0,
  bool audioEnabled = true,
  bool autoPlay = true,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final initial = store.loadSettings()
    ..audioEnabled = audioEnabled
    ..autoPlayStory = autoPlay;
  await store.saveSettings(initial);

  final settings = SettingsController(store, initial);
  final progress = ProgressController(store, store.loadProgress());
  final content = ContentController(ContentRepository());
  await content.load();
  final port = _ControlledAudioPort();
  final audio = AudioController(port: port, settings: settings);
  addTearDown(audio.dispose);
  final pushedRoutes = <String>[];

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: content),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: progress),
      ],
      child: AudioScope(
        controller: audio,
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: false,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: StoryScreen(args: StoryArgs(chapterId, startScene: startScene)),
          onGenerateRoute: (route) {
            pushedRoutes.add(route.name ?? '');
            return MaterialPageRoute<void>(
              settings: route,
              builder: (_) => const Scaffold(body: Text('Lesson reached')),
            );
          },
        ),
      ),
    ),
  );
  // Let post-frame auto-cue kick off without waiting on infinite idle motion.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
  return (
    content: content,
    settings: settings,
    store: store,
    audio: audio,
    port: port,
    pushedRoutes: pushedRoutes,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeechCadence', () {
    test('cycles through half and open vowels for English, Bangla and Hindi',
        () {
      for (final sample in [
        'Hello, I am Rahul! Welcome to our classroom.',
        'নমস্কার, আমি রাহুল। আমাদের ক্লাসে স্বাগতম!',
        'नमस्ते, मैं राहुल हूँ। हमारी कक्षा में स्वागत है!',
      ]) {
        final cadence = SpeechCadence.fromText(sample);
        final seen = <MouthFrame>{};
        for (var ms = 0; ms <= cadence.totalMs + 100; ms += 25) {
          seen.add(cadence.frameAt(Duration(milliseconds: ms)));
        }
        expect(seen, containsAll(MouthFrame.values), reason: sample);
        // Settles into a closed smile once the line is done.
        expect(
          cadence.frameAt(Duration(milliseconds: cadence.totalMs + 50)),
          MouthFrame.closed,
        );
        // Loops cleanly while live audio is still speaking.
        expect(
          cadence.frameAt(
            Duration(milliseconds: cadence.totalMs + 70),
            loop: true,
          ),
          isNot(MouthFrame.closed),
        );
      }
    });
  });

  group('animated talking characters & auto-story', () {
    testWidgets(
        'speaker auto-voices the line, animates lip-sync, blinks and auto-advances',
        (tester) async {
      // Scene 1 of ch01 has two dialogue lines (teacher, then rahul).
      final h = await _pumpLiveStory(tester, chapterId: 'ch01', startScene: 1);
      final scene = h.content.byId('ch01')!.scenes[1];
      final speaker = scene.dialogue[0].characterId;
      final listener = scene.characterIds.firstWhere((id) => id != speaker);

      // Voice starts automatically on scene open.
      expect(h.port.played, ['assets/audio/clips/story_ch01_1_0_en.mp3']);
      expect(find.text('Speaking · Tap to skip'), findsOneWidget);

      // Sample across 500 ms: speaker visits half and open talk frames while
      // the listener's mouth never opens.
      final speakerFrames = <String>{};
      final listenerFrames = <String>{};
      for (var step = 0; step < 20; step++) {
        await tester.pump(const Duration(milliseconds: 30));
        for (final asset in _visibleCharacterAssets(tester)) {
          if (asset.contains(speaker)) speakerFrames.add(asset);
          if (asset.contains(listener)) listenerFrames.add(asset);
        }
      }
      expect(
        speakerFrames,
        containsAll([
          'assets/characters/${speaker}_talk_half.webp',
          'assets/characters/${speaker}_talk_open.webp',
        ]),
      );
      expect(
        listenerFrames.where((a) => a.contains('_talk_')),
        isEmpty,
      );

      // When the voice clip finishes, the speaker closes their mouth, waits a
      // natural breath, and the next character automatically takes over.
      h.port.finishCurrentClip();
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        _visibleCharacterAssets(tester).where((a) => a.contains('_talk_')),
        isEmpty,
      );

      // Advance past the 850 ms conversational pause.
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.text(scene.dialogue[1].text.en), findsOneWidget);
      expect(h.port.played.last, 'assets/audio/clips/story_ch01_1_1_en.mp3');
    });

    testWidgets('characters blink naturally while waiting on stage',
        (tester) async {
      await _pumpLiveStory(
        tester,
        chapterId: 'ch01',
        startScene: 1,
        autoPlay: false,
      );

      final seenBlinks = <String>{};
      for (var step = 0; step < 60; step++) {
        await tester.pump(const Duration(milliseconds: 80));
        for (final asset in _visibleCharacterAssets(tester)) {
          if (asset.endsWith('_blink.webp')) seenBlinks.add(asset);
        }
      }
      expect(seenBlinks, isNotEmpty);
    });

    testWidgets('auto-play pauses at interactive choices until learner chooses',
        (tester) async {
      // ch11 scene 2 has two dialogue lines followed by an interactive choice.
      final h = await _pumpLiveStory(tester, chapterId: 'ch11', startScene: 2);
      final scene = h.content.byId('ch11')!.scenes[2];

      // Choice stays hidden until the second (prompt) line arrives.
      expect(find.text(scene.choices.first.text.en), findsNothing);
      expect(h.port.played, ['assets/audio/clips/story_ch11_2_0_en.mp3']);

      // Line 0 finishes -> auto-steps to line 1 and shows the choice.
      h.port.finishCurrentClip();
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text(scene.dialogue[1].text.en), findsOneWidget);
      expect(find.text(scene.choices.first.text.en), findsOneWidget);

      // Line 1 finishes -> auto-play waits on the choice instead of skipping.
      h.port.finishCurrentClip();
      await tester.pump(const Duration(seconds: 4));
      expect(h.pushedRoutes, isEmpty);
      expect(find.text(scene.choices.first.text.en), findsOneWidget);

      // Picking the choice shows its feedback, then flows to the lesson.
      await tester.tap(find.text(scene.choices.first.text.en));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(scene.choices.first.response.en), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump();
      expect(h.pushedRoutes, contains(GrammarLessonScreen.routeName));
    });

    testWidgets(
        'silent mode still animates mouth shapes and steps automatically',
        (tester) async {
      final h = await _pumpLiveStory(
        tester,
        chapterId: 'ch01',
        startScene: 1,
        audioEnabled: false,
      );
      final scene = h.content.byId('ch01')!.scenes[1];

      expect(h.port.played, isEmpty);
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        _visibleCharacterAssets(tester).any((a) => a.contains('_talk_')),
        isTrue,
      );

      // After silent speech + pause, the second line arrives automatically.
      await tester.pump(const Duration(seconds: 7));
      expect(find.text(scene.dialogue[1].text.en), findsOneWidget);
    });

    testWidgets(
        'Auto toggle stops/resumes auto-play, persists, and meets 48 dp at 320 dp / 200%',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final h = await _pumpLiveStory(
          tester,
          chapterId: 'ch01',
          size: const Size(320, 640),
          textScale: 2.0,
        );
        expect(tester.takeException(), isNull);

        final toggle = find.bySemanticsLabel('Auto-play story');
        final size = tester.getSize(toggle);
        expect(
            size.width, greaterThanOrEqualTo(AccessibleLayout.minTouchTarget));
        expect(
          size.height,
          greaterThanOrEqualTo(AccessibleLayout.minTouchTarget),
        );
        expect(
          tester.getSemantics(toggle).flagsCollection.isSelected,
          Tristate.isTrue,
        );

        // Pausing stops live playback and persists to disk.
        await tester.tap(toggle);
        await tester.pump(const Duration(milliseconds: 50));
        expect(h.audio.playingId, isNull);
        expect(h.store.loadSettings().autoPlayStory, isFalse);
        expect(
          tester.getSemantics(toggle).flagsCollection.isSelected,
          Tristate.isFalse,
        );

        // Turning Auto back on restarts the current line immediately.
        final playedBefore = h.port.played.length;
        await tester.tap(toggle);
        await tester.pump(const Duration(milliseconds: 50));
        expect(h.store.loadSettings().autoPlayStory, isTrue);
        expect(h.port.played.length, playedBefore + 1);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets(
        'listening characters stay 100% opaque and keep stable stage positions',
        (tester) async {
      final h = await _pumpLiveStory(tester, chapterId: 'ch01', startScene: 1);

      final chars = find.byType(TalkingCharacter);
      expect(chars, findsNWidgets(2));

      // Neither speaker nor listener may be wrapped in a partial-opacity fade
      // that lets background furniture bleed through their face or clothes.
      for (final element in chars.evaluate()) {
        final opacities = find.descendant(
          of: find.byWidget(element.widget),
          matching: find.byType(Opacity),
        );
        for (final op in opacities.evaluate()) {
          expect((op.widget as Opacity).opacity, 1.0);
        }
        final animated = find.descendant(
          of: find.byWidget(element.widget),
          matching: find.byType(AnimatedOpacity),
        );
        for (final ao in animated.evaluate()) {
          expect((ao.widget as AnimatedOpacity).opacity, 1.0);
        }
      }

      final rahulKey = find.byKey(const ValueKey<String>('stage_char_rahul'));
      final teacherKey =
          find.byKey(const ValueKey<String>('stage_char_teacher'));
      final rahulLeftBefore = tester.getTopLeft(rahulKey).dx;
      final teacherLeftBefore = tester.getTopLeft(teacherKey).dx;

      // Advance from Mrs. Sen's line to Rahul's reply: both stay in their own
      // horizontal half instead of teleport-swapping across the room.
      h.port.finishCurrentClip();
      await tester.pump(const Duration(milliseconds: 950));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.getTopLeft(rahulKey).dx, rahulLeftBefore);
      expect(tester.getTopLeft(teacherKey).dx, teacherLeftBefore);
    });
  });
}
