import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// The GrammarBondhu wordmark used on splash, login and rewards screens.
///
/// Richer 3D feel: multi-layered shadows, tiny grad-cap glyph, playful
/// color split between "Grammar" (deep blue) and "Bondhu" (gold).
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.fontSize = 40,
    this.showTagline = true,
    this.compact = false,
  });

  final double fontSize;
  final bool showTagline;

  /// One-line lockup for the splash screen: badge, then "Grammar Bondhu"
  /// side by side and the tagline in a pill. The stacked lockup is ~190 dp
  /// tall and lands on the hero character's head; this one is ~125 dp, so
  /// it stays in the sky band of the splash artwork.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Graduation cap icon with gold tassel and subtle glow.
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: fontSize * 1.3,
              height: fontSize * 1.3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: fontSize * 0.6,
                    offset: Offset(0, fontSize * 0.2),
                  ),
                ],
              ),
              child: Icon(
                Icons.school_rounded,
                size: fontSize * 0.75,
                color: Colors.white,
              ),
            ),
            // Tiny gold sparkle top-right.
            Positioned(
              top: -fontSize * 0.05,
              right: -fontSize * 0.05,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: fontSize * 0.32,
                color: AppColors.accent,
                shadows: [
                  Shadow(
                    color: AppColors.accentDark,
                    blurRadius: 6,
                  )
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: fontSize * 0.22),
        // Grammar (deep blue, bold).
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [AppColors.primaryDeeper, AppColors.primary],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(b),
          child: Text(
            'Grammar',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.4,
              height: 1.0,
              shadows: const [
                Shadow(
                    color: Color(0x44000000),
                    offset: Offset(0, 3),
                    blurRadius: 8),
              ],
            ),
          ),
        ),
        // Bondhu (gold, playful).
        Transform.translate(
          offset: Offset(0, -fontSize * 0.08),
          child: Stack(
            children: [
              // Dark outline stroke.
              Text(
                'Bondhu',
                style: TextStyle(
                  fontSize: fontSize * 1.2,
                  fontWeight: FontWeight.w900,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = fontSize * 0.05
                    ..color = AppColors.accentDeep,
                  letterSpacing: 1.2,
                  height: 1.0,
                ),
              ),
              // Gold fill on top.
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [
                    AppColors.goldTop,
                    AppColors.accent,
                    AppColors.accentDark
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(b),
                child: Text(
                  'Bondhu',
                  style: TextStyle(
                    fontSize: fontSize * 1.2,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                    height: 1.0,
                    shadows: const [
                      Shadow(
                          color: Color(0x66000000),
                          offset: Offset(0, 4),
                          blurRadius: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showTagline)
          Padding(
            padding: EdgeInsets.only(top: fontSize * 0.05),
            child: Text(
              'Learn English Through Stories',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize * 0.34,
                fontWeight: FontWeight.w700,
                color: AppColors.textOnDark.withValues(alpha: 0.95),
                letterSpacing: 0.6,
                shadows: const [
                  Shadow(
                    color: Color(0x66000000),
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    final badgeSize = fontSize * 1.25;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Small cap badge.
        Container(
          width: badgeSize,
          height: badgeSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.85), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: fontSize * 0.5,
                offset: Offset(0, fontSize * 0.16),
              ),
            ],
          ),
          child: Icon(
            Icons.school_rounded,
            size: fontSize * 0.62,
            color: Colors.white,
          ),
        ),
        SizedBox(height: fontSize * 0.28),
        // One-line wordmark: Grammar (blue, white halo) + Bondhu (gold).
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // White outline first: deep-blue 'Grammar' on a blue sky is
            // unreadable without it. Mirrors the Bondhu sticker below.
            Stack(
              children: [
                Text(
                  'Grammar',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = fontSize * 0.16
                      ..strokeJoin = StrokeJoin.round
                      ..color = Colors.white,
                    letterSpacing: 0.3,
                    height: 1.0,
                  ),
                ),
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [AppColors.primaryDeeper, AppColors.primary],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(b),
                  child: Text(
                    'Grammar',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.3,
                      height: 1.0,
                      shadows: const [
                        Shadow(
                            color: Color(0x55000000),
                            offset: Offset(0, 3),
                            blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: fontSize * 0.22),
            // Bondhu (gold fill over a dark stroke, as in the stacked logo).
            Stack(
              children: [
                Text(
                  'Bondhu',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = fontSize * 0.045
                      ..strokeJoin = StrokeJoin.round
                      ..color = AppColors.accentDeep,
                    letterSpacing: 0.6,
                    height: 1.0,
                  ),
                ),
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [
                      AppColors.goldTop,
                      AppColors.accent,
                      AppColors.accentDark
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(b),
                  child: Text(
                    'Bondhu',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.6,
                      height: 1.0,
                      shadows: const [
                        Shadow(
                            color: Color(0x66000000),
                            offset: Offset(0, 3),
                            blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (showTagline) ...[
          SizedBox(height: fontSize * 0.3),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: fontSize * 0.34,
              vertical: fontSize * 0.13,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            ),
            child: Text(
              'LEARN ENGLISH THROUGH STORIES',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize * 0.27,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.5,
                height: 1.0,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
