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
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const routeName = '/';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Kick off content loading while the learner reads the splash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final content = context.read<ContentController>();
      if (!content.isLoaded && !content.isLoading) {
        content.load();
      }
    });
  }

  void _begin() {
    final settings = context.read<SettingsController>().settings;
    Navigator.of(context).pushReplacementNamed(
      settings.onboardingComplete ? HomeShell.routeName : OnboardingScreen.routeName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primary, AppColors.skyTop],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                const Spacer(),
                const BrandLogo(fontSize: 44),
                const Spacer(),
                const CharacterAvatar(characterId: 'rahul', size: 148),
                const Spacer(),
                AppButton(
                  label: "Let's Begin",
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _begin,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
