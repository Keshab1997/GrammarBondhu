import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// The bit of audio playback the app actually needs: play one bundled clip,
/// stop, and know when it finished.
///
/// An interface rather than a direct `just_audio` call so widget tests can run
/// with no platform channel — a test asserts *which clip was requested*, not
/// that a phone made a noise.
abstract class AudioPort {
  Future<void> playAsset(String assetPath);

  Future<void> stop();

  /// Fires once each time a clip plays to its end (or fails).
  Stream<void> get completions;

  /// The real hardware playhead inside the clip that is sounding right now, or
  /// null when nothing has started moving yet (still decoding/buffering, or
  /// stopped). Lip-sync reads this so a mouth waits politely through a slow
  /// first load instead of flapping ahead of a silent phone.
  ///
  /// A fake port may leave this at null; the controller then falls back to its
  /// own stopwatch, so animation never freezes in tests or on a stubborn
  /// platform.
  Duration? get position => null;

  /// Whether this port can report a real playhead at all. A fake in a test says
  /// no (so animation is driven by the test clock instead of a hardware
  /// number), and so does a platform that cannot answer.
  bool get supportsPosition => false;

  Future<void> dispose();
}

/// Real playback: one player for the whole app, so starting a new clip stops
/// the old one instead of talking over it.
class JustAudioPort implements AudioPort {
  JustAudioPort() {
    _player.playerStateStream.listen(
      (state) {
        if (state.processingState == ProcessingState.completed) {
          _completions.add(null);
        }
      },
      onError: (Object error) {
        // Reported, not swallowed: "no sound" is impossible to debug from a
        // phone without the actual reason.
        debugPrint('GrammarBondhu audio: player error — $error');
        _completions.add(null);
      },
    );
  }

  final AudioPlayer _player = AudioPlayer();
  final StreamController<void> _completions =
      StreamController<void>.broadcast();
  Future<void>? _sessionReady;

  @override
  Stream<void> get completions => _completions.stream;

  /// Set once the current source has finished loading; before that the player
  /// still reports the previous clip's offset, which must never drive a mouth.
  bool _loaded = false;

  @override
  Duration? get position {
    if (_player.processingState == ProcessingState.idle ||
        _player.processingState == ProcessingState.loading) {
      return null;
    }
    // `AudioPlayer.position` before the first playback event is still the
    // previous clip's (or zero) offset; the controller treats a missing
    // playhead as "buffering" and keeps the mouth closed until it moves.
    if (!_loaded) return null;
    final pos = _player.position;
    return pos > Duration.zero ? pos : null;
  }

  @override
  bool get supportsPosition => true;

  /// Tell the OS what kind of sound this is.
  ///
  /// Two things go wrong without it: an iPhone with the ringer switch off
  /// plays narration silently (the default category obeys the switch), and on
  /// Android the clip is cut short the moment the learner touches their music
  /// app. A speech session keeps our own sound audible and polite.
  Future<void> _ensureSession() {
    return _sessionReady ??= () async {
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration.speech());
      } catch (error) {
        // A missing platform implementation must not stop playback itself.
        debugPrint('GrammarBondhu audio: session config failed — $error');
      }
    }();
  }

  @override
  Future<void> playAsset(String assetPath) async {
    await _ensureSession();
    debugPrint('GrammarBondhu audio: loading $assetPath');
    _loaded = false;
    await _player.setAsset(assetPath);
    _loaded = true;
    // Not awaited: play() only completes when the clip ends, and the caller
    // (a tap) must not be held open for the length of the sentence.
    unawaited(_player.play());
  }

  @override
  Future<void> stop() async {
    await _player.stop();
  }

  @override
  Future<void> dispose() async {
    await _player.dispose();
    await _completions.close();
  }
}
