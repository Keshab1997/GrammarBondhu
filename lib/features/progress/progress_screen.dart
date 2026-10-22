import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/asset_images.dart';
import '../../data/models/progress.dart';

/// Screen 14 — overview, per-chapter history and stats.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  static const routeName = '/progress';

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentController>();
    final progress = context.watch<ProgressController>();
    final p = progress.progress;

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
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  if (_tab == 0) ...[
                    _LevelCard(
                      level: p.level,
                      title: p.levelTitle,
                      xpIntoLevel: p.xpIntoLevel,
                      xpPerLevel: UserProgress.xpPerLevel,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 1.5,
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
                          label: 'Quiz Answers',
                          value: '${p.totalQuizAnswered}',
                        ),
                        _StatTile(
                          icon: Icons.local_fire_department_rounded,
                          color: AppColors.accentDark,
                          label: 'Streak',
                          value:
                              '${p.streakDays} ${p.streakDays == 1 ? 'day' : 'days'}',
                        ),
                        _StatTile(
                          icon: Icons.military_tech_rounded,
                          color: AppColors.primaryDark,
                          label: 'Total Points',
                          value: '${p.totalXp}',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _StreakStrip(
                      streakDays: p.streakDays,
                      today: DateTime.now(),
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
                  ] else ...[
                    AppCard(
                      child: Column(
                        children: [
                          _StatRow(label: 'Total XP', value: '${p.totalXp}'),
                          _StatRow(label: 'Coins', value: '${p.coins}'),
                          _StatRow(
                              label: 'Current streak',
                              value: '${p.streakDays} days'),
                          _StatRow(
                              label: 'Questions today',
                              value: '${p.questionsAnsweredToday}'),
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
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  color: AppColors.accentDark, size: 20),
              const SizedBox(width: 6),
              Text('This week', style: text.titleMedium),
              const Spacer(),
              Text(
                streakDays == 0
                    ? 'Start today'
                    : '$streakDays day${streakDays == 1 ? '' : 's'} in a row',
                style: text.bodyMedium?.copyWith(
                  color: streakDays == 0
                      ? AppColors.textMuted
                      : AppColors.accentDeep,
                  fontWeight: FontWeight.w700,
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: text.bodyMedium, overflow: TextOverflow.ellipsis),
              ),
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
