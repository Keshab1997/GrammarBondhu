import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A slow breathing motion for a still illustration.
///
/// Two characters on a static plate read as a screenshot; a fraction of a
/// percent of scale drift over a few seconds is enough for the eye to read them
/// as alive, and cheap enough for a low-RAM phone.
///
/// Honours the OS "remove animations" setting by stopping the ticker itself —
/// which is also what lets widget tests settle.
class IdleBob extends StatefulWidget {
  const IdleBob({
    super.key,
    required this.child,
    this.period = 4200,
    this.phase = 0,
    this.amplitude = 0.006,
  });

  final Widget child;

  /// Cycle length in milliseconds.
  final int period;

  /// 0..1 start offset, so two figures never breathe in unison.
  final double phase;

  /// Peak scale delta, as a fraction of the child's size.
  final double amplitude;

  @override
  State<IdleBob> createState() => _IdleBobState();
}

class _IdleBobState extends State<IdleBob> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.period),
  );

  @override
  void initState() {
    super.initState();
    _controller.value = widget.phase;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(
          (math.sin(_controller.value * 2 * math.pi) + 1) / 2,
        );
        return Transform.scale(
          scale: 1 + t * widget.amplitude,
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
