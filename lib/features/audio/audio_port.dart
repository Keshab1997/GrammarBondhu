import 'dart:async';

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
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _completions.add(null);
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final StreamController<void> _completions =
      StreamController<void>.broadcast();

  @override
  Stream<void> get completions => _completions.stream;

  @override
  Future<void> playAsset(String assetPath) async {
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
