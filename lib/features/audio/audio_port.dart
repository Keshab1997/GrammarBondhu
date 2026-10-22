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
    await _player.setAsset(assetPath);
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
