import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// One place for the layout decisions a large font scale forces.
///
/// At the default scale a row of three stats, a chip rail or a sheet title all
/// fit on a 320 dp phone; at 200% (Android's "Largest" accessibility setting,
/// and the scale a low-vision learner actually runs) the same row is twice as
/// wide and overflows. Squeezing the type instead of reflowing it would defeat
/// the setting the person turned on, so everything here reflows or wraps.
class AccessibleLayout {
  const AccessibleLayout._();

  /// The scale below which the default, compact layouts are safe.
  ///
  /// 1.3 is not a guess: Android's four standard font sizes are 0.85, 1.0,
  /// 1.15 and 1.3, so 1.3 is the last step that does not ask for a redesign.
  static const double reflowThreshold = 1.3;

  /// True when text is scaled past the point where a fixed row still fits.
  static bool needsReflow(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) > reflowThreshold;

  /// True when the short edge is narrow enough that a dense row is a gamble,
  /// regardless of the type size.
  static bool isNarrow(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 340;

  /// Reflow, *or* a phone narrow enough that the compact row would not fit
  /// even at the default scale.
  static bool isCompact(BuildContext context) =>
      needsReflow(context) || isNarrow(context);

  /// The shortest side of a square touch target, in dp of *layout* space.
  ///
  /// Material's 48 dp target is about a fingertip, not about a glyph: the
  /// platform does not shrink a finger when the user enlarges text. Flutter
  /// scales a tap area with `textScaler` only when the widget opts in, so a
  /// 30 dp icon button is 30 dp at 200% type as well. Callers pass this to
  /// [minimumTarget] to keep it 48 while the glyph inside may grow.
  static const double minTouchTarget = 48;

  /// Guarantees [child] is at least a 48 dp tap area on both axes.
  ///
  /// The hit area is what grows; the visual is left alone.
  static Widget minimumTarget(Widget child) => ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: minTouchTarget,
          minHeight: minTouchTarget,
        ),
        child: Center(widthFactor: 1, heightFactor: 1, child: child),
      );

  /// The longest label that still reads on one line at this width, or null if
  /// the layout has room for the full text.
  ///
  /// Deliberately a measurement rather than a character count: the bundled
  /// display face and Bengali's taller glyphs make a count unreliable.
  static double? availableLabelWidth(
    BuildContext context, {
    required double reserved,
    required double horizontalPadding,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final left = math.max(0.0, width - reserved - horizontalPadding);
    return left == 0 ? null : left;
  }
}
