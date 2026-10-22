import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

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
  void initState() {
    super.initState();
    if (widget.shine) {
      // One sweep, then rest. A looping sweep is the kind of motion that stops
      // feeling premium by the third pass — and an endlessly repeating
      // animation never lets a widget test settle.
      _sweep = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sweep?.forward();
      });
    }
  }

  @override
  void dispose() {
    _sweep?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null;

    final child = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
        ],
        // Flexible, not bare: a long label ("I understand — quiz me") overflowed
        // the row by ~96 px on a 320 dp phone instead of wrapping.
        Flexible(
          child: Text(
            widget.label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
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

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      height: 58,
      padding:
          EdgeInsets.symmetric(horizontal: widget.expand ? 0 : AppSpacing.xl),
      transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
      decoration: BoxDecoration(
        gradient: disabled ? null : gradient,
        color: disabled
            ? AppColors.textMuted.withValues(alpha: 0.5)
            : (widget.variant == AppButtonVariant.outline
                ? Colors.white
                : null),
        borderRadius: BorderRadius.circular(AppRadii.button),
        border: widget.variant == AppButtonVariant.outline
            ? Border.all(
                color: AppColors.primary.withValues(alpha: disabled ? 0.3 : 1),
                width: 1.8)
            : null,
        boxShadow: disabled ? [] : shadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: Stack(
          children: [
            if (_sweep != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _sweep!,
                    builder: (context, _) {
                      // Ease the sweep so it enters and leaves instead of
                      // snapping on at the button's edge.
                      final t = Curves.easeInOut.transform(_sweep!.value);
                      return FractionalTranslation(
                        translation: Offset(-1.6 + 3.2 * t, 0),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0x00FFFFFF),
                                Color(0x47FFFFFF),
                                Color(0x00FFFFFF),
                              ],
                              stops: [0.30, 0.5, 0.70],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                onHighlightChanged: (v) => setState(() => _pressed = v),
                borderRadius: BorderRadius.circular(AppRadii.button),
                child: Center(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      color: foreground.withValues(alpha: disabled ? 0.7 : 1),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                    child: IconTheme.merge(
                      data: IconThemeData(
                        color: foreground.withValues(alpha: disabled ? 0.7 : 1),
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!widget.expand) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
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
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Gradient? gradient;
  final double radius;
  final VoidCallback? onTap;
  final bool elevation;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevation ? AppShadows.card : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
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
          FractionallySizedBox(
            widthFactor: clamped,
            child: Container(
              height: height,
              decoration: BoxDecoration(
                gradient: gradient ??
                    LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.5, end: i < count ? 1.0 : 0.6),
            duration: Duration(milliseconds: 400 + i * 120),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(
              scale: v,
              child: Icon(
                i < count ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size,
                color: i < count
                    ? AppColors.accent
                    : AppColors.textSecondary.withValues(alpha: 0.3),
                shadows: i < count
                    ? [
                        BoxShadow(
                          color: AppColors.accentDark.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
            ),
          ),
          if (i < total - 1) SizedBox(width: size * 0.1),
        ],
      ],
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1.6,
            ),
            boxShadow: selected ? AppShadows.cardSoft : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (flag != null)
                Text(flag!, style: const TextStyle(fontSize: 16))
              else
                Icon(Icons.language,
                    size: 16,
                    color: selected ? Colors.white : AppColors.primary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
