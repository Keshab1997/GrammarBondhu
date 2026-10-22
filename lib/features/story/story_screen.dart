import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/asset_lookup.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/asset_images.dart';
import '../../data/models/chapter.dart';
import '../grammar/grammar_lesson_screen.dart';

/// Navigation arguments for the story player.
class StoryArgs {
  const StoryArgs(this.chapterId, {this.startScene = 0});

  final String chapterId;
  final int startScene;
}

/// Screens 8 & 9 — the story scene player with translation toggle.
///
/// Tap anywhere to advance the dialogue. English is always shown first;
/// the toggle adds the Bengali or Hindi translation underneath.
class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key, required this.args});

  static const routeName = '/story';

  final StoryArgs args;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  late int _sceneIndex = widget.args.startScene.clamp(0, 999);
  int _lineIndex = 0;
  StoryChoice? _chosenChoice;

  /// Local display language for translations: 'off', 'bn', 'hi'.
  String _translationLang = 'off';

  Chapter? get _chapter =>
      context.read<ContentController>().byId(widget.args.chapterId);

  void _advance() {
    final chapter = _chapter;
    if (chapter == null) return;
    final scene = chapter.scenes[_sceneIndex];
    setState(() => _chosenChoice = null);

    if (_lineIndex < scene.dialogue.length - 1) {
      setState(() => _lineIndex += 1);
      return;
    }
    // Scene finished → save resume point and move on.
    context.read<ProgressController>().openChapter(chapter.id, _sceneIndex);
    if (_sceneIndex < chapter.scenes.length - 1) {
      setState(() {
        _sceneIndex += 1;
        _lineIndex = 0;
      });
    } else {
      Navigator.of(context).pushReplacementNamed(
        GrammarLessonScreen.routeName,
        arguments: chapter.id,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _chapter;
    if (chapter == null) {
      return const Scaffold(body: Center(child: Text('Chapter not found')));
    }
    // Deliberately NOT seeded from the support language: opening a scene with
    // the translation already rendered means the learner reads the answer
    // before trying the English, which is the one thing this screen teaches.
    // The toggle is one tap away and remembers the choice for the session.

    final scene =
        chapter.scenes[_sceneIndex.clamp(0, chapter.scenes.length - 1)];
    final line = scene.dialogue[_lineIndex.clamp(0, scene.dialogue.length - 1)];
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: GestureDetector(
        onTap: _advance,
        behavior: HitTestBehavior.opaque,
        child: SceneBackground(
          backgroundId: scene.backgroundId,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xs, AppSpacing.sm, AppSpacing.sm, 0),
                  child: Row(
                    children: [
                      _GlassIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _SceneProgress(
                          scene: _sceneIndex + 1,
                          scenes: chapter.scenes.length,
                          line: _lineIndex + 1,
                          lines: scene.dialogue.length,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // One switch instead of three chips: the row used to be
                      // 135 px wider than the screen, so the last chip was
                      // always clipped.
                      _TranslationToggle(
                        lang: _translationLang,
                        onChanged: (value) =>
                            setState(() => _translationLang = value),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_chosenChoice != null)
                  _ChoiceResponseBubble(
                      choice: _chosenChoice!, lang: _translationLang),
                _DialogueBubble(
                  characterId: line.characterId,
                  line: line,
                  translationLang: _translationLang,
                ),
                if (scene.choices.isNotEmpty && _chosenChoice == null)
                  _ChoiceList(
                    choices: scene.choices,
                    lang: _translationLang,
                    onChosen: (choice) =>
                        setState(() => _chosenChoice = choice),
                  ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.touch_app_rounded,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.95)),
                      const SizedBox(width: 6),
                      Text(
                        'Tap to continue',
                        style: text.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          shadows: const [
                            Shadow(color: Color(0x99000000), blurRadius: 6),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.touch_app_rounded,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.95)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogueBubble extends StatelessWidget {
  const _DialogueBubble({
    required this.characterId,
    required this.line,
    required this.translationLang,
  });

  final String characterId;
  final DialogueLine line;
  final String translationLang;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final name = AssetLookup.characterDisplayName(characterId);
    final translation =
        translationLang == 'off' ? null : line.text.of(translationLang);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CharacterAvatar(characterId: characterId, size: 56),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: Text(
                  name,
                  style: text.bodyMedium?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.text.en,
                    style: text.bodyLarge?.copyWith(height: 1.45)),
                if (translation != null && translation != line.text.en) ...[
                  const Divider(height: AppSpacing.md),
                  // The helper line is what turns a translation from an
                  // answer key into a hint: it says what it is before you
                  // read it.
                  Text(
                    _translationLabel(translationLang),
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    translation,
                    style: text.bodyMedium?.copyWith(height: 1.45),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceList extends StatelessWidget {
  const _ChoiceList({
    required this.choices,
    required this.lang,
    required this.onChosen,
  });

  final List<StoryChoice> choices;
  final String lang;
  final ValueChanged<StoryChoice> onChosen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final choice in choices)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppButton(
                label: choice.text.of(lang == 'off' ? 'en' : lang),
                variant: AppButtonVariant.blue,
                expand: false,
                onPressed: () => onChosen(choice),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChoiceResponseBubble extends StatelessWidget {
  const _ChoiceResponseBubble({required this.choice, required this.lang});

  final StoryChoice choice;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Text(
        choice.response.of(lang == 'off' ? 'en' : lang),
        style: text.bodyLarge
            ?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// Which scene and line we are on — the story had no sense of progress at all.
class _SceneProgress extends StatelessWidget {
  const _SceneProgress({
    required this.scene,
    required this.scenes,
    required this.line,
    required this.lines,
  });

  final int scene;
  final int scenes;
  final int line;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final fraction = scenes == 0 ? 0.0 : (scene - 1) / scenes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scene $scene of $scenes',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(color: Color(0x99000000), blurRadius: 6)],
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.30),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// English · বাংলা · हिन्दी as a single segmented switch that cannot overflow.
class _TranslationToggle extends StatelessWidget {
  const _TranslationToggle({required this.lang, required this.onChanged});

  final String lang;
  final ValueChanged<String> onChanged;

  static const _options = <(String, String)>[
    ('off', 'EN'),
    ('bn', 'বাংলা'),
    ('hi', 'हिन्दी'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (value, label) in _options)
            _Segment(
              label: label,
              selected: lang == value,
              onTap: () => onChanged(value),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

String _translationLabel(String lang) => lang == 'hi'
    ? 'HINDI'
    : lang == 'bn'
        ? 'BENGALI'
        : '';
