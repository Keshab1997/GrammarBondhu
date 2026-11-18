import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import '../utils/asset_lookup.dart';

/// Character portrait with a designed fallback.
///
/// The app must run before art assets exist — a missing file shows a
/// friendly initial avatar instead of a broken image.
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.characterId,
    this.size = 72,
    this.showBorder = true,
  });

  final String characterId;
  final double size;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final path = AssetLookup.characterPath(characterId);
    final name = AssetLookup.characterDisplayName(characterId);
    final fallback = _FallbackAvatar(name: name, size: size);
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: showBorder && size >= 40 ? AppShadows.cardSoft : null,
        ),
        child: ClipOval(
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.primarySoft),
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: showBorder
                    ? Border.all(
                        color: Colors.white, width: size >= 44 ? 2 : 1.5)
                    : null,
              ),
              child: path == null
                  ? fallback
                  : Image.asset(
                      path,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => fallback,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  const _FallbackAvatar({required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.skyTop],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Scene background with a designed fallback gradient.
class SceneBackground extends StatelessWidget {
  const SceneBackground({
    super.key,
    required this.backgroundId,
    required this.child,
  });

  final String? backgroundId;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path =
        backgroundId == null ? null : AssetLookup.backgroundPath(backgroundId!);
    final fallback = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.skyTop, AppColors.skyBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (path == null)
          fallback
        else
          Image.asset(
            path,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => fallback,
          ),
        child,
      ],
    );
  }
}

/// Chapter thumbnail with a designed fallback.
class ChapterThumbnail extends StatelessWidget {
  const ChapterThumbnail({
    super.key,
    required this.assetPath,
    required this.fallbackIcon,
    this.size = 64,
    this.radius = AppRadii.chip,
  });

  final String? assetPath;
  final IconData fallbackIcon;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isLocked = fallbackIcon == Icons.lock_rounded;
    final corners = BorderRadius.circular(radius);
    final icon = Icon(fallbackIcon, color: Colors.white, size: size * 0.45);
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLocked
              ? const [AppColors.textMuted, AppColors.textSecondary]
              : AppColors.chapterGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: isLocked
          ? Image.asset(
              'assets/illustrations/locked_chapter.webp',
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => Center(child: icon),
            )
          : Center(child: icon),
    );
    return ClipRRect(
      borderRadius: corners,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: corners,
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: assetPath == null
              ? fallback
              : Image.asset(
                  assetPath!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => fallback,
                ),
        ),
      ),
    );
  }
}
