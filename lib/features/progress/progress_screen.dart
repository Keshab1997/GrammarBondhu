import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/accessible_layout.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/chapter.dart';
import '../../data/models/progress.dart';
import '../quiz/quiz_screen.dart';
import '../quiz/review_practice_screen.dart';

/// Screen 14 — overview, per-chapter history and stats.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, this.now, this.initialTab = 0});

  static const routeName = '/progress';

  final DateTime? now;
  final int initialTab;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  static const _tabLabels = ['Overview', 'Chapters', 'Stats', 'Review'];

  late int _tab = widget.initialTab.clamp(0, _tabLabels.length - 1);

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentController>();
    final progress = context.watch<ProgressController>();
    final language = context.watch<SettingsController>().supportLanguage;
    final p = progress.progress;
    final now = (widget.now ?? DateTime.now()).toLocal();
    final activeStreak = p.activeStreakOn(now);
    final chapters = content.chapters;
    final completed =
        chapters.where((c) => p.chapters[c.id]?.completed ?? false).length;
    final reviewCount = countReviewableMistakes(chapters, p);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          visualDensity: VisualDensity.standard,
          constraints: const BoxConstraints(
            minHeight: AccessibleLayout.minTouchTarget,
            minWidth: AccessibleLayout.minTouchTarget,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('My Progress'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
              child: _ProgressTabs(
                labels: _tabLabels,
                selected: _tab,
                onSelect: (tab) => setState(() => _tab = tab),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, 108),
                children: [
                  if (_tab == 0) ...[
                    _LevelCard(
                      level: p.level,
                      title: p.levelTitle,
                      xpIntoLevel: p.xpIntoLevel,
                      xpPerLevel: UserProgress.xpPerLevel,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // Cards grow independently so long labels can wrap.
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final tileWidth =
                            (constraints.maxWidth - AppSpacing.md) / 2;
                        return Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: [
                            _StatTile(
                              icon: Icons.menu_book_rounded,
                              color: AppColors.primary,
                              label: 'Chapters',
                              value: '$completed/${chapters.length}',
                            ),
                            _StatTile(
                              icon: Icons.quiz_rounded,
                              color: AppColors.success,
                              label: 'Quizzes Finished',
                              value: '${p.totalQuizAnswered}',
                            ),
                            _StatTile(
                              icon: Icons.local_fire_department_rounded,
                              color: AppColors.accentDark,
                              label: 'Streak',
                              value:
                                  '$activeStreak ${activeStreak == 1 ? 'day' : 'days'}',
                            ),
                            _StatTile(
                              icon: Icons.military_tech_rounded,
                              color: AppColors.primaryDark,
                              label: 'Total Points',
                              value: '${p.totalXp}',
                            ),
                          ]
                              .map((tile) =>
                                  SizedBox(width: tileWidth, child: tile))
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _StreakStrip(
                      streakDays: activeStreak,
                      today: now,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ChapterXpCard(
                      chapters: [
                        for (final chapter in chapters)
                          (
                            title: chapter.title.en,
                            xp: p.chapters[chapter.id]?.xpEarned ?? 0
                          ),
                      ],
                    ),
                  ] else if (_tab == 1) ...[
                    for (final chapter in chapters)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _ChapterProgressCard(
                          chapter: chapter,
                          record: p.chapters[chapter.id],
                        ),
                      ),
                  ] else if (_tab == 3) ...[
                    if (reviewCount == 0)
                      const _EmptyReviewCard()
                    else ...[
                      _PracticeCallout(count: reviewCount),
                      const SizedBox(height: AppSpacing.md),
                      for (final chapter in chapters)
                        _MistakeReviewCard(
                          chapter: chapter,
                          missedIds:
                              p.chapters[chapter.id]?.missedQuestionIds ??
                                  const {},
                          language: language,
                          onMarkReviewed: (questionId) => progress
                              .clearQuestionForReview(chapter.id, questionId),
                          onRetakeQuiz: () => Navigator.of(context).pushNamed(
                            QuizScreen.routeName,
                            arguments: chapter.id,
                          ),
                        ),
                    ],
                  ] else ...[
                    _CourseSummary(
                        completed: completed, total: chapters.length),
                    const SizedBox(height: AppSpacing.md),
                    _StatsPanel(
                        progress: p, activeStreak: activeStreak, now: now),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterProgressCard extends StatelessWidget {
  const _ChapterProgressCard({required this.chapter, required this.record});

  final Chapter chapter;
  final ChapterProgress? record;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final best = record;
    final assetPath = chapter.thumbnailAsset;
    final starCount = best?.stars ?? 0;
    final reflow = AccessibleLayout.needsReflow(context);
    const fallback = ColoredBox(
      color: AppColors.primarySoft,
      child: Icon(Icons.auto_stories_rounded, color: AppColors.primaryDark),
    );
    final stars = Semantics(
      label: '$starCount of 3 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Icon(
              i < starCount ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 18,
              color: i < starCount
                  ? AppColors.accentDeep
                  : AppColors.textSecondary,
            ),
        ],
      ),
    );
    return _ProgressPanel(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: SizedBox.square(
              dimension: 48,
              child: assetPath == null
                  ? fallback
                  : Image.asset(assetPath,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      excludeFromSemantics: true,
                      errorBuilder: (_, __, ___) => fallback),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(chapter.title.en, style: text.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                    best != null && best.completed
                        ? 'Best ${best.bestScorePercent}%'
                        : 'Not finished yet',
                    style: text.bodyMedium
                        ?.copyWith(color: AppColors.textSecondary)),
                if (reflow) ...[const SizedBox(height: AppSpacing.xs), stars],
              ],
            ),
          ),
          if (!reflow) ...[const SizedBox(width: AppSpacing.sm), stars],
        ],
      ),
    );
  }
}

class _PracticeCallout extends StatelessWidget {
  const _PracticeCallout({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const title = 'Practise Mistakes';
    const action = 'Open practice';
    final detail =
        '$count ${count == 1 ? 'question' : 'questions'} ready to practise';
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.18)),
    );
    void openPractice() {
      Navigator.of(context).pushNamed(ReviewPracticeScreen.routeName);
    }

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      label: '$title. $detail',
      hint: action,
      onTap: openPractice,
      child: Material(
        color: AppColors.primarySoft,
        shape: shape,
        child: InkWell(
          onTap: openPractice,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                const _ProgressBadge(
                  icon: Icons.replay_rounded,
                  tint: AppColors.surface,
                  color: AppColors.primaryDark,
                  size: 44,
                ),
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
                      const SizedBox(height: AppSpacing.sm),
                      Text(action,
                          style: text.labelLarge
                              ?.copyWith(color: AppColors.primaryDark)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.primaryDark),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyReviewCard extends StatelessWidget {
  const _EmptyReviewCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _ProgressPanel(
      child: Column(
        children: [
          const _ProgressBadge(
            icon: Icons.check_rounded,
            tint: AppColors.successSoft,
            color: AppColors.successDark,
            size: 56,
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          Text('Nothing to review',
              style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'You’re all caught up! Any questions you miss will be saved here '
            'when you’re ready to try again.',
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MistakeReviewCard extends StatelessWidget {
  const _MistakeReviewCard({
    required this.chapter,
    required this.missedIds,
    required this.language,
    required this.onMarkReviewed,
    required this.onRetakeQuiz,
  });

  final Chapter chapter;
  final Set<String> missedIds;
  final String language;
  final ValueChanged<String> onMarkReviewed;
  final VoidCallback onRetakeQuiz;

  @override
  Widget build(BuildContext context) {
    final questions = chapter.quiz
        .where((question) => missedIds.contains(question.id))
        .toList();
    if (questions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: _ProgressPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _ProgressPill(label: chapter.title.en),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final (index, question) in questions.indexed) ...[
              if (index > 0) const _ProgressDivider(),
              _ReviewQuestion(
                question: question,
                language: language,
                onMarkReviewed: () => onMarkReviewed(question.id),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              onPressed: onRetakeQuiz,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.square(AccessibleLayout.minTouchTarget),
                foregroundColor: AppColors.primaryDark,
                side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.24)),
                visualDensity: VisualDensity.standard,
              ),
              icon: const Icon(Icons.replay_rounded, size: 20),
              label: const Text('Retake chapter quiz',
                  textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewQuestion extends StatelessWidget {
  const _ReviewQuestion({
    required this.question,
    required this.language,
    required this.onMarkReviewed,
  });

  final QuizQuestion question;
  final String language;
  final VoidCallback onMarkReviewed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(question.question,
            style: text.bodyLarge?.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: AppColors.successSoft,
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_rounded,
                  color: AppColors.successDark, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('Answer: ${question.correctAnswer}',
                    style: text.titleMedium?.copyWith(
                      color: AppColors.successDark,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    )),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        Text(question.explanation.of(language),
            style: text.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: onMarkReviewed,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              minimumSize: const Size.square(AccessibleLayout.minTouchTarget),
              visualDensity: VisualDensity.standard,
            ),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Mark reviewed'),
          ),
        ),
      ],
    );
  }
}

class _ProgressTabs extends StatelessWidget {
  const _ProgressTabs(
      {required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final columns =
            AccessibleLayout.needsReflow(context) || constraints.maxWidth < 320
                ? 2
                : labels.length;
        final width =
            (constraints.maxWidth - (columns - 1) * AppSpacing.xs) / columns;
        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < labels.length; i++)
              SizedBox(
                width: width,
                child: _TabChip(
                    label: labels[i],
                    selected: i == selected,
                    onTap: () => onSelect(i)),
              ),
          ],
        );
      }),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = StadiumBorder(
      side: selected
          ? BorderSide(color: AppColors.primary.withValues(alpha: 0.22))
          : BorderSide.none,
    );
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: Material(
        shape: shape,
        color: selected ? AppColors.surface : AppColors.primarySoft,
        elevation: selected ? 2 : 0,
        shadowColor: AppColors.primaryDark.withValues(alpha: 0.22),
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: AccessibleLayout.minimumTarget(
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? AppColors.primaryDark
                            : AppColors.textPrimary,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      )),
            ),
          ),
        ),
      ),
    );
  }
}

class _CourseSummary extends StatelessWidget {
  const _CourseSummary({required this.completed, required this.total});

  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fraction = total == 0 ? 0.0 : completed / total;
    return _ProgressPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _ProgressPortrait(),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Course completion', style: text.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    Text('$completed of $total chapters complete',
                        style: text.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          LinearProgressIndicator(
            value: fraction,
            minHeight: 10,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            backgroundColor: AppColors.primarySoft,
            color: AppColors.primary,
            semanticsLabel: 'Course completion',
          ),
        ],
      ),
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel(
      {required this.progress, required this.activeStreak, required this.now});

  final UserProgress progress;
  final int activeStreak;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    String days(int value) => '$value ${value == 1 ? 'day' : 'days'}';
    final rows = [
      _StatRow(
          icon: Icons.military_tech_rounded,
          label: 'Total XP',
          value: '${p.totalXp}',
          tint: AppColors.primarySoft,
          color: AppColors.primaryDark),
      _StatRow(
          icon: Icons.monetization_on_rounded,
          label: 'Coins',
          value: '${p.coins}',
          tint: AppColors.accentSoft,
          color: AppColors.accentDeep),
      _StatRow(
          icon: Icons.local_fire_department_rounded,
          label: 'Current streak',
          value: days(activeStreak),
          tint: AppColors.accentSoft,
          color: AppColors.accentDeep,
          emphasized: true),
      _StatRow(
          icon: Icons.emoji_events_rounded,
          label: 'Best streak',
          value: days(p.bestStreakDays),
          tint: AppColors.accentSoft,
          color: AppColors.accentDeep,
          emphasized: true),
      _StatRow(
          icon: Icons.quiz_rounded,
          label: 'Questions today',
          value: '${p.questionsAnsweredOn(now)}',
          tint: AppColors.successSoft,
          color: AppColors.successDark),
      _StatRow(
          icon: Icons.flag_rounded,
          label: 'Daily goal',
          value: '${p.dailyGoalQuestions} questions',
          tint: AppColors.successSoft,
          color: AppColors.successDark),
      _StatRow(
          icon: Icons.trending_up_rounded,
          label: 'Level',
          value: '${p.level} — ${p.levelTitle}',
          tint: AppColors.primarySoft,
          color: AppColors.primaryDark),
    ];
    return _ProgressPanel(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const _ProgressDivider(),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
          boxShadow: AppShadows.cardSoft,
        ),
        child: child,
      );
}

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.xs),
        decoration: const ShapeDecoration(
            color: AppColors.primarySoft, shape: StadiumBorder()),
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: AppColors.primaryDark)),
      );
}

class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge(
      {required this.icon,
      required this.tint,
      required this.color,
      this.size = 36});

  final IconData icon;
  final Color tint;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: size * 0.55),
      );
}

class _ProgressDivider extends StatelessWidget {
  const _ProgressDivider();

  @override
  Widget build(BuildContext context) => Divider(
        color: AppColors.primary.withValues(alpha: 0.12),
        thickness: 1,
        height: AppSpacing.sm + 4,
      );
}

class _ProgressPortrait extends StatelessWidget {
  const _ProgressPortrait();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
          boxShadow: AppShadows.cardSoft,
        ),
        child: ClipOval(
          child: SizedBox.square(
            dimension: 60,
            child: Image.asset(
              'assets/illustrations/progress_avatar.webp',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              filterQuality: FilterQuality.high,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: AppColors.primarySoft,
                child: Icon(Icons.person_rounded, color: AppColors.primaryDark),
              ),
            ),
          ),
        ),
      );
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.title,
    required this.xpIntoLevel,
    required this.xpPerLevel,
  });

  final int level;
  final String title;
  final int xpIntoLevel;
  final int xpPerLevel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _ProgressPanel(
      child: Row(
        children: [
          const _ProgressPortrait(),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Level $level', style: text.titleLarge),
                Text(title, style: text.bodyMedium),
                const SizedBox(height: AppSpacing.sm),
                AppProgressBar(value: xpIntoLevel / xpPerLevel),
                const SizedBox(height: 4),
                Text('$xpIntoLevel / $xpPerLevel XP', style: text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Seven dots ending on today; filled for each day the streak covers.
///
/// The data model keeps a streak length and a last-study date, so this is a
/// true reading of what was already earned rather than decoration.
class _StreakStrip extends StatelessWidget {
  const _StreakStrip({required this.streakDays, required this.today});

  final int streakDays;
  final DateTime today;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final filled = streakDays.clamp(0, 7);
    // Index 6 is today, so the week runs backwards from it.
    final todayIndex = today.weekday - 1;
    return _ProgressPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: AppColors.accentDark, size: 20),
              const SizedBox(width: 6),
              Flexible(child: Text('This week', style: text.titleMedium)),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  streakDays == 0
                      ? 'Start today'
                      : '$streakDays day${streakDays == 1 ? '' : 's'} in a row',
                  textAlign: TextAlign.end,
                  style: text.bodyMedium?.copyWith(
                    color: streakDays == 0
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                Column(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i >= 7 - filled && streakDays > 0
                            ? AppColors.accentSoft
                            : AppColors.background,
                        border: i == 6
                            ? Border.all(color: AppColors.primary, width: 1.6)
                            : null,
                      ),
                      child: Icon(
                        i >= 7 - filled && streakDays > 0
                            ? Icons.local_fire_department_rounded
                            : Icons.remove_rounded,
                        size: 15,
                        color: i >= 7 - filled && streakDays > 0
                            ? AppColors.accentDark
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _labels[(todayIndex - (6 - i)) % 7],
                      style: text.bodyMedium?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: i == 6
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// XP earned per chapter — the only per-chapter number the app actually keeps,
/// so the chart is honest at zero as well as at five.
class _ChapterXpCard extends StatelessWidget {
  const _ChapterXpCard({required this.chapters});

  final List<({String title, int xp})> chapters;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final maxXp = chapters.fold<int>(0, (max, c) => c.xp > max ? c.xp : max);
    return _ProgressPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded,
                  color: AppColors.primaryDark, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('XP by chapter', style: text.titleMedium)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (maxXp == 0)
            Text(
              'Answer a quiz and your first bar shows up here.',
              style: text.bodyMedium?.copyWith(color: AppColors.textSecondary),
            )
          else
            for (final chapter in chapters) ...[
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(chapter.title, style: text.titleSmall),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text('${chapter.xp}',
                        style: text.titleSmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              LinearProgressIndicator(
                value: (chapter.xp / maxXp).clamp(0.0, 1.0),
                minHeight: 8,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                backgroundColor: AppColors.primarySoft,
                color: AppColors.primary,
                semanticsLabel: '${chapter.title}, ${chapter.xp} XP',
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _ProgressPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: text.bodyMedium)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: text.titleLarge),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
    required this.color,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reflow = AccessibleLayout.isCompact(context);
    final title = Text(label,
        style: text.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600));
    final amount = Text(
      value,
      textAlign: reflow ? TextAlign.start : TextAlign.end,
      style: text.bodyMedium?.copyWith(
        color: emphasized ? AppColors.textPrimary : AppColors.textSecondary,
        fontWeight: emphasized ? FontWeight.w800 : FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final metric = emphasized
        ? Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: const ShapeDecoration(
                color: AppColors.accentSoft, shape: StadiumBorder()),
            child: amount,
          )
        : amount;
    return Row(
      children: [
        _ProgressBadge(icon: icon, tint: tint, color: color),
        const SizedBox(width: AppSpacing.sm + 2),
        if (reflow)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: AppSpacing.xs), metric],
            ),
          )
        else ...[
          Expanded(child: title),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child:
                Align(alignment: AlignmentDirectional.centerEnd, child: metric),
          ),
        ],
      ],
    );
  }
}
