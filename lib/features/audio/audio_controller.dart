import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../app/state/settings_controller.dart';
import 'audio_catalog.g.dart';
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
    _completion = _port.completions.listen((_) {
      if (_playing == null) return;
      _playing = null;
      notifyListeners();
    });
    // The Audio switch in Settings changes whether speakers are offered at
    // all; mirror that change to every listening button.
    _settings.addListener(_onSettingsChanged);
  }

  final AudioPort _port;
  final SettingsController _settings;
  late final StreamSubscription<void> _completion;

  String? _playing;

  /// The clip that is currently sounding, if any.
  String? get playingId => _playing;

  /// False when the learner has switched narration off in Settings.
  bool get enabled => _settings.audioEnabled;

  bool isPlaying(String clipId) => _playing == clipId;

  /// True when this clip can be offered at all: narration is on and the clip
  /// really shipped in the bundle.
  bool canPlay(String clipId) => enabled && AudioCatalog.has(clipId);

  /// Tap behaviour: start this clip, or stop it if it is already sounding.
  Future<void> toggle(String clipId) async {
    if (_playing == clipId) {
      await stop();
      return;
    }
    if (!canPlay(clipId)) return;
    _playing = clipId;
    notifyListeners();
    try {
      await _port.playAsset(AudioCatalog.assetFor(clipId));
    } catch (_) {
      // A clip that will not decode must not leave a button stuck in
      // "playing" forever.
      if (_playing == clipId) {
        _playing = null;
        notifyListeners();
      }
    }
  }

  Future<void> stop() async {
    if (_playing == null) return;
    _playing = null;
    notifyListeners();
    try {
      await _port.stop();
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
    _completion.cancel();
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
