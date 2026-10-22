import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens for GrammarBondhu — polished, modern, kid-friendly.
///
/// Softer color palette, subtle shadow system, generous rounding and
/// multi-stop gradients that match the 3D storyboard illustrations.
class AppColors {
  const AppColors._();

  // Primary blues (slightly deeper, more premium than before).
  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1E40AF);
  static const primaryDeeper = Color(0xFF1E3A8A);
  static const primarySoft = Color(0xFFEFF6FF);
  static const primaryGlow = Color(0xFF93C5FD);

  // Warm gold/yellow accent (CTAs, rewards, stars).
  static const accent = Color(0xFFFFC83C);
  static const accentDark = Color(0xFFF59E0B);
  static const accentDeep = Color(0xFFD97706);
  static const accentSoft = Color(0xFFFFF4D6);

  // Semantic.
  static const success = Color(0xFF10B981);
  static const successDark = Color(0xFF059669);
  static const successSoft = Color(0xFFD1FAE5);
  static const error = Color(0xFFEF4444);
  static const errorSoft = Color(0xFFFEE2E2);
  static const warning = Color(0xFFF97316);
  static const info = Color(0xFF06B6D4);

  // Surfaces.
  static const background = Color(0xFFF1F5FB);
  static const backgroundAlt = Color(0xFFE8F0FE);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceGlass = Color(0xCCFFFFFF);

  // Text.
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const textOnDark = Color(0xFFFFFFFF);

  // Gradient stops.
  static const skyTop = Color(0xFF60A5FA);
  static const skyBottom = Color(0xFFBAE6FD);
  static const nightTop = Color(0xFF1E3A8A);
  static const nightBottom = Color(0xFF3B82F6);
  static const goldTop = Color(0xFFFFE082);
  static const goldBottom = Color(0xFFFFA726);
  static const purpleTop = Color(0xFF8B5CF6);
  static const purpleBottom = Color(0xFFEC4899);

  // Ready-made gradients.
  static const primaryGradient = [primaryDark, primary, Color(0xFF38BDF8)];
  static const chapterGradient = [Color(0xFF2563EB), Color(0xFF38BDF8)];
  static const rewardGradient = [Color(0xFFFFD54F), Color(0xFFFF9800)];
  static const successGradient = [Color(0xFF10B981), Color(0xFF34D399)];
  static const skyGradient = [
    Color(0xFF60A5FA),
    Color(0xFFBAE6FD),
    Colors.white
  ];
  static const cardGradient = [Colors.white, Color(0xFFF8FAFC)];
}

/// Pre-built soft shadow sets used by cards, buttons and hero images.
class AppShadows {
  const AppShadows._();

  static List<BoxShadow> get card => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get cardSoft => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.06),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get button => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get buttonYellow => [
        BoxShadow(
          color: AppColors.accentDark.withValues(alpha: 0.45),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get buttonSuccess => [
        BoxShadow(
          color: AppColors.success.withValues(alpha: 0.40),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get hero => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 30,
          offset: const Offset(0, 14),
        ),
      ];
}

/// Font families declared in `pubspec.yaml`.
///
/// The display face is bundled rather than taken from the platform, and the two
/// Noto families are the *fallback* for every string in the app: a phone with no
/// Bengali system font would otherwise paint Bangla as tofu boxes.
class AppFonts {
  const AppFonts._();

  static const display = 'Baloo2';
  static const bengali = 'NotoSansBengali';
  static const devanagari = 'NotoSansDevanagari';

  /// Latin first (the body face), then the scripts the app actually teaches.
  static const fallback = <String>[bengali, devanagari];
}

class AppRadii {
  const AppRadii._();

  static const xs = 8.0;
  static const sm = 12.0;
  static const card = 22.0;
  static const button = 16.0;
  static const chip = 14.0;
  static const sheet = 32.0;
  static const avatar = 28.0;
}

class AppSpacing {
  const AppSpacing._();

  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 44.0;
}

/// Base theme: modern, colorful, rounded, with subtle depth.
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
    // No explicit font family: an unlisted family name ('Roboto' here) is not in
    // the asset FontManifest, so the engine falls back to the serif default and
    // the whole app renders in a serif face. Leaving it unset uses the platform
    // default, which is already Roboto on Android.
    splashFactory: InkSparkle.splashFactory,
  );

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  final textTheme = base.textTheme.copyWith(
    // Headings get the rounded display face: one change that lifts every screen
    // at once, and it is friendly without being childish.
    displaySmall: base.textTheme.displaySmall?.copyWith(
      color: AppColors.textPrimary,
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      color: AppColors.textPrimary,
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    headlineSmall: base.textTheme.headlineSmall?.copyWith(
      color: AppColors.textPrimary,
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      color: AppColors.textPrimary,
      fontFamily: AppFonts.display,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.1,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    ),
    titleSmall: base.textTheme.titleSmall?.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    ),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    ),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      color: AppColors.textOnDark,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
    ),
  );

  final scriptSafeTheme = textTheme.apply(
    fontFamilyFallback: AppFonts.fallback,
  );

  return base.copyWith(
    textTheme: scriptSafeTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: scriptSafeTheme.titleLarge,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnDark,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        textStyle: scriptSafeTheme.labelLarge,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.primary, width: 1.8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        textStyle:
            scriptSafeTheme.labelLarge?.copyWith(color: AppColors.primary),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle:
            scriptSafeTheme.labelLarge?.copyWith(color: AppColors.primary),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      prefixIconColor: AppColors.textMuted,
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
      elevation: 8,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
      linearTrackColor: AppColors.primarySoft,
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE2E8F0),
      thickness: 1,
      space: AppSpacing.md,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showUnselectedLabels: true,
    ),
  );
}
