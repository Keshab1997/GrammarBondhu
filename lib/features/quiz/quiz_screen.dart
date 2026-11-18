import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/accessible_layout.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/chapter.dart';
import '../completion/chapter_completed_screen.dart';

/// Screens 11 & 12 — multiple-choice quiz with kind, explanatory feedback.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.chapterId});

  static const routeName = '/quiz';

  final String chapterId;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _questionIndex = 0;
  int? _selected;
  bool _submitted = false;
  bool _submitting = false;
  bool _finishing = false;
  bool _countedThisQuestion = false;
  int _correctCount = 0;

  bool get _optionsLocked => _submitting || _submitted || _finishing;

  Future<void> _submit(Chapter chapter) async {
    if (_selected == null || _optionsLocked) return;
    final question = chapter.quiz[_questionIndex];
    final correct = _selected == question.correctIndex;
    setState(() => _submitting = true);
    try {
      // A retry is practice. Keep the first answer's score, review entry and
      // daily credit, even if the learner gets it right on a second try.
      if (!_countedThisQuestion) {
        final progress = context.read<ProgressController>();
        if (correct) {
          await progress.clearQuestionForReview(chapter.id, question.id);
        } else {
          await progress.markQuestionForReview(chapter.id, question.id);
        }
        await progress.registerQuestionAnswered();
        if (!mounted) return;
        _countedThisQuestion = true;
        if (correct) _correctCount += 1;
      }
      setState(() => _submitted = true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _tryAgain() {
    if (!_submitted || _submitting || _finishing) return;
    setState(() {
      _selected = null;
      _submitted = false;
    });
  }

  Future<void> _next(Chapter chapter) async {
    if (!_submitted || _submitting || _finishing) return;
    if (_questionIndex < chapter.quiz.length - 1) {
      setState(() {
        _questionIndex += 1;
        _countedThisQuestion = false;
        _selected = null;
        _submitted = false;
      });
      return;
    }
    // Lock before the first await, not just on the next frame when the
    // button is rebuilt. On success keep it locked through route replacement.
    setState(() => _finishing = true);
    QuizRunResult? result;
    try {
      result = await context.read<ProgressController>().recordQuizRun(
            chapter: chapter,
            correct: _correctCount,
            total: chapter.quiz.length,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not save your quiz. Please try again.')),
        );
      }
    } finally {
      if (result == null && mounted) setState(() => _finishing = false);
    }
    if (result == null || !mounted) return;
    Navigator.of(context).pushReplacementNamed(
      ChapterCompletedScreen.routeName,
      arguments: CompletedArgs(chapterId: chapter.id, result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final content = context.watch<ContentController>();
    final settings = context.watch<SettingsController>();
    final chapter = content.byId(widget.chapterId);
    if (chapter == null || chapter.quiz.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
            child: Text(chapter == null
                ? 'Chapter not found'
                : 'No quiz questions in this chapter yet.')),
      );
    }

    final question = chapter.quiz[_questionIndex];
    final lang = settings.supportLanguage;
    final isCorrect = _submitted && _selected == question.correctIndex;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Quiz-time illustrated background (storyboard frame 11).
          Image.asset(
            'assets/illustrations/quiz_time.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xAA1B5FC1), Color(0xCC2F80ED)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Close quiz',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text('Quiz Time!',
                                style: text.titleLarge
                                    ?.copyWith(color: Colors.white)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.chip),
                              ),
                              child: Text(
                                'Question ${_questionIndex + 1}/${chapter.quiz.length}',
                                style: text.bodyMedium
                                    ?.copyWith(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                // Where you are in the set, as a bar rather than another label.
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md + 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (_questionIndex + 1) / chapter.quiz.length,
                      minHeight: 6,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                ),
                // The card used to be a full-height container with a Spacer,
                // which left ~600 dp of blank white under four answer options.
                // It now hugs the content, centres in the space that is left,
                // and only scrolls when the question is a long one.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - AppSpacing.md * 2,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius:
                                    BorderRadius.circular(AppRadii.sheet),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Semantics(
                                    header: true,
                                    child: Text(
                                      question.question,
                                      style: text.headlineMedium
                                          ?.copyWith(fontSize: 24),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  for (var i = 0;
                                      i < question.options.length;
                                      i++) ...[
                                    _OptionTile(
                                      index: i,
                                      label: question.options[i],
                                      state: !_submitted
                                          ? (i == _selected
                                              ? _OptionState.selected
                                              : _OptionState.idle)
                                          : i == question.correctIndex
                                              ? _OptionState.correct
                                              : i == _selected
                                                  ? _OptionState.wrong
                                                  : _OptionState.idle,
                                      enabled: !_optionsLocked,
                                      onTap: () {
                                        if (!_optionsLocked) {
                                          setState(() => _selected = i);
                                        }
                                      },
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                  ],
                                  const SizedBox(height: AppSpacing.md),
                                  if (!_submitted) ...[
                                    AppButton(
                                      label: 'Submit',
                                      variant: AppButtonVariant.success,
                                      onPressed:
                                          _selected == null || _optionsLocked
                                              ? null
                                              : () => _submit(chapter),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    // A greyed-out button with no reason reads
                                    // as broken.
                                    Text(
                                      _selected == null
                                          ? 'Pick an answer to continue'
                                          : 'Tap Submit when you are ready',
                                      textAlign: TextAlign.center,
                                      style: text.bodyMedium?.copyWith(
                                        color: AppColors.textMuted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ] else ...[
                                    _FeedbackCard(
                                      isCorrect: isCorrect,
                                      correctAnswer: question.correctAnswer,
                                      explanation:
                                          question.explanation.of(lang),
                                      englishExplanation:
                                          question.explanation.en,
                                      showTranslation: lang != 'en',
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    if (!isCorrect)
                                      AppButton(
                                        label: 'Try Again',
                                        variant: AppButtonVariant.outline,
                                        onPressed:
                                            _finishing ? null : _tryAgain,
                                      ),
                                    const SizedBox(height: AppSpacing.sm),
                                    AppButton(
                                      label: _questionIndex <
                                              chapter.quiz.length - 1
                                          ? 'Next Question'
                                          : 'Finish Quiz',
                                      variant: AppButtonVariant.blue,
                                      onPressed: _finishing
                                          ? null
                                          : () => _next(chapter),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

enum _OptionState { idle, selected, correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.index,
    required this.label,
    required this.state,
    required this.enabled,
    required this.onTap,
  });

  final int index;
  final String label;
  final _OptionState state;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (background, border) = switch (state) {
      _OptionState.idle => (AppColors.surface, AppColors.primarySoft),
      _OptionState.selected => (AppColors.primarySoft, AppColors.primary),
      _OptionState.correct => (AppColors.successSoft, AppColors.success),
      _OptionState.wrong => (AppColors.errorSoft, AppColors.error),
    };
    // A screen reader used to announce four bare answers: which one was
    // picked, and whether it was right, lived only in the tile's colour and
    // in two icons that carry no label. The letter, the selected state and
    // the verdict are now part of what the reader says; the icons are
    // decorations so their silence is not a gap.
    final verdict = switch (state) {
      _OptionState.correct => 'correct answer',
      _OptionState.wrong => 'your answer, incorrect',
      _ => null,
    };
    final letter = String.fromCharCode(65 + index);
    return Semantics(
      button: true,
      enabled: enabled,
      inMutuallyExclusiveGroup: true,
      // A radio-style list: `selected` while answering, and a checked/unchecked
      // verdict once the answer is in. After submitting, the picked option is
      // no longer "selected" - it is checked or not - so the two do not fight.
      selected: state == _OptionState.selected,
      checked: switch (state) {
        _OptionState.correct => true,
        _OptionState.wrong => false,
        _ => null,
      },
      label: verdict == null
          ? 'Option $letter: $label'
          : 'Option $letter: $label, $verdict',
      child: ExcludeSemantics(
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
            side: BorderSide(color: border, width: 1.6),
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppRadii.button),
            // A minimum height, not a fixed one: at a large font scale a
            // two-line answer needs to grow, and a 48 dp answer stays
            // comfortably tappable at the default scale.
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AccessibleLayout.minTouchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 13),
                child: Row(
                  children: [
                    // A/B/C/D marker: the list stops looking like four text
                    // fields and starts looking like a quiz.
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: switch (state) {
                          _OptionState.idle => AppColors.background,
                          _OptionState.selected => AppColors.primary,
                          _OptionState.correct => AppColors.success,
                          _OptionState.wrong => AppColors.error,
                        },
                      ),
                      child: Text(
                        letter,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: state == _OptionState.idle
                              ? AppColors.textSecondary
                              : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    if (state == _OptionState.correct)
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.success, size: 20),
                    if (state == _OptionState.wrong)
                      const Icon(Icons.cancel_rounded,
                          color: AppColors.error, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({
    required this.isCorrect,
    required this.correctAnswer,
    required this.explanation,
    required this.englishExplanation,
    required this.showTranslation,
  });

  final bool isCorrect;
  final String correctAnswer;
  final String explanation;
  final String englishExplanation;
  final bool showTranslation;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = isCorrect ? AppColors.success : AppColors.error;
    final soft = isCorrect ? AppColors.successSoft : AppColors.errorSoft;
    // Announced as one sentence. Read piecemeal, a reader visits "Correct!",
    // then an answer string with no verb, then the explanation - with no clue
    // which question they belong to.
    final spoken = isCorrect
        ? 'Correct. $explanation'
        : "Incorrect. The correct answer is $correctAnswer. $explanation";
    return Semantics(
      liveRegion: true,
      container: true,
      label: spoken,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isCorrect
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    color: color,
                    size: 28,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // The verdict word takes the rest of the line and wraps;
                  // at 200% it is 224 px wider than the card, which is the
                  // overflow this test caught after submitting.
                  Flexible(
                    child: Text(
                      isCorrect ? 'Correct!' : 'Incorrect',
                      style: text.titleLarge?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
              if (!isCorrect) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "The correct answer is: '$correctAnswer'",
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(showTranslation ? explanation : englishExplanation,
                  style: text.bodyMedium?.copyWith(height: 1.45)),
            ],
          ),
        ),
      ),
    );
  }
}
