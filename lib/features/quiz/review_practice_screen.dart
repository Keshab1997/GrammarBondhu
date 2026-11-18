import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/accessible_layout.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/chapter.dart';
import '../../data/models/progress.dart';

typedef _PracticeItem = ({Chapter chapter, QuizQuestion question});

/// Only count questions the learner can still open in the bundled course.
int countReviewableMistakes(List<Chapter> chapters, UserProgress progress) =>
    _queuedMistakes(chapters, progress).length;

Iterable<_PracticeItem> _queuedMistakes(
  List<Chapter> chapters,
  UserProgress progress,
) sync* {
  for (final chapter in chapters) {
    final missed = progress.chapters[chapter.id]?.missedQuestionIds;
    if (missed == null || missed.isEmpty) continue;
    for (final question in chapter.quiz) {
      if (missed.contains(question.id)) {
        yield (chapter: chapter, question: question);
      }
    }
  }
}

/// A retry of just the missed questions, without chapter completion rewards.
class ReviewPracticeScreen extends StatefulWidget {
  const ReviewPracticeScreen({super.key});

  static const routeName = '/review-practice';

  @override
  State<ReviewPracticeScreen> createState() => _ReviewPracticeScreenState();
}

class _ReviewPracticeScreenState extends State<ReviewPracticeScreen> {
  final _scroll = ScrollController();
  late List<_PracticeItem> _deck;
  int _index = 0;
  int _clearedCount = 0;
  int? _selected;
  bool _submitting = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _deck = _snapshotDeck();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<_PracticeItem> _snapshotDeck() => _queuedMistakes(
        context.read<ContentController>().chapters,
        context.read<ProgressController>().progress,
      ).toList(growable: false);

  void _leave() {
    Navigator.of(context).maybePop();
  }

  void _restart() {
    setState(() {
      _deck = _snapshotDeck();
      _index = 0;
      _clearedCount = 0;
      _selected = null;
      _submitted = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _advance() {
    if (!_submitted) return;
    setState(() {
      _index += 1;
      _selected = null;
      _submitted = false;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _select(int index) {
    if (_submitting || _submitted) return;
    setState(() => _selected = index);
  }

  Future<void> _submit() async {
    if (_submitting || _submitted || _selected == null) return;
    final progress = context.read<ProgressController>();
    final (:chapter, :question) = _deck[_index];
    final correct = _selected == question.correctIndex;

    setState(() => _submitting = true);
    try {
      final reviewChange = correct
          ? progress.clearQuestionForReview(chapter.id, question.id)
          : progress.markQuestionForReview(chapter.id, question.id);
      // A submitted answer still counts if the learner closes the screen
      // while the local save is in flight. Neither write needs this widget.
      await reviewChange.then((_) => progress.registerQuestionAnswered());
      if (!mounted) return;
      setState(() {
        if (correct) _clearedCount += 1;
        _submitted = true;
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight:
            AccessibleLayout.needsReflow(context) ? 88 : kToolbarHeight,
        leading: IconButton(
          tooltip: 'Close',
          onPressed: _leave,
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text(
          'Mistake Practice',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_deck.isEmpty) ...[
                _message(
                  context,
                  heading: 'Nothing to review',
                  detail: 'Nice work! Keep learning and any missed questions '
                      'will be ready here for another try.',
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(label: 'Back', onPressed: _leave),
              ] else if (_index == _deck.length)
                ..._summary(context)
              else
                ..._question(context, _deck[_index]),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _question(BuildContext context, _PracticeItem item) {
    final text = Theme.of(context).textTheme;
    final (:chapter, :question) = item;
    final language = context.watch<SettingsController>().supportLanguage;
    final isLast = _index == _deck.length - 1;
    final correct = _selected == question.correctIndex;
    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Question ${_index + 1} of ${_deck.length}',
              style: text.labelLarge?.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppProgressBar(value: (_index + 1) / _deck.length, height: 8),
            const SizedBox(height: AppSpacing.md),
            Text(chapter.title.en, style: text.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(question.question, style: text.titleLarge),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      for (var i = 0; i < question.options.length; i++) ...[
        _PracticeOption(
          letter: String.fromCharCode(65 + i),
          answer: question.options[i],
          selected: _selected == i,
          correct: _submitted && i == question.correctIndex,
          incorrect: _submitted && _selected == i && !correct,
          onTap: _submitting || _submitted ? null : () => _select(i),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      const SizedBox(height: AppSpacing.sm),
      if (_submitted) ...[
        Semantics(
          container: true,
          liveRegion: true,
          child: _message(
            context,
            heading: correct ? 'Correct!' : 'Not quite. Keep practising!',
            detail: question.explanation.of(language),
            color: correct ? AppColors.successSoft : AppColors.errorSoft,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: isLast ? 'Finish Practice' : 'Next Question',
          icon: isLast ? Icons.flag_rounded : Icons.arrow_forward_rounded,
          onPressed: _advance,
        ),
      ] else
        AppButton(
          label: 'Submit',
          onPressed: _selected == null || _submitting ? null : _submit,
        ),
    ];
  }

  List<Widget> _summary(BuildContext context) {
    final remaining = countReviewableMistakes(
      context.watch<ContentController>().chapters,
      context.watch<ProgressController>().progress,
    );
    return [
      _message(
        context,
        heading: 'Cleared $_clearedCount of ${_deck.length}',
        detail: remaining == 0
            ? 'Every mistake cleared!'
            : '$remaining left for next time',
        color: AppColors.primarySoft,
      ),
      const SizedBox(height: AppSpacing.md),
      if (remaining > 0) ...[
        AppButton(
          label: 'Practise Remaining',
          icon: Icons.replay_rounded,
          onPressed: _restart,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      AppButton(
        label: 'Done',
        variant:
            remaining > 0 ? AppButtonVariant.outline : AppButtonVariant.blue,
        onPressed: _leave,
      ),
    ];
  }

  Widget _message(
    BuildContext context, {
    required String heading,
    required String detail,
    Color color = AppColors.surface,
  }) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(heading, style: text.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(detail, style: text.bodyMedium),
        ],
      ),
    );
  }
}

class _PracticeOption extends StatelessWidget {
  const _PracticeOption({
    required this.letter,
    required this.answer,
    required this.selected,
    required this.correct,
    required this.incorrect,
    required this.onTap,
  });

  final String letter;
  final String answer;
  final bool selected;
  final bool correct;
  final bool incorrect;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final verdict = correct
        ? ', correct answer'
        : incorrect
            ? ', your answer, incorrect'
            : '';
    final accent = correct
        ? AppColors.successDark
        : incorrect
            ? AppColors.error
            : AppColors.primary;
    final fill = correct
        ? AppColors.successSoft
        : incorrect
            ? AppColors.errorSoft
            : selected
                ? AppColors.primarySoft
                : AppColors.surface;
    final outlined = selected || correct || incorrect;

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: 'Option $letter. $answer$verdict',
      button: true,
      enabled: onTap != null,
      selected: selected,
      onTap: onTap,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          side: BorderSide(color: outlined ? accent : AppColors.backgroundAlt),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AccessibleLayout.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Text('$letter.',
                      style: text.titleSmall?.copyWith(color: accent)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(answer, style: text.bodyLarge)),
                  if (correct || incorrect) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(correct ? Icons.check_rounded : Icons.close_rounded,
                        size: 20, color: accent),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
