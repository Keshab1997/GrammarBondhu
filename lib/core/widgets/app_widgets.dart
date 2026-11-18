import 'package:material_ui/material_ui.dart';

import '../../app/theme/app_theme.dart';
import '../utils/asset_lookup.dart';

/// Primary CTA — supports gradient variants for a premium feel.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.expand = true,
    this.shine = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool expand;

  /// A slow highlight that sweeps across the gradient. Off by default — it
  /// belongs on the one hero CTA per screen, not on every button in the app.
  final bool shine;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with TickerProviderStateMixin {
  bool _pressed = false;
  AnimationController? _sweep;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateSweep();
  }

  @override
  void didUpdateWidget(covariant AppButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateSweep();
  }

  void _updateSweep() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion || !widget.shine || widget.onPressed == null) {
      _sweep?.dispose();
      _sweep = null;
      return;
    }
    // A single sweep gives the CTA emphasis without a perpetual ticker.
    _sweep ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _sweep?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final isOutline = widget.variant == AppButtonVariant.outline;
    final radius = BorderRadius.circular(AppRadii.button);
    final sweep = _sweep;

    final child = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
        ],
        // Let long or scaled labels wrap before they grow the tap target.
        Flexible(
          child: Text(widget.label, textAlign: TextAlign.center),
        ),
      ],
    );

    // Colors, gradient and shadow per variant.
    late Gradient gradient;
    late List<BoxShadow> shadow;
    late Color foreground;

    switch (widget.variant) {
      case AppButtonVariant.primary: // warm yellow
        gradient = const LinearGradient(
          colors: [AppColors.goldTop, AppColors.accentDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        shadow = AppShadows.buttonYellow;
        foreground = AppColors.textPrimary;
        break;
      case AppButtonVariant.blue:
        gradient = const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        shadow = AppShadows.button;
        foreground = AppColors.textOnDark;
        break;
      case AppButtonVariant.outline:
        gradient = const LinearGradient(colors: [Colors.white, Colors.white]);
        shadow = AppShadows.cardSoft;
        foreground = AppColors.primary;
        break;
      case AppButtonVariant.success:
        gradient = const LinearGradient(
          colors: [Color(0xFF34D399), AppColors.successDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        shadow = AppShadows.buttonSuccess;
        foreground = AppColors.textOnDark;
        break;
    }

    final labelColor = disabled ? AppColors.primaryDeeper : foreground;
    final button = AnimatedContainer(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(
        0,
        _pressed && !disabled && !reduceMotion ? 2 : 0,
        0,
      ),
      decoration: BoxDecoration(
        gradient: disabled ? null : gradient,
        color: disabled ? AppColors.backgroundAlt : null,
        borderRadius: radius,
        boxShadow: disabled ? null : shadow,
      ),
      foregroundDecoration: isOutline
          ? BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: disabled ? AppColors.textMuted : AppColors.primary,
                width: 1.5,
              ),
            )
          : null,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            if (sweep != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: sweep,
                    builder: (context, child) {
                      final t = Curves.easeInOut.transform(sweep.value);
                      return FractionalTranslation(
                        translation: Offset(-1.6 + 3.2 * t, 0),
                        child: child,
                      );
                    },
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0x47FFFFFF),
                            Colors.transparent,
                          ],
                          stops: [0.30, 0.5, 0.70],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onPressed,
                onHighlightChanged: (v) => setState(() => _pressed = v),
                borderRadius: radius,
                splashFactory: reduceMotion ? NoSplash.splashFactory : null,
                splashColor: isOutline ? AppColors.primarySoft : null,
                highlightColor: isOutline ? AppColors.primarySoft : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 58),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.expand ? AppSpacing.sm : AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: Center(
                      widthFactor: 1,
                      heightFactor: 1,
                      child: DefaultTextStyle.merge(
                        style: TextStyle(
                          color: labelColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 0.2,
                        ),
                        child: IconTheme.merge(
                          data: IconThemeData(color: labelColor),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.expand) return SizedBox(width: double.infinity, child: button);
    final width = MediaQuery.maybeSizeOf(context)?.width;
    if (width != null &&
        width < 340 &&
        MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      // Shrink-wrapped CTAs can sit in a Row beside page indicators.
      // Reserve room for the other children and let the label wrap instead.
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width * 0.6),
        child: button,
      );
    }
    return button;
  }
}

enum AppButtonVariant { primary, blue, outline, success }

/// Soft rounded card with subtle drop shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color = AppColors.surface,
    this.radius = AppRadii.card,
    this.onTap,
    this.gradient,
    this.elevation = true,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Gradient? gradient;
  final double radius;
  final VoidCallback? onTap;
  final bool elevation;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final corners = BorderRadius.circular(radius);
    final rim = border ??
        (gradient == null
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.08))
            : null);
    final inkColor = AppColors.primary.withValues(alpha: 0.06);
    return AnimatedContainer(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: corners,
        boxShadow: elevation ? AppShadows.card : null,
      ),
      foregroundDecoration: rim == null
          ? null
          : BoxDecoration(borderRadius: corners, border: rim),
      child: Material(
        color: Colors.transparent,
        borderRadius: corners,
        clipBehavior: onTap == null ? Clip.none : Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: corners,
          splashFactory: reduceMotion ? NoSplash.splashFactory : null,
          splashColor: inkColor,
          highlightColor: inkColor,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Horizontal progress bar with rounded ends and optional gradient.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 12,
    this.color = AppColors.primary,
    this.trackColor,
    this.gradient,
  });

  /// 0.0–1.0
  final double value;
  final double height;
  final Color color;
  final Color? trackColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Stack(
        children: [
          Container(
            height: height,
            color: trackColor ?? AppColors.primarySoft,
          ),
          if (clamped > 0)
            FractionallySizedBox(
              widthFactor: clamped,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: gradient ??
                      LinearGradient(
                        colors: [color, Color.lerp(color, Colors.white, 0.16)!],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                  borderRadius: BorderRadius.circular(height / 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Star row used on completion and chapter cards.
class StarsDisplay extends StatelessWidget {
  const StarsDisplay(
      {super.key, required this.count, this.total = 3, this.size = 28});

  final int count;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          _star(i < count, i, reduceMotion),
          if (i < total - 1) SizedBox(width: size * 0.1),
        ],
      ],
    );
  }

  Widget _star(bool earned, int index, bool reduceMotion) {
    final scale = earned ? 1.0 : 0.88;
    final icon = Icon(
      earned ? Icons.star_rounded : Icons.star_outline_rounded,
      size: size,
      color: earned
          ? AppColors.accent
          : AppColors.textMuted.withValues(alpha: 0.55),
      shadows: earned
          ? [
              Shadow(
                color: AppColors.accentDark.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
    if (reduceMotion) return Transform.scale(scale: scale, child: icon);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: scale),
      duration: Duration(milliseconds: 400 + index * 120),
      curve: Curves.elasticOut,
      builder: (_, value, child) => Transform.scale(scale: value, child: child),
      child: icon,
    );
  }
}

/// Small language chip (flag + code) — EN / বাং / हि.
class LanguageChip extends StatelessWidget {
  const LanguageChip({
    super.key,
    required this.code,
    required this.label,
    this.flag,
    this.selected = false,
    this.onTap,
  });

  final String code;
  final String label;
  final String? flag;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 220);
    final corners = BorderRadius.circular(AppRadii.chip);
    final foreground = selected ? AppColors.textOnDark : AppColors.primary;
    final flagAsset = switch (flag) {
      '🇬🇧' => AssetLookup.iconPath('flag_en'),
      '🇧🇩' => AssetLookup.iconPath('flag_bn'),
      '🇮🇳' => AssetLookup.iconPath('flag_hi'),
      _ => null,
    };
    final flagFallback = Text(flag ?? '', style: const TextStyle(fontSize: 16));
    final width = MediaQuery.maybeSizeOf(context)?.width ?? double.infinity;
    // On compact screens the onboarding page places three chips in one row.
    final compact =
        width < 340 || MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(
        minHeight: onTap == null ? 0 : 48,
        maxWidth: compact
            ? ((width - 2 * AppSpacing.lg - 2 * AppSpacing.sm) / 3)
                .clamp(48.0, 120.0)
                .toDouble()
            : double.infinity,
      ),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : AppColors.primarySoft,
        borderRadius: corners,
        boxShadow: selected ? AppShadows.cardSoft : null,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: corners,
        border: Border.all(
          color: selected
              ? AppColors.primaryDark
              : AppColors.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: corners,
          splashFactory: reduceMotion ? NoSplash.splashFactory : null,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (flagAsset != null)
                  Image.asset(
                    flagAsset,
                    width: 16,
                    height: 16,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => flagFallback,
                  )
                else if (flag != null)
                  flagFallback
                else
                  Icon(Icons.language, size: 16, color: foreground),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
