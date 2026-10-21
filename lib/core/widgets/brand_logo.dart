import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// The GrammarBondhu wordmark used on splash, login and rewards screens.
///
/// The 3D feel of the storyboard logo is approximated with layered text
/// shadows — no image asset needed, so it scales crisply on every screen.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.fontSize = 40, this.showTagline = true});

  final double fontSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.school_rounded, size: fontSize * 1.15, color: AppColors.accent),
        SizedBox(height: fontSize * 0.18),
        Text(
          'Grammar',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryDark,
            letterSpacing: 0.5,
            shadows: const [
              Shadow(color: Colors.black26, offset: Offset(0, 3), blurRadius: 6),
            ],
          ),
        ),
        Transform.translate(
          offset: Offset(0, -fontSize * 0.16),
          child: Text(
            'Bondhu',
            style: TextStyle(
              fontSize: fontSize * 1.12,
              fontWeight: FontWeight.w900,
              color: AppColors.accent,
              letterSpacing: 1,
              shadows: const [
                Shadow(color: AppColors.accentDark, offset: Offset(0, 3), blurRadius: 0),
                Shadow(color: Colors.black26, offset: Offset(0, 6), blurRadius: 8),
              ],
            ),
          ),
        ),
        if (showTagline)
          Padding(
            padding: EdgeInsets.only(top: fontSize * 0.08),
            child: Text(
              'Learn English Through Stories',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize * 0.36,
                fontWeight: FontWeight.w600,
                color: AppColors.textOnDark,
                letterSpacing: 0.4,
              ),
            ),
          ),
      ],
    );
  }
}
