import 'dart:async';

import 'package:flutter/material.dart';

/// The scene inside the splash frame, played as a slow slideshow.
///
/// `assets/frames/frame_00…09.webp` are ten renders of the same illustration:
/// same camera, same school, same garden, same light — only Rahul moves, by a
/// few centimetres per frame (an arm, a blink, a smile). They are ordered so
/// each step is the smallest change available, then cross-faded. The result
/// reads as one continuous shot instead of ten images swapping.
///
/// Two deliberate choices:
///
/// * **The fade is long relative to the hold.** 900 ms of cross-fade against
///   2.6 s of still means the eye never sees a cut, only drift.
/// * **It stops.** One full pass, then the last frame is held. An endlessly
///   repeating timer (or any never-ending animation) keeps a widget test from
///   ever settling, which would turn every `pumpAndSettle` in this repo into a
///   ten-minute timeout instead of a pass.
class HeroFrames extends StatefulWidget {
  const HeroFrames({
    super.key,
    this.hold = const Duration(milliseconds: 2600),
    this.fade = const Duration(milliseconds: 900),
    this.frameCount = 10,
    this.playOnce = true,
  });

  /// How long each frame is still before the next fade starts.
  final Duration hold;

  /// Cross-fade length. Long on purpose — see the class comment.
  final Duration fade;

  final int frameCount;

  /// When false the slideshow loops forever (preview only — see the note about
  /// tests above).
  final bool playOnce;

  static String assetFor(int index) =>
      'assets/frames/frame_${index.toString().padLeft(2, '0')}.webp';

  @override
  State<HeroFrames> createState() => _HeroFramesState();
}

class _HeroFramesState extends State<HeroFrames> {
  int _index = 0;
  Timer? _tick;
  bool _warmed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_warmed) return;
    _warmed = true;
    // Warm the cache in the background and start the clock now: ten decodes
    // finish in well under the first 2.6 s hold, so the first cross-fade never
    // catches an undecoded frame — but the slideshow is never blocked on IO.
    _warmUp();
    _schedule();
  }

  /// Decode every frame before the first cross-fade.
  ///
  /// Without this the slideshow shows an empty card for a few hundred ms
  /// whenever it moves to a frame that has not been decoded yet — a still
  /// screen that blinks is worse than one that never moves.
  Future<void> _warmUp() async {
    for (var i = 0; i < widget.frameCount; i++) {
      if (!mounted) return;
      // A missing frame is not fatal: the build falls back to the hero art.
      await precacheImage(AssetImage(HeroFrames.assetFor(i)), context)
          .catchError((_) {});
    }
  }

  void _schedule() {
    _tick?.cancel();
    _tick = Timer(widget.hold, () {
      if (!mounted) return;
      final next = (_index + 1) % widget.frameCount;
      if (widget.playOnce && next == 0) return; // one pass, then hold
      setState(() => _index = next);
      _schedule();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: widget.fade,
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      // Both frames stay mounted through the swap, so the cross-fade is a
      // blend of two images rather than a fade through the background.
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, if (current != null) current],
      ),
      child: Image.asset(
        HeroFrames.assetFor(_index),
        key: ValueKey<int>(_index),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        // Decode the next frame before we need it, so a fade never starts on a
        // blank frame.
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Image.asset(
          'assets/illustrations/splash_hero.webp',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}
