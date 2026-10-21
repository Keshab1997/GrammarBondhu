import 'package:flutter/material.dart';

/// Design tokens for GrammarBondhu — extracted from the storyboard:
/// friendly blues, warm yellow CTAs, soft cards, generous rounding.
class AppColors {
  const AppColors._();

  static const primary = Color(0xFF2F80ED);
  static const primaryDark = Color(0xFF1B5FC1);
  static const primarySoft = Color(0xFFE8F1FF);

  static const accent = Color(0xFFFFC93C);
  static const accentDark = Color(0xFFE6A700);

  static const success = Color(0xFF27AE60);
  static const successSoft = Color(0xFFE4F7EC);
  static const error = Color(0xFFEB5757);
  static const errorSoft = Color(0xFFFDEBEB);

  static const background = Color(0xFFF4F7FE);
  static const surface = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF1F2A44);
  static const textSecondary = Color(0xFF5A6B8C);
  static const textOnDark = Color(0xFFFFFFFF);

  static const skyTop = Color(0xFF6EC3F7);
  static const skyBottom = Color(0xFFB7E1FF);
  static const nightTop = Color(0xFF27447E);
  static const nightBottom = Color(0xFF3E6FBF);

  static const chapterGradient = [
    Color(0xFF2F80ED),
    Color(0xFF56CCF2),
  ];
  static const rewardGradient = [
    Color(0xFFFFC93C),
    Color(0xFFFF9A3C),
  ];
}

class AppRadii {
  const AppRadii._();

  static const card = 20.0;
  static const button = 14.0;
  static const chip = 12.0;
  static const sheet = 28.0;
}

class AppSpacing {
  const AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Base theme: rounded, colorful, readable on small screens.
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      error: AppColors.error,
      surface: AppColors.surface,
    ),
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Roboto',
  );

  final textTheme = base.textTheme.copyWith(
    displaySmall: base.textTheme.displaySmall?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w800,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w800,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary),
    bodyMedium:
        base.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      color: AppColors.textOnDark,
      fontWeight: FontWeight.w700,
    ),
  );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnDark,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        textStyle: textTheme.labelLarge,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.primary, width: 1.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        textStyle: textTheme.labelLarge?.copyWith(color: AppColors.primary),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: textTheme.labelLarge?.copyWith(color: AppColors.primary),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      margin: EdgeInsets.zero,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
    ),
  );
}
