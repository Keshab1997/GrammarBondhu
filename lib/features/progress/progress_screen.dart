import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/asset_images.dart';
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
  late int _tab = widget.initialTab.clamp(0, 3);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final content = context.watch<ContentController>();
    final progress = context.watch<ProgressController>();
    final language = context.watch<SettingsController>().supportLanguage;
    final p = progress.progress;
    final now = (widget.now ?? DateTime.now()).toLocal();
    final activeStreak = p.activeStreakOn(now);
    final reviewCount = countReviewableMistakes(content.chapters, p);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('My Progress'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  _TabChip(
                      label: 'Overview',
                      selected: _tab == 0,
                      onTap: () => setState(() => _tab = 0)),
                  const SizedBox(width: AppSpacing.sm),
                  _TabChip(
                      label: 'Chapters',
                      selected: _tab == 1,
                      onTap: () => setState(() => _tab = 1)),
                  const SizedBox(width: AppSpacing.sm),
                  _TabChip(
                      label: 'Stats',
                      selected: _tab == 2,
                      onTap: () => setState(() => _tab = 2)),
                  const SizedBox(width: AppSpacing.sm),
                  _TabChip(
                      label: 'Review',
                      selected: _tab == 3,
                      onTap: () => setState(() => _tab = 3)),
                ],
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
                    // A GridView.count forces one height on every tile, and
                    // no height is right at every font scale: the fixed
                    // aspect ratio clipped 23 px at 200%, and a computed
                    // height still missed because a label can wrap to two
                    // lines on a narrow phone. A Wrap of IntrinsicHeight
                    // tiles lets each one be as tall as its own text, which
                    // is the only answer that survives both axes at once.
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
                              value:
                                  '${p.completedChapterCount}/${content.chapters.length}',
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
                      chapters: content.chapters
                          .map((c) => (
                                title: c.title.en,
                                xp: progress.chapterProgress(c.id).xpEarned,
                                stars: progress.chapterProgress(c.id).stars,
                                done: progress.isCompleted(c.id),
                              ))
                          .toList(),
                    ),
                  ] else if (_tab == 1) ...[
                    for (final chapter in content.chapters)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: AppCard(
                          child: Row(
                            children: [
                              ChapterThumbnail(
                                assetPath: chapter.thumbnailAsset,
                                fallbackIcon: Icons.auto_stories_rounded,
                                size: 48,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(chapter.title.en,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    Text(
                                      progress
                                              .chapterProgress(chapter.id)
                                              .completed
                                          ? 'Best ${progress.chapterProgress(chapter.id).bestScorePercent}%'
                                          : 'Not finished yet',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              StarsDisplay(
                                count:
                                    progress.chapterProgress(chapter.id).stars,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ] else if (_tab == 3) ...[
                    if (reviewCount == 0)
                      AppCard(
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded,
                                color: AppColors.success, size: 40),
                            const SizedBox(height: AppSpacing.sm),
                            Text('Nothing to review', style: text.titleMedium),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Questions you miss will be saved here so you can '
                              'come back to them later.',
                              textAlign: TextAlign.center,
                              style: text.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    else ...[
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '$reviewCount ${reviewCount == 1 ? 'question' : 'questions'} ready to practise',
                              style: text.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            AppButton(
                              label: 'Practise Mistakes',
                              icon: Icons.replay_rounded,
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const ReviewPracticeScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final chapter in content.chapters)
                        _MistakeReviewCard(
                          chapter: chapter,
                          missedIds: progress
                              .chapterProgress(chapter.id)
                              .missedQuestionIds,
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
                    AppCard(
                      child: Column(
                        children: [
                          _StatRow(label: 'Total XP', value: '${p.totalXp}'),
                          _StatRow(label: 'Coins', value: '${p.coins}'),
                          _StatRow(
                              label: 'Current streak',
                              value:
                                  '$activeStreak ${activeStreak == 1 ? 'day' : 'days'}'),
                          _StatRow(
                            label: 'Best streak',
                            value:
                                '${p.bestStreakDays} ${p.bestStreakDays == 1 ? 'day' : 'days'}',
                          ),
                          _StatRow(
                              label: 'Questions today',
                              value: '${p.questionsAnsweredOn(now)}'),
                          _StatRow(
                              label: 'Daily goal',
                              value: '${p.dailyGoalQuestions} questions'),
                          _StatRow(
                              label: 'Level',
                              value: '${p.level} — ${p.levelTitle}'),
                        ],
                      ),
                    ),
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
    final text = Theme.of(context).textTheme;
    final questions = chapter.quiz
        .where((question) => missedIds.contains(question.id))
        .toList();
    if (questions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(chapter.title.en, style: text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            for (final question in questions) ...[
              const Divider(height: AppSpacing.md),
              Text(question.question,
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.xs),
              Text('Answer: ${question.correctAnswer}',
                  style: text.bodyMedium?.copyWith(
                    color: AppColors.successDark,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: AppSpacing.xs),
              Text(question.explanation.of(language), style: text.bodyMedium),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => onMarkReviewed(question.id),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Mark reviewed'),
                ),
              ),
            ],
            AppButton(
              label: 'Retake chapter quiz',
              icon: Icons.replay_rounded,
              variant: AppButtonVariant.outline,
              onPressed: onRetakeQuiz,
            ),
          ],
        ),
      ),
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
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
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
    return AppCard(
      child: Row(
        children: [
          // A circle, not a rounded square: the square crop sliced the top of
          // the portrait's head on every device.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: ClipOval(
              child: SizedBox(
                width: 62,
                height: 62,
                child: Image.asset(
                  'assets/illustrations/progress_avatar.webp',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) =>
                      const CharacterAvatar(characterId: 'rahul', size: 62),
                ),
              ),
            ),
          ),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "12 days in a row" is the longest string on this card and the
          // reason the row overflowed by 72 px once the system font scale
          // went up: it wraps under the title instead of next to it.
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
                        ? AppColors.textMuted
                        : AppColors.accentDeep,
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
                            : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _labels[(todayIndex - (6 - i)) % 7],
                      style: text.bodyMedium?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: i == 6 ? AppColors.primary : AppColors.textMuted,
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

  final List<({String title, int xp, int stars, bool done})> chapters;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final maxXp = chapters.fold<int>(1, (m, c) => c.xp > m ? c.xp : m);
    final empty = chapters.every((c) => c.xp == 0);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              Text('XP by chapter', style: text.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (empty)
            Text(
              'Answer a quiz and your first bar shows up here.',
              style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
            )
          else
            for (final c in chapters) ...[
              Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      c.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: c.xp / maxXp,
                        minHeight: 10,
                        backgroundColor: AppColors.background,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${c.xp}',
                      textAlign: TextAlign.right,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
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
    return AppCard(
      // No fixed height anywhere: at a large font scale the label wraps to a
      // second line and the tile grows with it. An ellipsis here would hide
      // which number the tile is counting.
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
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.bodyLarge)),
          Text(value,
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
