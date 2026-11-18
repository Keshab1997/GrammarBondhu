import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../home/home_shell.dart';
import '../settings/language_selection_screen.dart';

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
  bool _finishing = false;

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
          'আপনি বাংলা বা হিন্দি ভাষায় অনুবাদ দেখতে পারবেন।\n'
          'आप हिन्दी या बांग्ला अनुवाद देख सकते हैं।',
      showLanguages: true,
    ),
    _OnboardingPageData(
      image: 'assets/illustrations/onboarding_story_world.webp',
      title: 'Explore the Story World',
      body: 'Complete missions, learn grammar and unlock new chapters.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_finishing) return;
    if (_page == _pages.length - 1) {
      await _skip();
    } else {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _skip() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await context.read<SettingsController>().completeOnboarding();
    } catch (_) {
      if (mounted) {
        setState(() => _finishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Could not save your preferences. Please try again.')),
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(HomeShell.routeName);
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
                padding: const EdgeInsets.only(
                    right: AppSpacing.md, top: AppSpacing.sm),
                child: TextButton(
                  onPressed: _finishing ? null : _skip,
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
              child: OverflowBar(
                alignment: MainAxisAlignment.spaceBetween,
                overflowAlignment: OverflowBarAlignment.center,
                spacing: AppSpacing.sm,
                overflowSpacing: AppSpacing.sm,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
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
                                ? const LinearGradient(colors: [
                                    AppColors.primary,
                                    AppColors.skyTop
                                  ])
                                : null,
                            color: i == _page ? null : AppColors.primarySoft,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: i == _page
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    )
                                  ]
                                : null,
                          ),
                        ),
                    ],
                  ),
                  IntrinsicWidth(
                    child: AppButton(
                      label:
                          _page == _pages.length - 1 ? 'Get Started' : 'Next',
                      icon: _page == _pages.length - 1
                          ? Icons.rocket_launch_rounded
                          : Icons.arrow_forward_rounded,
                      variant: AppButtonVariant.blue,
                      expand: false,
                      onPressed: _finishing ? null : _next,
                    ),
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
    this.showLanguages = false,
  });

  final String image;
  final String title;
  final String body;
  final bool showLanguages;
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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: text.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                if (data.showLanguages) ...[
                  ExplanationLanguagePicker(
                    selected:
                        context.watch<SettingsController>().supportLanguage,
                    onChanged: (code) => context
                        .read<SettingsController>()
                        .setSupportLanguage(code),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(
                  data.body,
                  textAlign: TextAlign.center,
                  style: text.bodyLarge
                      ?.copyWith(height: 1.5, color: AppColors.textSecondary),
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
