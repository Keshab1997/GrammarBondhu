import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../auth/login_screen.dart';

/// Screens 2–4 — the three onboarding pages.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const routeName = '/onboarding';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.auto_stories_rounded,
      title: 'Welcome to GrammarBondhu!',
      body: 'A magical journey where you learn English through exciting '
          'stories, fun quizzes and real-life situations.',
    ),
    _OnboardingPage(
      icon: Icons.translate_rounded,
      title: '3 Languages,\n1 Goal',
      body: 'English is the main language.\n'
          'আপনি বাংলা বা হিন্দী ভাষায় অনুবাদ দেখতে পারবেন।\n'
          'आप हिन्दी या बांग्ला अनुवाद देख सकते हैं।',
      languageRow: true,
    ),
    _OnboardingPage(
      icon: Icons.castle_rounded,
      title: 'Explore the Story World',
      body: 'Complete missions, learn grammar and unlock new chapters.',
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      context.read<SettingsController>().completeOnboarding();
      Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.skyTop, AppColors.background],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _pages[i],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.primary : AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AppButton(
                  label: _page == _pages.length - 1 ? 'Get Started' : 'Next',
                  variant: AppButtonVariant.blue,
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    this.languageRow = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool languageRow;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 72, color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: text.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (languageRow) ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                LanguageChip(code: 'en', label: 'English', flag: '🇬🇧'),
                SizedBox(width: AppSpacing.sm),
                LanguageChip(code: 'bn', label: 'বাংলা', flag: '🇧🇩'),
                SizedBox(width: AppSpacing.sm),
                LanguageChip(code: 'hi', label: 'हिन्दी', flag: '🇮🇳'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            body,
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
