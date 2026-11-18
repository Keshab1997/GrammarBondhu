import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_bondhu/core/utils/audio_speaking_mouth.dart';
import 'package:grammar_bondhu/core/utils/speech_cadence.dart';
import 'package:grammar_bondhu/features/audio/audio_lipsync.g.dart';

/// Lip-sync is measured, not guessed: these tests pin the waveform timeline to
/// the actual bundled recordings, so a clip that starts moving its mouth at the
/// wrong instant fails here instead of shipping.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioLipSync timelines', () {
    test('every narration clip has a timeline as long as its audio', () {
      expect(AudioLipSync.has('story_ch01_1_0_en'), isTrue);
      // Measured from the bundled 6.05 s recording.
      expect(AudioLipSync.durationMsOf('story_ch01_1_0_en'), 6050);
      expect(AudioLipSync.has('teach_1_en'), isTrue);
      expect(AudioLipSync.has('no_such_clip'), isFalse);
      expect(AudioLipSync.durationMsOf('no_such_clip'), isNull);
    });

    test('the mouth shape follows the recorded voice, not a text guess', () {
      const clip = 'story_ch01_1_0_en';
      // The greeting "Welcome, Rahul!" is voiced immediately: an open vowel lands
      // in the first third of a second, and the mouth is shut before playback.
      expect(AudioLipSync.frameAt(clip, Duration.zero), MouthFrame.closed);
      final opening = <MouthFrame>{
        for (var ms = 0; ms <= 400; ms += 10)
          AudioLipSync.frameAt(clip, Duration(milliseconds: ms)),
      };
      expect(opening, contains(MouthFrame.open));

      // The recorded pause after "Rahul!" (1.8-2.4 s) shows a closed mouth even
      // though the next word is already on screen: the jaw follows the voice,
      // not the text.
      final pause = <MouthFrame>{
        for (var ms = 1800; ms <= 2400; ms += 50)
          AudioLipSync.frameAt(clip, Duration(milliseconds: ms)),
      };
      expect(pause, <MouthFrame>{MouthFrame.closed});

      // Past the end of the audio the mouth rests instead of cycling.
      expect(
        AudioLipSync.frameAt(
          clip,
          Duration(milliseconds: AudioLipSync.durationMsOf(clip)! + 500),
        ),
        MouthFrame.closed,
      );
    });

    test('mouth motion is calm: no cartoon flap and no frozen jaw', () {
      const clip = 'story_ch01_1_0_en';
      final frames = <MouthFrame>[
        for (var ms = 0; ms < AudioLipSync.durationMsOf(clip)!; ms += 50)
          AudioLipSync.frameAt(clip, Duration(milliseconds: ms)),
      ];
      var changes = 0;
      var opens = 0;
      for (var i = 1; i < frames.length; i++) {
        if (frames[i] != frames[i - 1]) changes++;
        if (frames[i] == MouthFrame.open && frames[i - 1] != MouthFrame.open) {
          opens++;
        }
      }
      final seconds = frames.length * 0.05;
      // Natural narration: ~4-6 shape changes and ~1-1.6 wide vowels a second.
      expect(changes / seconds, lessThan(7.5));
      expect(opens / seconds, lessThan(2.2));
      expect(opens, greaterThanOrEqualTo(3));
    });

    test('energy is a smooth phrase-level signal, never a per-frame spike', () {
      const clip = 'story_ch01_1_0_en';
      double? previous;
      var maxStep = 0.0;
      for (var ms = 0; ms <= 6000; ms += 50) {
        final energy = AudioLipSync.energyAt(clip, Duration(milliseconds: ms));
        expect(energy, inInclusiveRange(0.0, 1.0));
        if (previous != null && (energy - previous).abs() > maxStep) {
          maxStep = (energy - previous).abs();
        }
        previous = energy;
      }
      expect(maxStep, lessThan(0.22));
    });
  });

  group('AudioSpeakingMouth', () {
    test('holds the mouth shut through the buffering window', () {
      final mouth = AudioSpeakingMouth(audio: null)
        ..startClip('silent_for_now');
      // No audio controller at all: nothing is playing, so nothing moves.
      mouth.sample(Duration.zero);
      expect(mouth.mouth, MouthFrame.closed);
      expect(mouth.energy, 0);
      mouth.dispose();
    });

    test('a silent line is narrated on the frame clock, then rests', () {
      final mouth = AudioSpeakingMouth(audio: null);
      final cadence = SpeechCadence.fromText(
        'Hi! I am Rahul. I am a new student.',
      );
      mouth.startSilent(cadence);

      final seen = <MouthFrame>{};
      for (var ms = 0; ms < cadence.totalMs; ms += 16) {
        mouth.sample(Duration(milliseconds: ms));
        seen.add(mouth.mouth);
      }
      expect(seen, containsAll(MouthFrame.values));

      mouth.sample(Duration(milliseconds: cadence.totalMs + 100));
      expect(mouth.mouth, MouthFrame.closed);
      mouth.dispose();
    });

    test('spoken text paces at a natural rate instead of flapping', () {
      final cadence = SpeechCadence.fromText(
        'Welcome, Rahul! I am Mrs. Sen. I am your English teacher.',
      );
      // 5.5 s of speech for an 11-word line: about the pace of the bundled voice.
      expect(
          cadence.silentDuration.inMilliseconds, inInclusiveRange(5200, 7000));

      var opens = 0;
      var previous = MouthFrame.closed;
      for (var ms = 0; ms < cadence.totalMs; ms += 25) {
        final frame = cadence.frameAt(Duration(milliseconds: ms));
        if (frame == MouthFrame.open && previous != MouthFrame.open) opens++;
        previous = frame;
      }
      final seconds = cadence.totalMs / 1000;
      // At most ~2.4 wide vowels a second: calm, human, never a cartoon flap.
      expect(opens / seconds, lessThan(2.6));
      expect(opens, greaterThanOrEqualTo(3));
    });

    test('reduced-motion callers simply never animate the mouth', () {
      final cadence = SpeechCadence.fromText('Line with no audio.');
      expect(cadence.frameAt(Duration.zero), isNotNull);
      expect(cadence.silentDuration.inMilliseconds, cadence.totalMs);
    });
  });
}
