import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../auth/login_screen.dart';

/// Screens 2–4 — the three onboarding pages with rich 3D illustrations.
/// Smooth page-transform and animated dots, matching storyboard frames 2-4.
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
    _OnboardingPageData(
      image: 'assets/illustrations/onboarding_welcome.webp',
      title: 'Welcome to\nGrammarBondhu!',
      body: 'A magical journey where you learn English through exciting '
          'stories, fun quizzes and real-life situations.',
    ),
    _OnboardingPageData(
      image: 'assets/illustrations/onboarding_languages.webp',
      title: '3 Languages,\n1 Goal',
      body: 'English is the main language.\n'
          'আপনি বাংলা বা হিন্দী ভাষায় অনুবাদ দেখতে পারবেন।\n'
          'आप हिन्दी या बांग्ला अनुवाद देख सकते हैं।',
      languageRow: true,
    ),
    _OnboardingPageData(
      image: 'assets/illustrations/onboarding_story_world.webp',
      title: 'Explore the Story World',
      body: 'Complete missions, learn grammar and unlock new chapters.',
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      context.read<SettingsController>().completeOnboarding();
      Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
    }
  }

  void _skip() {
    context.read<SettingsController>().completeOnboarding();
    Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.md, top: AppSpacing.sm),
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _OnboardingPage(data: _pages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _page ? 28 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: i == _page
                            ? const LinearGradient(
                                colors: [AppColors.primary, AppColors.skyTop])
                            : null,
                        color: i == _page ? null : AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: i == _page
                            ? [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                    ),
                  const Spacer(),
                  AppButton(
                    label: _page == _pages.length - 1 ? 'Get Started' : 'Next',
                    icon: _page == _pages.length - 1
                        ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                    variant: AppButtonVariant.blue,
                    expand: false,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.image,
    required this.title,
    required this.body,
    this.languageRow = false,
  });

  final String image;
  final String title;
  final String body;
  final bool languageRow;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      data.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.skyTop,
                        child: const Center(
                          child: Icon(Icons.auto_stories_rounded,
                              size: 80, color: Colors.white),
                        ),
                      ),
                    ),
                    // Subtle bottom fade so illustration meets card gracefully.
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment(0, 0.75),
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x55FFFFFF)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: text.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                if (data.languageRow) ...[
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
                  data.body,
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(
                      height: 1.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
