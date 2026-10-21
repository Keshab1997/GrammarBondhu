import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/asset_images.dart';
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
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Hero illustrated background.
          Image.asset(
            'assets/illustrations/splash_hero.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDeeper, AppColors.primary, AppColors.skyTop],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Top gradient for logo legibility.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment(0, 0.45),
                colors: [Colors.black45, Colors.transparent],
              ),
            ),
          ),
          // Bottom gradient for button legibility.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0, 0.6),
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x661B5FC1)],
              ),
            ),
          ),
          FadeTransition(
            opacity: _fade,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    SlideTransition(
                      position: _logoSlide,
                      child: const BrandLogo(fontSize: 44),
                    ),
                    const Spacer(),
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
                    const SizedBox(height: AppSpacing.md),
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
