import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/accessible_layout.dart';
import '../../core/utils/asset_lookup.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/asset_images.dart';
import '../../data/models/chapter.dart';
import '../grammar/grammar_lesson_screen.dart';
import '../story/story_screen.dart';

/// A consistent display label for the difficulty in both chapter views.
extension ChapterDifficultyLabel on Chapter {
  String get difficultyLabel {
    final level = difficulty.trim().toLowerCase();
    if (level.isEmpty) return '';
    return level
        .split(RegExp(r'\s+'))
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}

/// Screen 17 — chapter intro: what it is, what you will learn, and one way in.
///
/// The hero keeps the artwork's own 1376 × 768 ratio instead of being stretched
/// over the whole screen: a full-bleed cover crop sliced both characters'
/// faces in half on every phone. The sheet below scrolls, and the CTA is
/// pinned outside the scroll — a fixed-height `Column` with a `Spacer` (the old
/// layout) overflowed by 368 px at 353 dp.
class ChapterDetailScreen extends StatelessWidget {
  const ChapterDetailScreen({super.key, required this.chapterId});

  static const routeName = '/chapter-detail';

  final String chapterId;

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentController>();
    final progress = context.watch<ProgressController>();
    final lang = context.select(
        (SettingsController? settings) => settings?.supportLanguage ?? 'en');
    final chapter = content.byId(chapterId);

    if (chapter == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Chapter not found')),
      );
    }

    final record = progress.chapterProgress(chapterId);
    final number = content.chapters.indexOf(chapter) + 1;
    final started = record.started && !record.completed;
    final resume = started
        ? (record.resumeSceneIndex ?? 0).clamp(0, chapter.scenes.length)
        : null;

    return Scaffold(
      // Surface, not background: the sheet is nudged up 24 dp to overlap the
      // hero, which would otherwise leave a pale strip along the bottom edge.
      backgroundColor: AppColors.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            // On a landscape/tablet viewport the hero still leaves room for
            // both the chapter sheet and its pinned action.
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.38),
            child: _Hero(
              backgroundId: chapter.scenes.isNotEmpty
                  ? chapter.scenes.first.backgroundId
                  : null,
              stars: record.stars,
              completed: record.completed,
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadii.sheet),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 24,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                        child: _SheetBody(
                          number: number,
                          chapter: chapter,
                          supportLanguage: lang,
                          bestScore: record.bestScorePercent,
                          completed: record.completed,
                          resumeIndex: resume,
                        ),
                      ),
                    ),
                    _CtaBar(
                      label: started
                          ? 'Resume'
                          : record.completed
                              ? 'Play again'
                              : 'Start',
                      onPressed: () {
                        final nav = Navigator.of(context);
                        if (chapter.scenes.isEmpty ||
                            resume == chapter.scenes.length) {
                          nav.pushNamed(GrammarLessonScreen.routeName,
                              arguments: chapterId);
                        } else {
                          nav.pushNamed(StoryScreen.routeName,
                              arguments: StoryArgs(chapterId,
                                  startScene: resume ?? 0));
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.backgroundId,
    required this.stars,
    required this.completed,
  });

  final String? backgroundId;
  final int stars;
  final bool completed;

  /// The landscape frame matches the bundled chapter hero fallback.
  static const _aspect = 1376 / 768;

  @override
  Widget build(BuildContext context) {
    final id = backgroundId;
    final sceneAsset = id == null ? null : AssetLookup.backgroundPath(id);
    Widget fallback() => Image.asset(
          'assets/illustrations/chapter_detail_hero.webp',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          excludeFromSemantics: true,
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: AppColors.skyTop),
        );
    return AspectRatio(
      aspectRatio: _aspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (sceneAsset == null)
            fallback()
          else
            Image.asset(
              sceneAsset,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              excludeFromSemantics: true,
              errorBuilder: (_, __, ___) => fallback(),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x520B1B3A),
                  Color(0x00000000),
                  Color(0x470B1B3A),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
          // Leave the middle of the scene unobstructed; the chapter identity
          // and translations have their own space in the sheet.
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CircleButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                  if (completed && stars > 0)
                    DecoratedBox(
                      decoration: ShapeDecoration(
                        color: Colors.black.withValues(alpha: 0.38),
                        shape: StadiumBorder(
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.36))),
                      ),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: Semantics(
                              label: '$stars of 3 stars',
                              excludeSemantics: true,
                              child: StarsDisplay(count: stars, size: 18))),
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

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    this.color = AppColors.primaryDark,
    this.icon,
  });

  final String label;
  final Color color;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
          minWidth: AccessibleLayout.minTouchTarget,
          minHeight: AccessibleLayout.minTouchTarget),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
            minimumSize: const Size.square(AccessibleLayout.minTouchTarget),
            visualDensity: VisualDensity.standard,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary),
      ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.number,
    required this.chapter,
    required this.supportLanguage,
    required this.bestScore,
    required this.completed,
    required this.resumeIndex,
  });

  final int number;
  final Chapter chapter;
  final String supportLanguage;
  final int bestScore;
  final bool completed;
  final int? resumeIndex;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final sceneCount = chapter.scenes.length;
    final localizedTitle = chapter.title.of(supportLanguage);
    final localizedDescription = chapter.description.of(supportLanguage);
    final secondary = text.bodyMedium?.copyWith(color: AppColors.textSecondary);
    final level = chapter.difficultyLabel;
    final resume = resumeIndex;
    final readyForLesson = sceneCount == 0 || resume == sceneCount;
    final cast = <String>{
      for (final scene in chapter.scenes) ...[
        ...scene.characterIds,
        for (final line in scene.dialogue) line.characterId,
      ],
    }..removeWhere((id) => id.trim().isEmpty);

    final progressNote = completed
        ? 'Finished — replay the story or beat your best score.'
        : readyForLesson
            ? 'Story complete. Ready for the grammar lesson.'
            : resume != null
                ? 'Scene ${resume + 1} of $sceneCount. Pick up where you left off.'
                : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The sheet opens with the chapter it belongs to. It used to open with
        // the grammar chip over the hero's title, so the first thing read was
        // the least important thing on the screen.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _Pill(label: 'CHAPTER $number'),
            if (level.isNotEmpty) _Pill(label: level),
            if (completed)
              const _Pill(
                label: 'COMPLETED',
                color: Color(0xFF065F46),
                icon: Icons.check_rounded,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          chapter.title.en,
          style: text.displaySmall?.copyWith(fontSize: 30, height: 1.15),
        ),
        if (supportLanguage != 'en' && localizedTitle != chapter.title.en)
          Text(localizedTitle,
              style:
                  text.titleMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpacing.sm),
        Text(chapter.description.en, style: text.bodyLarge),
        if (supportLanguage != 'en' &&
            localizedDescription != chapter.description.en)
          Text(localizedDescription, style: secondary),
        if (progressNote != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(progressNote, style: secondary),
        ],
        if (cast.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
            for (final id in cast) _CastChip(id: id),
          ]),
        ],
        const SizedBox(height: AppSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadii.card - 4),
            border: Border.all(color: const Color(0xFFD8E6FB)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: const Icon(Icons.school_rounded,
                    size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GRAMMAR FOCUS',
                      style: text.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      chapter.grammarTopic.en,
                      style: text.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text("What's inside", style: text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        _StepRow(
          icon: Icons.auto_stories_rounded,
          phase: completed || readyForLesson
              ? _StepPhase.finished
              : _StepPhase.active,
          title: 'Story',
          detail: '$sceneCount scenes',
          status: completed || readyForLesson
              ? 'Finished'
              : resume != null
                  ? 'Scene ${resume + 1}'
                  : 'Up next',
        ),
        _StepRow(
          icon: Icons.school_rounded,
          phase: completed
              ? _StepPhase.finished
              : readyForLesson
                  ? _StepPhase.active
                  : _StepPhase.upcoming,
          title: 'Grammar lesson',
          detail: 'Rules & examples',
          status: completed
              ? 'Finished'
              : readyForLesson
                  ? 'Up next'
                  : null,
        ),
        _StepRow(
          icon: Icons.quiz_rounded,
          phase: completed ? _StepPhase.finished : _StepPhase.upcoming,
          title: 'Quiz',
          detail: '${chapter.quiz.length} questions',
          status: completed
              ? 'Best $bestScore%'
              : resume != null
                  ? 'Unlocks at the end'
                  : null,
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Maximum rewards', style: text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          _Pill(label: '${chapter.rewards.xp} XP', icon: Icons.bolt_rounded),
          _Pill(
              label: '${chapter.rewards.coins} coins',
              color: const Color(0xFF854D0E),
              icon: Icons.monetization_on_rounded),
        ]),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _CastChip extends StatelessWidget {
  const _CastChip({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
      decoration: ShapeDecoration(
        color: AppColors.primarySoft,
        shape: StadiumBorder(
            side: BorderSide(color: AppColors.primary.withValues(alpha: 0.14))),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ExcludeSemantics(child: CharacterAvatar(characterId: id, size: 24)),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
            child: Text(AssetLookup.characterDisplayName(id),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

enum _StepPhase { finished, active, upcoming }

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.icon,
    required this.phase,
    required this.title,
    required this.detail,
    this.status,
  });

  final IconData icon;
  final _StepPhase phase;
  final String title;
  final String detail;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (color, fill) = switch (phase) {
      _StepPhase.finished => (AppColors.successDark, AppColors.successSoft),
      _StepPhase.active => (AppColors.primary, AppColors.primarySoft),
      _StepPhase.upcoming => (AppColors.textSecondary, AppColors.background),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          color: phase == _StepPhase.active ? fill : AppColors.surface,
          border: Border.all(
              color: color.withValues(
                  alpha: phase == _StepPhase.active ? 0.52 : 0.23))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: fill,
              shape: BoxShape.circle,
              border: Border.all(
                  color: color, width: phase == _StepPhase.active ? 2 : 1),
            ),
            child: Icon(
                phase == _StepPhase.finished ? Icons.check_rounded : icon,
                size: 18,
                color: color),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: text.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        )),
                    Text(detail,
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
                if (status != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundAlt,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status!,
                      style: text.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pinned CTA — outside the scroll view, so it can never be pushed off screen.
class _CtaBar extends StatelessWidget {
  const _CtaBar({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg + 6,
            AppSpacing.lg,
            AppSpacing.md + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 18,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: AppButton(
            label: label,
            icon: Icons.play_arrow_rounded,
            variant: AppButtonVariant.primary,
            onPressed: onPressed,
          ),
        ),
        // A short fade above the bar: without it the last paragraph is sliced
        // mid-sentence by a hard edge and reads as a layout bug.
        Positioned(
          left: 0,
          right: 0,
          top: -26,
          height: 26,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00FFFFFF), AppColors.surface],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
