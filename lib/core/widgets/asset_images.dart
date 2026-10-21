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
  });

  final String characterId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = AssetLookup.characterPath(characterId);
    final name = AssetLookup.characterDisplayName(characterId);
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: path == null
            ? _FallbackAvatar(name: name, size: size)
            : Image.asset(
                path,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _FallbackAvatar(name: name, size: size),
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
    final fallback = isLocked
        ? ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFB8B8D1), Color(0xFF7E7EA0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: 0.9,
                    child: Image.asset(
                      'assets/illustrations/locked_chapter.webp',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(fallbackIcon,
                            color: Colors.white, size: size * 0.45),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.chapterGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(radius),
            ),
            child: Icon(fallbackIcon, color: Colors.white, size: size * 0.45),
          );
    if (assetPath == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          assetPath!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}
