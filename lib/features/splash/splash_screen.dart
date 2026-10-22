import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/app_widgets.dart';
import '../onboarding/onboarding_screen.dart';
import '../home/home_shell.dart';

/// Screen 1 — branding, hero character, "Let's Begin".
/// Matches storyboard frame 1: logo top, Rahul hero, golden CTA, with
/// subtle entrance animation so the logo and button glide into place.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const routeName = '/';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  late final Animation<double> _fade;
  late final Animation<Offset> _logoSlide;
  late final Animation<Offset> _btnSlide;

  @override
  void initState() {
    super.initState();
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _btnSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _ac.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final content = context.read<ContentController>();
      if (!content.isLoaded && !content.isLoading) {
        content.load();
      }
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  void _begin() {
    final settings = context.read<SettingsController>().settings;
    Navigator.of(context).pushReplacementNamed(
      settings.onboardingComplete
          ? HomeShell.routeName
          : OnboardingScreen.routeName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Single-screen fit: everything is sized off the screen height, so the
    // logo, hero and CTA always fit together with no scrolling, on short
    // and tall phones alike.
    final logoSize = (size.height * 0.042).clamp(30.0, 38.0).toDouble();
    // The artwork is 768x1376 (~0.56 aspect). On screens taller than the
    // artwork, fitWidth shows the whole scene — head to shoes — with the
    // CTA band below it; on wider screens cover fills the frame instead.
    final fit = size.aspectRatio < 0.56 ? BoxFit.fitWidth : BoxFit.cover;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Base wash behind the artwork: sky at the top, deep blue where
          // the CTA sits, so the artwork's bottom edge melts into it.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.skyTop,
                  AppColors.primary,
                  AppColors.primaryDeeper,
                ],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
          // Hero illustrated scene, pinned to the top. It is never cropped
          // over the character's head or shoes on tall phones (fitWidth),
          // and the darkening wash below hides its bottom edge.
          Image.asset(
            'assets/illustrations/splash_hero.webp',
            fit: fit,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          // Top gradient for logo legibility.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment(0, -0.1),
                colors: [Colors.black38, Colors.transparent],
              ),
            ),
          ),
          // Bottom wash: darkens the scene's lower edge into the base
          // gradient and keeps the golden CTA readable.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0, 0.35),
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0xCC1E3A8A),
                ],
              ),
            ),
          ),
          FadeTransition(
            opacity: _fade,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  children: [
                    SlideTransition(
                      position: _logoSlide,
                      // Compact one-line lockup: stays in the sky band of
                      // the artwork, clear of the hero character's head.
                      child: BrandLogo(
                        fontSize: logoSize,
                        compact: true,
                      ),
                    ),
                    const Spacer(),
                    SlideTransition(
                      position: _btnSlide,
                      child: AppButton(
                        label: "Let's Begin",
                        icon: Icons.arrow_forward_rounded,
                        variant: AppButtonVariant.primary,
                        onPressed: _begin,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
