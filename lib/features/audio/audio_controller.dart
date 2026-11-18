import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../app/state/settings_controller.dart';
import 'audio_catalog.g.dart';
import 'audio_lipsync.g.dart';
import 'audio_port.dart';

/// One clip at a time, app-wide.
///
/// Two buttons on the same story page must never talk over each other, and the
/// teacher's line has to stop when the learner turns the page — so playback
/// state lives here rather than inside each button.
class AudioController extends ChangeNotifier {
  AudioController(
      {required AudioPort port, required SettingsController settings})
      : _port = port,
        _settings = settings {
    // The Audio switch in Settings changes whether speakers are offered at
    // all; mirror that change to every listening button.
    _settings.addListener(_onSettingsChanged);
  }

  final AudioPort _port;
  final SettingsController _settings;
  StreamSubscription<void>? _completion;
  int _request = 0;
  Future<void>? _stopping;

  String? _playing;
  String? _lastCompletedId;
  int _completedCount = 0;

  /// Why the last attempt failed, if it did. Surfaced by the button so a
  /// silent phone can be debugged without a cable attached.
  Object? _lastError;

  Object? get lastError => _lastError;

  /// The clip that is currently sounding, if any.
  String? get playingId => _playing;

  /// Most recent clip that played all the way to its natural end (not stopped
  /// early by a tap, page turn or clip switch), paired with [completedCount].
  String? get lastCompletedId => _lastCompletedId;
  int get completedCount => _completedCount;

  /// False when the learner has switched narration off in Settings.
  bool get enabled => _settings.audioEnabled;

  bool isPlaying(String clipId) => _playing == clipId;

  /// The hardware playhead inside [clipId], or null when the platform does not
  /// report one (or has not started producing sound yet).
  ///
  /// Null is meaningful: it is how a caller learns to hold the mouth closed
  /// while a clip decodes or buffers instead of miming over silence. Callers
  /// that need a value between reports anchor on this and extrapolate with
  /// their own frame clock.
  Duration? playheadOf(String clipId) {
    if (_playing != clipId) return null;
    if (!_port.supportsPosition) return null;
    final reported = _port.position;
    if (reported == null) return null;
    final duration = AudioLipSync.durationMsOf(clipId);
    if (duration != null && reported.inMilliseconds > duration) {
      return Duration(milliseconds: duration);
    }
    return reported;
  }

  /// True while the clip is loaded but no sound has come out yet — a cold
  /// decode, a slow asset, or the first frames after a tap. The speaker keeps
  /// their mouth politely closed instead of miming over silence.
  bool isBuffering(String clipId) {
    if (_playing != clipId) return false;
    if (!_port.supportsPosition) return false;
    return _port.position == null;
  }

  /// True when this clip can be offered at all: narration is on and the clip
  /// really shipped in the bundle.
  bool canPlay(String clipId) => enabled && AudioCatalog.has(clipId);

  /// Starts [clipId] from the beginning, replacing anything currently playing.
  ///
  /// Used by story auto-play so entering a line never toggles it off by
  /// mistake; [toggle] stays for interactive speaker buttons.
  Future<bool> play(String clipId) async {
    if (!canPlay(clipId)) return false;
    return _start(clipId);
  }

  /// Tap behaviour: start this clip, or stop it if it is already sounding.
  ///
  /// Returns false when playback could not start, so the caller can say so
  /// instead of leaving the learner tapping a dead button.
  Future<bool> toggle(String clipId) async {
    if (_playing == clipId) {
      await stop();
      return true;
    }
    if (!canPlay(clipId)) return false;
    return _start(clipId);
  }

  Future<bool> _start(String clipId) async {
    final request = _newRequest();
    final switching = _playing != null;
    _playing = clipId;
    _lastError = null;
    try {
      final stopping = switching ? _stopPort() : _stopping;
      notifyListeners();
      if (stopping != null) await stopping;
      if (request != _request) return true;
      await _port.playAsset(AudioCatalog.assetFor(clipId));
      if (request != _request) return true;

      // The port broadcasts unlabelled end events. Retire A's listener before
      // stopping it and only arm B's once its source has finished loading.
      _completion = _port.completions.listen((_) {
        if (request != _request || _playing == null) return;
        final finished = _playing;
        _playing = null;
        _lastCompletedId = finished;
        _completedCount += 1;
        notifyListeners();
      });
      return true;
    } catch (error, stack) {
      // Superseding a play request can interrupt its decoder. That is not a
      // failure of the *current* tap, even when it asked for the same clip.
      if (request != _request) return true;
      debugPrint(
          'GrammarBondhu audio: could not play $clipId — $error\n$stack');
      _lastError = error;
      _playing = null;
      notifyListeners();
      return false;
    }
  }

  int _newRequest() {
    final request = ++_request;
    unawaited(_completion?.cancel());
    _completion = null;
    return request;
  }

  // An explicit stop (or a rapid A → B → C switch) can still be in flight
  // when the next tap arrives. Wait for that same stop before playing.
  Future<void> _stopPort() =>
      _stopping ??= Future<void>.sync(_port.stop).whenComplete(() {
        _stopping = null;
      });

  Future<void> stop() async {
    _newRequest();
    if (_playing == null) return;
    _playing = null;
    final stopping = _stopPort();
    notifyListeners();
    try {
      await stopping;
    } catch (_) {
      // Nothing to recover: the UI is already back to "not playing".
    }
  }

  void _onSettingsChanged() {
    if (!enabled && _playing != null) {
      unawaited(stop());
      return;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _newRequest();
    _playing = null;
    _port.dispose();
    super.dispose();
  }
}

/// Makes the single [AudioController] reachable from any screen.
///
/// An [InheritedNotifier] rather than a Provider: the controller is audio
/// hardware, not app state, and screens that render without it (golden tests,
/// the storyboard harness) simply show no speakers instead of crashing.
class AudioScope extends InheritedNotifier<AudioController> {
  const AudioScope({
    super.key,
    required AudioController controller,
    required super.child,
  }) : super(notifier: controller);

  static AudioController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AudioScope>()?.notifier;

  static AudioController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No AudioScope above this widget');
    return controller!;
  }
}
