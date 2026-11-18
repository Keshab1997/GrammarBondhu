import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../chapters/chapter_detail_screen.dart';
import '../home/home_shell.dart';

/// Navigation arguments for the reward screen.
class CompletedArgs {
  const CompletedArgs({required this.chapterId, required this.result});

  final String chapterId;
  final QuizRunResult result;
}

/// Screen 13 — stars, XP, coins, "Next Chapter".
/// Uses the celebratory illustration matching storyboard frame 13.
class ChapterCompletedScreen extends StatelessWidget {
  const ChapterCompletedScreen({super.key, required this.args});

  static const routeName = '/completed';

  final CompletedArgs args;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final content = context.watch<ContentController>();
    final result = args.result;
    final next = content.nextAfter(args.chapterId);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Celebratory hero background (confetti, stars, cheering Rahul).
          Image.asset(
            'assets/illustrations/chapter_completed.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.skyTop,
                    AppColors.skyBottom
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Blue tint overlay for text legibility.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x661B5FC1),
                  Color(0x992F80ED),
                  Color(0x6656CCF2)
                ],
              ),
            ),
          ),
          SafeArea(
            child: _CelebrationLayout(
              header: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: () =>
                          Navigator.of(context).pushNamedAndRemoveUntil(
                        HomeShell.routeName,
                        (_) => false,
                      ),
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ),
                  Text(
                    'Chapter Completed!',
                    textAlign: TextAlign.center,
                    style: text.headlineMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  StarsDisplay(count: result.stars, size: 52),
                ],
              ),
              summary: Column(
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    result.percent >= 90
                        ? 'You did an amazing job!'
                        : 'You did a great job!',
                    textAlign: TextAlign.center,
                    style: text.headlineMedium
                        ?.copyWith(color: Colors.white, fontSize: 28),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _RewardChip(
                          icon: Icons.star_rounded,
                          label: '+${result.xpEarned} XP'),
                      _RewardChip(
                          icon: Icons.monetization_on_rounded,
                          label: '+${result.coinsEarned} Coins'),
                    ],
                  ),
                  if (result.isPersonalBest) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(AppRadii.chip),
                      ),
                      child: Text(
                        'Score ${result.percent}% — personal best!',
                        style: text.bodyMedium?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (next != null)
                    AppButton(
                      label: 'Next Chapter',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () =>
                          Navigator.of(context).pushNamedAndRemoveUntil(
                        ChapterDetailScreen.routeName,
                        (route) => route.isFirst,
                        arguments: next.id,
                      ),
                    )
                  else
                    AppButton(
                      label: 'Back to Home',
                      icon: Icons.home_rounded,
                      onPressed: () =>
                          Navigator.of(context).pushNamedAndRemoveUntil(
                        HomeShell.routeName,
                        (_) => false,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamedAndRemoveUntil(
                      HomeShell.routeName,
                      (_) => false,
                    ),
                    child: const Text('Finish for now',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keep the celebration at the foot of a tall screen, but let it scroll
/// below the stars when larger text needs more than a screenful.
class _CelebrationLayout extends StatelessWidget {
  const _CelebrationLayout({required this.header, required this.summary});

  final Widget header;
  final Widget summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: viewport.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [header, summary],
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppColors.rewardGradient),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
