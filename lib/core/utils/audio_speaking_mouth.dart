import '../../features/audio/audio_controller.dart';
import '../../features/audio/audio_lipsync.g.dart';
import 'speech_cadence.dart';

/// Drives a character's mouth from whatever is *actually* sounding.
///
/// Two sources, one clock:
///
///  * A bundled clip that really shipped → the mouth is read from the measured
///    waveform timeline (`AudioLipSync`) at the hardware playhead, so syllables,
///    breaths and sentence pauses land exactly on the voice.
///  * No clip (narration switched off, a line with no recording, or Hindi text)
///    → a deliberately calm [SpeechCadence] read, so the character still talks
///    at a human pace instead of flapping.
///
/// While a clip is still loading or buffering the mouth stays closed: a mouth
/// that starts moving over silence is the single most obvious lip-sync bug.
///
/// The driver is *frame driven*: the owner calls [sample] once per animation
/// frame, so the jaw, the blinking eyelids and the posture all advance on the
/// same frame and nothing keeps ticking between lines.
///
/// ```dart
/// final mouth = AudioSpeakingMouth(audio: AudioScope.maybeOf(context));
/// mouth.startClip('teach_1_en');   // or mouth.startSilent(cadence)
/// mouth.sample(tickerElapsed);      // each frame
/// mouth.mouth;                      // read the shape
/// ```
class AudioSpeakingMouth {
  AudioSpeakingMouth({required AudioController? audio}) : _audio = audio;

  final AudioController? _audio;

  String? _clipId;
  SpeechCadence? _silent;

  /// Audio playhead used to be extrapolated from these two before the driver
  /// started following the frame clock.
  final Stopwatch _stopwatch = Stopwatch();

  /// Elapsed time of the current narration, advanced by the caller's frame
  /// clock when it supplies one (exact in widget tests), otherwise by
  /// [_stopwatch].
  Duration _virtual = Duration.zero;
  Duration? _lastScreenTime;

  /// Hardware playhead anchor: the last position the platform reported, and the
  /// [_virtual] value at the moment it reported it.
  Duration _anchor = Duration.zero;
  Duration _anchorAt = Duration.zero;
  bool _hasAnchor = false;

  MouthFrame _mouth = MouthFrame.closed;
  double _energy = 0;

  /// Measured shape this frame.
  MouthFrame get mouth => _mouth;

  /// Smoothed phrase-level energy (0..1) for posture and breathing emphasis.
  double get energy => _energy;

  /// True while a clip is loaded but silent so far (decode/buffer window).
  bool get buffering {
    final clip = _clipId;
    if (clip == null) return false;
    return _audio?.isBuffering(clip) ?? false;
  }

  /// Follow the real voice of [clipId] until it stops playing.
  void startClip(String clipId) {
    if (_clipId == clipId) return;
    _clipId = clipId;
    _silent = null;
    _restartClock();
  }

  /// Narrate [cadence] with no audio (silent mode, or a line with no clip).
  void startSilent(SpeechCadence cadence) {
    _clipId = null;
    _silent = cadence;
    _restartClock();
  }

  /// Ends narration and closes the mouth immediately.
  void stop() {
    _clipId = null;
    _silent = null;
    _stopwatch
      ..stop()
      ..reset();
    _virtual = Duration.zero;
    _lastScreenTime = null;
    _hasAnchor = false;
    _mouth = MouthFrame.closed;
    _energy = 0;
  }

  void dispose() => stop();

  /// Advances the mouth to the current instant. Cheap; call it every frame.
  ///
  /// [screenTime] is the owner's animation clock (Flutter's ticker elapsed), so
  /// the jaw follows exactly the same frames the sprite is drawn on. Without it
  /// a monotonic stopwatch is used.
  ///
  /// Returns true when the visible shape changed, so an owner can avoid a
  /// pointless rebuild.
  bool sample([Duration? screenTime]) {
    final previousMouth = _mouth;
    final previousEnergy = _energy;
    _advanceClock(screenTime);

    final clip = _clipId;
    if (clip != null) {
      final audio = _audio;
      if (audio == null || !audio.isPlaying(clip)) {
        _set(MouthFrame.closed, 0);
      } else if (audio.isBuffering(clip)) {
        // Loaded but not sounding yet: stay closed until the first sample.
        _hasAnchor = false;
        _set(MouthFrame.closed, 0);
      } else {
        final position = _position(audio, clip);
        _set(
          AudioLipSync.frameAt(clip, position),
          AudioLipSync.energyAt(clip, position),
        );
      }
    } else if (_silent != null) {
      if (_virtual.inMilliseconds >= _silent!.totalMs) {
        _set(MouthFrame.closed, 0);
      } else {
        final frame = _silent!.frameAt(_virtual);
        _set(
          frame,
          switch (frame) {
            MouthFrame.open => 0.55,
            MouthFrame.half => 0.24,
            MouthFrame.closed => 0.0,
          },
        );
      }
    } else {
      _set(MouthFrame.closed, 0);
    }

    return _mouth != previousMouth || (_energy - previousEnergy).abs() >= 0.02;
  }

  void _restartClock() {
    _virtual = Duration.zero;
    _lastScreenTime = null;
    _hasAnchor = false;
    _anchor = Duration.zero;
    _anchorAt = Duration.zero;
    _stopwatch
      ..reset()
      ..start();
  }

  void _advanceClock(Duration? screenTime) {
    if (screenTime == null) {
      _virtual = _stopwatch.elapsed;
      _lastScreenTime = null;
      return;
    }
    final last = _lastScreenTime;
    _lastScreenTime = screenTime;
    if (last == null) return;
    final delta = screenTime - last;
    // Ignore a wild jump (a paused engine, a backgrounded app) rather than
    // teleporting the jaw half a sentence forward.
    if (delta <= Duration.zero || delta > const Duration(milliseconds: 500)) {
      return;
    }
    _virtual += delta;
  }

  /// Real playhead when the platform gives one (two light corrections toward the
  /// hardware number rather than a visible snap), the frame clock extended from
  /// the last report in between, and the frame clock alone when the platform
  /// reports nothing at all (a test fake, or an engine without a position).
  Duration _position(AudioController audio, String clip) {
    final reported = audio.playheadOf(clip);
    final durationMs = AudioLipSync.durationMsOf(clip);
    final ceiling =
        durationMs == null ? null : Duration(milliseconds: durationMs);

    Duration position;
    if (reported != null) {
      if (_hasAnchor) {
        final predicted = _anchor + (_virtual - _anchorAt);
        final drift = reported - predicted;
        // A slow drift is blended away over a few frames; only a real jump
        // (a seek, or a decoder catching up after a stall) is adopted whole.
        if (drift.abs() <= const Duration(milliseconds: 45)) {
          position = predicted + drift ~/ 3;
        } else {
          position = reported;
        }
      } else {
        position = reported;
      }
      _anchor = position;
      _anchorAt = _virtual;
      _hasAnchor = true;
    } else if (_hasAnchor) {
      position = _anchor + (_virtual - _anchorAt);
    } else {
      position = _virtual;
    }

    if (position < Duration.zero) return Duration.zero;
    if (ceiling != null && position > ceiling) return ceiling;
    return position;
  }

  void _set(MouthFrame frame, double energy) {
    _mouth = frame;
    _energy = energy.clamp(0.0, 1.0);
  }
}
