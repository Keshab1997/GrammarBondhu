import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../app/theme/app_theme.dart';
import '../utils/asset_lookup.dart';
import '../utils/speech_cadence.dart';
import 'idle_motion.dart';

/// A full-body story character that blinks naturally and moves their mouth in
/// time with spoken dialogue.
///
/// All four frames per character share the exact pixel geometry of the resting
/// full-body sprite, so swapping [Image.asset] with `gaplessPlayback: true`
/// animates only the mouth and eyelids without shifting the clothing or shoes.
/// Honours [MediaQuery.maybeDisableAnimationsOf] by resting on the closed smile
/// with no running ticker, keeping reduced-motion devices and `pumpAndSettle`
/// tests completely calm.
class TalkingCharacter extends StatefulWidget {
  const TalkingCharacter({
    super.key,
    required this.characterId,
    required this.height,
    required this.isSpeaker,
    required this.isTalking,
    this.spokenText = '',
    this.utteranceKey = 0,
    this.loopSpeech = false,
  });

  final String characterId;
  final double height;
  final bool isSpeaker;

  /// True while the character is actively delivering their line (either synced
  /// to playing voice audio or running through the silent speech cadence).
  final bool isTalking;

  /// Text currently being voiced — drives syllable pacing and comma pauses.
  final String spokenText;

  /// Incremented each time a fresh utterance starts so the cadence rewinds to
  /// syllable zero even when the same line is replayed.
  final int utteranceKey;

  /// True while live voice audio is playing so mouth shapes wrap smoothly until
  /// playback completes.
  final bool loopSpeech;

  /// Current resolved frame asset on [TalkingCharacter], exposed as a [ValueKey]
  /// on the rendered [Image] so widget tests can verify real lip-sync and blink
  /// transitions without reaching into private state.
  static const blinkDurationMs = 155;

  @override
  State<TalkingCharacter> createState() => _TalkingCharacterState();
}

class _TalkingCharacterState extends State<TalkingCharacter>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  late SpeechCadence _cadence = SpeechCadence.fromText(widget.spokenText);

  Duration _lastElapsed = Duration.zero;
  Duration _speechOrigin = Duration.zero;
  MouthFrame _mouth = MouthFrame.closed;
  bool _blinking = false;
  bool _reduceMotion = false;
  String? _warmedCharacter;

  /// Deterministic per-character blink cycle so two actors standing together
  /// never blink in lockstep.
  int get _blinkPeriodMs {
    switch (widget.characterId) {
      case 'rahul':
        return 3400;
      case 'priya':
        return 4150;
      case 'teacher':
        return 3800;
      default:
        return 3600 + (widget.characterId.hashCode.abs() % 700);
    }
  }

  int get _blinkOffsetMs {
    switch (widget.characterId) {
      case 'rahul':
        return 900;
      case 'priya':
        return 2100;
      case 'teacher':
        return 1450;
      default:
        return 1100;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _warmFramesIfNeeded();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant TalkingCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.characterId != widget.characterId) {
      _warmFramesIfNeeded();
    }
    final restarted = oldWidget.utteranceKey != widget.utteranceKey ||
        oldWidget.spokenText != widget.spokenText ||
        (!oldWidget.isTalking && widget.isTalking);
    if (restarted) {
      _cadence = SpeechCadence.fromText(widget.spokenText);
      _speechOrigin = _lastElapsed;
    }
    if (!widget.isTalking && _mouth != MouthFrame.closed) {
      _mouth = MouthFrame.closed;
    }
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _warmFramesIfNeeded() {
    if (_warmedCharacter == widget.characterId) return;
    _warmedCharacter = widget.characterId;
    final frames = AssetLookup.framesFor(widget.characterId);
    if (frames == null) return;
    for (final path in frames.all) {
      precacheImage(AssetImage(path), context).catchError((_) {});
    }
  }

  void _syncTicker() {
    final hasFrames = AssetLookup.framesFor(widget.characterId) != null;
    final shouldRun = !_reduceMotion && hasFrames;
    if (shouldRun && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _speechOrigin = Duration.zero;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
      if (_mouth != MouthFrame.closed || _blinking) {
        setState(() {
          _mouth = MouthFrame.closed;
          _blinking = false;
        });
      }
    }
  }

  void _onTick(Duration elapsed) {
    _lastElapsed = elapsed;

    final nextMouth = widget.isTalking
        ? _cadence.frameAt(
            elapsed - _speechOrigin,
            loop: widget.loopSpeech,
          )
        : MouthFrame.closed;

    final cyclePos = (elapsed.inMilliseconds + _blinkOffsetMs) % _blinkPeriodMs;
    final nextBlink = cyclePos < TalkingCharacter.blinkDurationMs;

    if (nextMouth != _mouth || nextBlink != _blinking) {
      setState(() {
        _mouth = nextMouth;
        _blinking = nextBlink;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final frames = AssetLookup.framesFor(widget.characterId);
    final activeMouth =
        (_reduceMotion || !widget.isTalking) ? MouthFrame.closed : _mouth;
    final activeBlink = !_reduceMotion && _blinking;
    final path = frames?.resolve(mouth: activeMouth, blinking: activeBlink) ??
        AssetLookup.fullBodyPath(widget.characterId);
    final name = AssetLookup.characterDisplayName(widget.characterId);

    Widget art = path == null
        ? _FallbackBody(name: name, height: widget.height)
        : Image.asset(
            path,
            key: ValueKey<String>(path),
            height: widget.height,
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) =>
                _FallbackBody(name: name, height: widget.height),
          );

    // Subtle vocal emphasis: an open vowel lifts the torso by ~0.5% anchored at
    // the shoes so the character feels physically engaged in the sentence, not
    // like a mannequin with a flapping mouth.
    final speechLift = activeMouth == MouthFrame.open
        ? 1.007
        : activeMouth == MouthFrame.half
            ? 1.003
            : 1.0;
    if (!_reduceMotion && widget.isSpeaker) {
      art = AnimatedScale(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        scale: speechLift,
        alignment: Alignment.bottomCenter,
        child: art,
      );
    }

    // A touch of warmth on whoever is talking. Dimming the listener alone left
    // the speaker looking like anyone else; the highlight does the pointing.
    if (widget.isSpeaker) {
      art = ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x14FFF3D6), Color(0x00FFF3D6)],
          stops: [0.0, 0.45],
        ).createShader(Offset.zero & rect.size),
        child: art,
      );
    }

    final phase = (widget.characterId.hashCode.abs() % 1000) / 1000.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: widget.isSpeaker ? 1 : 0.82,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        scale: widget.isSpeaker ? 1 : 0.97,
        alignment: Alignment.bottomCenter,
        child: IdleBob(
          period: widget.isSpeaker ? 3600 : 4600,
          phase: phase,
          amplitude: widget.isTalking ? 0.004 : 0.006,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Contact shadow: without it the feet float over the scene.
              Container(
                width: widget.height * 0.26,
                height: widget.height * 0.035,
                margin: EdgeInsets.only(bottom: widget.height * 0.004),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
              art,
            ],
          ),
        ),
      ),
    );
  }
}

class _FallbackBody extends StatelessWidget {
  const _FallbackBody({required this.name, required this.height});

  final String name;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: height * 0.36,
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.skyTop],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(height * 0.18),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: height * 0.16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
