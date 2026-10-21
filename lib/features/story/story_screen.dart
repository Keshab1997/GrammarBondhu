import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/progress_controller.dart';
import '../../app/state/settings_controller.dart';
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
    final settings = context.watch<SettingsController>();
    if (_translationLang == 'off' && settings.showTranslations) {
      _translationLang = settings.supportLanguage;
    }

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
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                      ),
                      const Spacer(),
                      LanguageChip(
                        code: 'en',
                        label: 'English',
                        flag: '🇬🇧',
                        selected: _translationLang == 'off',
                        onTap: () => setState(() => _translationLang = 'off'),
                      ),
                      const SizedBox(width: 6),
                      LanguageChip(
                        code: 'bn',
                        label: 'বাংলা',
                        flag: '🇧🇩',
                        selected: _translationLang == 'bn',
                        onTap: () => setState(() => _translationLang = 'bn'),
                      ),
                      const SizedBox(width: 6),
                      LanguageChip(
                        code: 'hi',
                        label: 'हिन्दी',
                        flag: '🇮🇳',
                        selected: _translationLang == 'hi',
                        onTap: () => setState(() => _translationLang = 'hi'),
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
                  child: Text(
                    'Tap to Continue',
                    style: text.bodyMedium?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w600),
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
