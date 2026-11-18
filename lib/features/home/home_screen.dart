import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/accessible_layout.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/chapter.dart';
import '../chapters/chapter_list_screen.dart';
import '../grammar/grammar_lesson_screen.dart';
import '../progress/progress_screen.dart';
import '../quiz/quiz_screen.dart';
import '../quiz/review_practice_screen.dart';
import '../settings/settings_screen.dart';
import '../story/story_screen.dart';

/// Screen 6 — continue journey, quick actions, progress, daily goal.
///
/// The dashboard lets the greeting, chapter metadata, and counters wrap
/// instead of cutting off learner-facing text at larger system sizes.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentController>();
    final progress = context.watch<ProgressController>();
    final settings = context.watch<SettingsController>();

    final chapters = content.chapters;
    final currentId = progress.recommendedChapterId(chapters);
    final current = content.byId(currentId);
    final completedChapters = chapters
        .where((chapter) => progress.chapterProgress(chapter.id).completed)
        .length;
    final allChaptersComplete =
        chapters.isNotEmpty && completedChapters == chapters.length;
    final reviewCount = countReviewableMistakes(chapters, progress.progress);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, 108),
        children: [
          _Header(name: settings.greetingName),
          const SizedBox(height: AppSpacing.md),
          if (allChaptersComplete)
            _CourseCompleteCard(totalChapters: chapters.length)
          else if (current != null)
            _ContinueCard(
              chapter: current,
              number: chapters.indexOf(current) + 1,
              supportLanguage: settings.supportLanguage,
            ),
          const SizedBox(height: AppSpacing.md),
          _QuickActions(current: current),
          const SizedBox(height: AppSpacing.md),
          if (current != null)
            _ProgressCard(
              chapter: current,
              completedChapters: completedChapters,
              totalChapters: chapters.length,
            ),
          const SizedBox(height: AppSpacing.sm + 4),
          _DailyGoalCard(
            done: progress.progress.questionsAnsweredOn(now ?? DateTime.now()),
            target: progress.progress.dailyGoalQuestions,
          ),
          if (reviewCount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            _ReviewMistakesCard(reviewCount: reviewCount),
          ],
        ],
      ),
    );
  }
}

/// Greeting, avatar and the coins/settings toolbar.
///
/// Drop the toolbar below the greeting at larger system text sizes.
class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final coins = context.watch<ProgressController>().progress.coins;
    final reflow = AccessibleLayout.needsReflow(context);
    final toolbar = _HeaderToolbar(coins: coins);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ClipOval(
                child: SizedBox.square(
                  dimension: 46,
                  child: Image.asset(
                    'assets/illustrations/progress_avatar.webp',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    excludeFromSemantics: true,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: AppColors.primaryDark,
                      child: Icon(Icons.person_rounded,
                          color: AppColors.textOnDark, size: 24),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello, $name!', style: text.titleLarge),
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      const Icon(Icons.favorite_rounded,
                          size: 13, color: AppColors.error),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text("You're doing great!",
                            style: text.bodySmall
                                ?.copyWith(color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!reflow) ...[
              const SizedBox(width: AppSpacing.sm),
              toolbar,
            ],
          ],
        ),
        if (reflow) ...[
          const SizedBox(height: AppSpacing.sm),
          toolbar,
        ],
      ],
    );
  }
}

/// Keep the counter compact without shrinking the settings hit area.
class _HeaderToolbar extends StatelessWidget {
  const _HeaderToolbar({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.chip + 4),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 104),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(AppRadii.chip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on_rounded,
                      size: 16, color: AppColors.accentDeep),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      '$coins',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Settings',
              visualDensity: VisualDensity.standard,
              constraints: const BoxConstraints(
                minWidth: AccessibleLayout.minTouchTarget,
                minHeight: AccessibleLayout.minTouchTarget,
              ),
              icon: const Icon(Icons.settings_outlined,
                  size: 21, color: AppColors.textSecondary),
              onPressed: () =>
                  Navigator.of(context).pushNamed(SettingsScreen.routeName),
            ),
          ],
        ),
      ),
    );
  }
}

/// Course-finished state: celebrate completion and offer a clear replay path.
class _CourseCompleteCard extends StatelessWidget {
  const _CourseCompleteCard({required this.totalChapters});

  final int totalChapters;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.primaryDeeper,
            AppColors.primaryDark,
            AppColors.primary
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.card + 2),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded,
                  color: AppColors.accent, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Course complete!',
                  style:
                      text.headlineSmall?.copyWith(color: AppColors.textOnDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'You finished all $totalChapters chapters. Celebrate your progress '
            'or revisit a story to practise again.',
            style: text.bodyMedium?.copyWith(color: AppColors.textOnDark),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Review chapters',
            icon: Icons.replay_rounded,
            variant: AppButtonVariant.primary,
            onPressed: () =>
                Navigator.of(context).pushNamed(ChapterListScreen.routeName),
          ),
        ],
      ),
    );
  }
}

/// Blue hero card: the next chapter, its artwork and one full-width CTA.
///
/// The CTA spans the card instead of sitting under the text: at 320 dp the
/// left column is too narrow for a button *and* a thumbnail, and the old
/// arrangement left a dead corner under the title.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.chapter,
    required this.number,
    required this.supportLanguage,
  });

  final Chapter chapter;
  final int number;
  final String supportLanguage;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final progress = context.watch<ProgressController>();
    final record = progress.chapterProgress(chapter.id);
    final steps = chapter.scenes.length + 1;
    final resume =
        (record.resumeSceneIndex ?? 0).clamp(0, chapter.scenes.length);

    final reflow = AccessibleLayout.needsReflow(context);
    final topic = chapter.grammarTopic.en;
    final localizedTopic = chapter.grammarTopic.of(supportLanguage);
    final secondary = text.bodySmall?.copyWith(
      color: AppColors.textOnDark.withValues(alpha: 0.94),
      fontWeight: FontWeight.w600,
    );
    final topicLabels = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: AppColors.primaryDeeper.withValues(alpha: 0.36),
            borderRadius: BorderRadius.circular(AppRadii.chip),
            border:
                Border.all(color: AppColors.textOnDark.withValues(alpha: 0.24)),
          ),
          child: Text(topic, style: secondary),
        ),
        if (supportLanguage != 'en' && localizedTopic != topic) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(localizedTopic, style: secondary),
        ],
      ],
    );

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.primaryDeeper,
            AppColors.primaryDark,
            AppColors.primary
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.card + 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.card + 2),
        child: Stack(
          children: [
            const Positioned(
              top: -46,
              right: -30,
              child: _Bloom(size: 150, opacity: 0.08),
            ),
            const Positioned(
              bottom: -60,
              left: -28,
              child: _Bloom(size: 130, opacity: 0.05),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm + 2,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        record.started
                            ? 'Continue Your Journey'
                            : 'Start Your Journey',
                        style: text.labelLarge?.copyWith(
                            color: AppColors.accentSoft,
                            fontWeight: FontWeight.w800),
                      ),
                      Text('Chapter $number', style: secondary),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chapter.title.en,
                              style: text.headlineSmall?.copyWith(
                                color: AppColors.textOnDark,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            if (!reflow) ...[
                              const SizedBox(height: AppSpacing.sm),
                              topicLabels,
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm + 4),
                      _JourneyArtwork(
                        assetPath: chapter.thumbnailAsset,
                        size: reflow ? 76 : 100,
                      ),
                    ],
                  ),
                  if (reflow) ...[
                    const SizedBox(height: AppSpacing.sm),
                    topicLabels,
                  ],
                  const SizedBox(height: AppSpacing.sm + 2),
                  Row(
                    children: [
                      Icon(
                        record.started
                            ? Icons.play_circle_outline_rounded
                            : Icons.list_alt_rounded,
                        size: 16,
                        color: AppColors.accentSoft,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          record.started
                              ? 'Step ${resume + 1} of $steps'
                              : '$steps steps · story + quiz',
                          style: secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: record.started ? 'Continue' : 'Start',
                    icon: Icons.play_arrow_rounded,
                    onPressed: () {
                      final navigator = Navigator.of(context);
                      // The final step is after the story, not a scene index.
                      if (resume == chapter.scenes.length) {
                        navigator.pushNamed(GrammarLessonScreen.routeName,
                            arguments: chapter.id);
                      } else {
                        navigator.pushNamed(
                          StoryScreen.routeName,
                          arguments: StoryArgs(chapter.id, startScene: resume),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyArtwork extends StatelessWidget {
  const _JourneyArtwork({required this.assetPath, required this.size});

  final String? assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: AppColors.primarySoft,
      child: Center(
          child: Icon(Icons.auto_stories_rounded,
              color: AppColors.primaryDark, size: 32)),
    );
    final path = assetPath;
    final radius = BorderRadius.circular(AppRadii.card - 2);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.32),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border:
            Border.all(color: AppColors.primaryGlow.withValues(alpha: 0.55)),
      ),
      child: path == null
          ? fallback
          : Image.asset(path,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => fallback),
    );
  }
}

class _Bloom extends StatelessWidget {
  const _Bloom({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.textOnDark.withValues(alpha: opacity),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.current});

  final Chapter? current;

  @override
  Widget build(BuildContext context) {
    final chapter = current;
    final actions = [
      _QuickAction(
        icon: Icons.menu_book_rounded,
        label: 'Chapters',
        caption: 'Stories',
        color: AppColors.primaryDark,
        onTap: () =>
            Navigator.of(context).pushNamed(ChapterListScreen.routeName),
      ),
      _QuickAction(
        icon: Icons.school_rounded,
        label: 'Grammar',
        caption: 'Lessons',
        color: AppColors.successDark,
        onTap: chapter == null
            ? null
            : () => Navigator.of(context).pushNamed(
                GrammarLessonScreen.routeName,
                arguments: chapter.id),
      ),
      _QuickAction(
        icon: Icons.quiz_rounded,
        label: 'Quiz',
        caption: 'Practise',
        color: AppColors.accentDeep,
        onTap: chapter == null
            ? null
            : () => Navigator.of(context)
                .pushNamed(QuizScreen.routeName, arguments: chapter.id),
      ),
      _QuickAction(
        icon: Icons.insights_rounded,
        label: 'Progress',
        caption: 'Track',
        color: AppColors.primaryDeeper,
        onTap: () => Navigator.of(context).pushNamed(ProgressScreen.routeName),
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final columns = AccessibleLayout.isCompact(context) ? 2 : 4;
      final width =
          (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final action in actions)
            SizedBox(width: width, child: _ActionChip(action: action)),
        ],
      );
    });
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.caption,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String caption;
  final Color color;
  final VoidCallback? onTap;
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final disabled = action.onTap == null;
    final color = disabled ? AppColors.textSecondary : action.color;
    final tint = disabled
        ? AppColors.background
        : Color.lerp(AppColors.surface, color, 0.1)!;
    final radius = BorderRadius.circular(AppRadii.sm);
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: !disabled,
      label: action.label,
      hint: action.caption,
      onTap: action.onTap,
      child: Material(
        color: disabled
            ? Color.lerp(AppColors.surface, AppColors.backgroundAlt, 0.35)!
            : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: color.withValues(alpha: 0.16)),
        ),
        child: InkWell(
          onTap: action.onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AccessibleLayout.minTouchTarget,
              minWidth: AccessibleLayout.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
              child: Column(
                children: [
                  _DashboardBadge(icon: action.icon, tint: tint, color: color),
                  const SizedBox(height: AppSpacing.xs),
                  Text(action.label,
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chapter progress: what is in flight, how far along it is.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.chapter,
    required this.completedChapters,
    required this.totalChapters,
  });

  final Chapter chapter;
  final int completedChapters;
  final int totalChapters;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final record =
        context.watch<ProgressController>().chapterProgress(chapter.id);
    final step = (record.resumeSceneIndex ?? 0).clamp(0, chapter.scenes.length);
    final steps = chapter.scenes.length + 1;
    // The bar and its label count chapters. Keep any resume step separate so
    // a learner doesn't mistake it for part of the course completion tally.
    final value = totalChapters == 0 ? 0.0 : completedChapters / totalChapters;
    final percent = (value * 100).round();
    return _DashboardFrame(
      outline: AppColors.primary.withValues(alpha: 0.16),
      child: AppCard(
        onTap: () => Navigator.of(context).pushNamed(ProgressScreen.routeName),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashboardCardHeading(
              icon: Icons.trending_up_rounded,
              tint: AppColors.primarySoft,
              color: AppColors.primaryDark,
              title: 'Your Course',
              caption: completedChapters >= totalChapters && totalChapters > 0
                  ? 'Every chapter complete!'
                  : '$percent% complete',
              metric: _MetricPill(
                value: '$completedChapters/$totalChapters',
                tint: AppColors.primarySoft,
                color: AppColors.primaryDark,
                showChevron: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            Semantics(
              label: 'Course completion',
              value: '$percent%',
              child: AppProgressBar(value: value, height: 10),
            ),
            if (step > 0 && completedChapters < totalChapters) ...[
              const SizedBox(height: AppSpacing.xs + 2),
              Text('Current chapter · Step ${step + 1} of $steps',
                  style:
                      text.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Warm daily-goal card with a full-width bar so the target reads at a glance.
class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({required this.done, required this.target});

  final int done;
  final int target;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pct = target == 0 ? 0.0 : (done / target).clamp(0.0, 1.0);
    final remaining = (target - done).clamp(0, target);

    final complete = remaining == 0;
    return _DashboardFrame(
      outline: complete
          ? AppColors.accent.withValues(alpha: 0.72)
          : AppColors.accentDeep.withValues(alpha: 0.16),
      width: complete ? 1.5 : 1,
      child: AppCard(
        gradient: const LinearGradient(
          colors: [AppColors.surface, AppColors.accentSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        elevation: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DashboardCardHeading(
              icon: complete ? Icons.check_rounded : Icons.flag_rounded,
              tint: complete ? AppColors.successSoft : AppColors.accentSoft,
              color: complete ? AppColors.successDark : AppColors.accentDeep,
              title: 'Daily Goal',
              caption: 'Complete $target quiz questions today',
              metric: _MetricPill(
                  value: '$done/$target',
                  tint: AppColors.accentSoft,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            AppProgressBar(
              value: pct,
              height: 10,
              color: complete ? AppColors.successDark : AppColors.accentDeep,
              trackColor: AppColors.surface,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              complete
                  ? 'Goal complete — nicely done!'
                  : '$remaining more to reach today\'s goal',
              style: text.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: complete ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Only shown once the learner has a question to retry.
class _ReviewMistakesCard extends StatelessWidget {
  const _ReviewMistakesCard({required this.reviewCount});

  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const title = 'Review Mistakes';
    final detail =
        '$reviewCount ${reviewCount == 1 ? 'question' : 'questions'} waiting for another try';

    void practise() {
      Navigator.of(context).pushNamed(ReviewPracticeScreen.routeName);
    }

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      label: '$title. $detail',
      onTap: practise,
      child: _DashboardFrame(
        outline: AppColors.warning.withValues(alpha: 0.30),
        width: 1.5,
        child: AppCard(
          onTap: practise,
          gradient: const LinearGradient(
            colors: [AppColors.accentSoft, AppColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Row(
            children: [
              const _DashboardBadge(
                  icon: Icons.replay_rounded,
                  tint: AppColors.accentSoft,
                  color: AppColors.accentDeep),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text(detail,
                        style: text.bodyMedium
                            ?.copyWith(color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.accentDeep),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardFrame extends StatelessWidget {
  const _DashboardFrame(
      {required this.outline, this.width = 1, required this.child});

  final Color outline;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: outline, width: width),
        ),
        child: child,
      );
}

class _DashboardBadge extends StatelessWidget {
  const _DashboardBadge(
      {required this.icon, required this.tint, required this.color});

  final IconData icon;
  final Color tint;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Icon(icon, color: color, size: 22),
      );
}

class _DashboardCardHeading extends StatelessWidget {
  const _DashboardCardHeading({
    required this.icon,
    required this.tint,
    required this.color,
    required this.title,
    required this.caption,
    required this.metric,
  });

  final IconData icon;
  final Color tint;
  final Color color;
  final String title;
  final String caption;
  final Widget metric;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final heading = Row(
      children: [
        _DashboardBadge(icon: icon, tint: tint, color: color),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleMedium),
              const SizedBox(height: AppSpacing.xxs),
              Text(caption,
                  style:
                      text.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
    if (AccessibleLayout.needsReflow(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [heading, const SizedBox(height: AppSpacing.sm), metric],
      );
    }
    return Row(
      children: [
        Expanded(child: heading),
        const SizedBox(width: AppSpacing.sm),
        metric
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.value,
    required this.tint,
    required this.color,
    this.showChevron = false,
  });

  final String value;
  final Color tint;
  final Color color;
  final bool showChevron;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 104),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: tint,
          borderRadius: BorderRadius.circular(AppRadii.chip),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
                child: Text(value,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ))),
            if (showChevron)
              Icon(Icons.chevron_right_rounded, size: 16, color: color),
          ],
        ),
      );
}
