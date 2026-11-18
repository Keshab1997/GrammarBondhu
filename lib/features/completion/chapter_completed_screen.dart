import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/accessible_layout.dart';
import '../../core/widgets/app_widgets.dart';
import '../chapters/chapter_detail_screen.dart';
import '../home/home_shell.dart';

/// Navigation arguments for the reward screen.
class CompletedArgs {
  const CompletedArgs({
    required this.chapterId,
    required this.result,
    this.correct = 0,
    this.total = 0,
  });

  final String chapterId;
  final QuizRunResult result;

  /// Exact first-attempt counts from this run. Older callers without counts
  /// omit the accuracy pill rather than reverse-engineering a rounded percent.
  final int correct;
  final int total;
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
    final supportLanguage =
        Provider.of<SettingsController?>(context)?.supportLanguage ?? 'en';
    final subtitle = switch (supportLanguage) {
      'bn' => 'দারুণ কাজ! আরও এগিয়ে চলো।',
      'hi' => 'शानदार काम! ऐसे ही आगे बढ़ते रहो।',
      _ => null,
    };
    final result = args.result;
    final next = content.nextAfter(args.chapterId);

    void finish() {
      Navigator.of(context)
          .pushNamedAndRemoveUntil(HomeShell.routeName, (_) => false);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.card),
                boxShadow: AppShadows.card,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _CelebrationHero(stars: result.stars, onClose: finish),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(children: [
                      Text('Chapter Completed!',
                          textAlign: TextAlign.center,
                          style: text.titleMedium
                              ?.copyWith(color: AppColors.primaryDark)),
                      const SizedBox(height: AppSpacing.xs),
                      Semantics(
                          header: true,
                          child: Text(
                            result.percent >= 90
                                ? 'You did an amazing job!'
                                : 'You did a great job!',
                            textAlign: TextAlign.center,
                            style: text.headlineMedium
                                ?.copyWith(color: AppColors.textPrimary),
                          )),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(subtitle,
                            textAlign: TextAlign.center,
                            style: text.bodyLarge
                                ?.copyWith(color: AppColors.primaryDark)),
                      ],
                      if (args.total > 0) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: const ShapeDecoration(
                              color: AppColors.primarySoft,
                              shape: StadiumBorder(
                                  side: BorderSide(
                                      color: AppColors.primaryGlow))),
                          child: Text('${args.correct}/${args.total} correct',
                              textAlign: TextAlign.center,
                              style: text.bodyMedium?.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: AppSpacing.sm,
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
                        Text('Score ${result.percent}% — personal best!',
                            textAlign: TextAlign.center,
                            style: text.bodyMedium
                                ?.copyWith(color: AppColors.textPrimary)),
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
                            onPressed: finish),
                      const SizedBox(height: AppSpacing.xs),
                      TextButton(
                        onPressed: finish,
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            minimumSize: const Size.square(
                                AccessibleLayout.minTouchTarget),
                            visualDensity: VisualDensity.standard),
                        child: const Text('Finish for now',
                            textAlign: TextAlign.center),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Frame Rahul independently of the text: large type can make the summary
/// taller without ever covering his face or requiring a wash over the art.
class _CelebrationHero extends StatelessWidget {
  const _CelebrationHero({required this.stars, required this.onClose});

  final int stars;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.35,
      child: Stack(fit: StackFit.expand, children: [
        Image.asset(
          'assets/illustrations/chapter_completed.webp',
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.15),
          filterQuality: FilterQuality.high,
          excludeFromSemantics: true,
          errorBuilder: (_, __, ___) => const DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppColors.skyGradient))),
        ),
        Positioned(
            left: AppSpacing.sm,
            top: AppSpacing.sm,
            child: IconButton(
              tooltip: 'Close',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
              style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  minimumSize:
                      const Size.square(AccessibleLayout.minTouchTarget),
                  visualDensity: VisualDensity.standard),
            )),
        Positioned(
            bottom: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Semantics(
              label: '$stars of 3 stars',
              excludeSemantics: true,
              child: DecoratedBox(
                decoration: const ShapeDecoration(
                    color: AppColors.primaryDeeper, shape: StadiumBorder()),
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: StarsDisplay(count: stars, size: 28)),
              ),
            )),
      ]),
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
        color: AppColors.accentSoft,
        border: Border.all(color: AppColors.accentDark),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.accentDeep),
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
