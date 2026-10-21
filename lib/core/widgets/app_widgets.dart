import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Primary CTA — the warm yellow pill used for "Let's Begin", "Start",
/// "Next Chapter". Falls back to blue style when [style] is [ButtonStyle.primary].
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(label),
      ],
    );

    switch (variant) {
      case AppButtonVariant.primary:
        final button = ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.textPrimary,
          ),
          child: child,
        );
        return expand ? button : _wrap(button);
      case AppButtonVariant.blue:
        final button = ElevatedButton(onPressed: onPressed, child: child);
        return expand ? button : _wrap(button);
      case AppButtonVariant.outline:
        final button = OutlinedButton(onPressed: onPressed, child: child);
        return expand ? button : _wrap(button);
      case AppButtonVariant.success:
        final button = ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: AppColors.textOnDark,
          ),
          child: child,
        );
        return expand ? button : _wrap(button);
    }
  }

  Widget _wrap(Widget button) => button;
}

enum AppButtonVariant { primary, blue, outline, success }

/// Soft rounded card used across screens.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.color = AppColors.surface,
    this.radius = AppRadii.card,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Padding(padding: padding, child: child),
      ),
    );
    return card;
  }
}

/// Horizontal progress bar with rounded ends.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.value,
    this.height = 12,
    this.color = AppColors.primary,
    this.trackColor = AppColors.primarySoft,
  });

  /// 0.0–1.0
  final double value;
  final double height;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: trackColor,
          color: color,
          minHeight: height,
        ),
      ),
    );
  }
}

/// Star row used on completion and chapter cards.
class StarsDisplay extends StatelessWidget {
  const StarsDisplay({super.key, required this.count, this.total = 3, this.size = 28});

  final int count;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++) ...[
          Icon(
            i < count ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i < count ? AppColors.accent : AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          if (i < total - 1) SizedBox(width: size * 0.15),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.chip),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.primarySoft,
          borderRadius: BorderRadius.circular(AppRadii.chip),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (flag != null)
              Text(flag!, style: const TextStyle(fontSize: 16))
            else
              Icon(Icons.language, size: 16, color: selected ? Colors.white : AppColors.primary),
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
    );
  }
}
