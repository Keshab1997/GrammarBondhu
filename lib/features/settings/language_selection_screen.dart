import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/accessible_layout.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/localized_text.dart';

const _languages = [
  (
    code: 'en',
    flag: '🇬🇧',
    icon: 'flag_en',
    name: 'English',
    spoken: 'English explanation',
    detail: 'English-only explanations'
  ),
  (
    code: 'bn',
    flag: '🇧🇩',
    icon: 'flag_bn',
    name: 'বাংলা',
    spoken: 'Bengali explanation',
    detail: 'Bengali explanations and translations'
  ),
  (
    code: 'hi',
    flag: '🇮🇳',
    icon: 'flag_hi',
    name: 'हिन्दी',
    spoken: 'Hindi explanation',
    detail: 'Hindi explanations and translations'
  ),
];

/// A preference on onboarding, a temporary choice in a quiz. The caller owns
/// the selection so comparing explanations never changes the learner's default.
class ExplanationLanguagePicker extends StatelessWidget {
  const ExplanationLanguagePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.translations,
    this.englishLabel = 'English',
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final LocalizedText? translations;
  final String englishLabel;

  @override
  Widget build(BuildContext context) {
    final active = translations?.has(selected) == false ? 'en' : selected;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final language in _languages)
          if (translations?.has(language.code) ?? true)
            Semantics(
              container: true,
              button: true,
              selected: active == language.code,
              inMutuallyExclusiveGroup: true,
              excludeSemantics: true,
              label: language.spoken,
              onTap: () => onChanged(language.code),
              child: OutlinedButton(
                onPressed: () => onChanged(language.code),
                style: OutlinedButton.styleFrom(
                  minimumSize:
                      const Size.square(AccessibleLayout.minTouchTarget),
                  visualDensity: VisualDensity.standard,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: active == language.code
                      ? Colors.white
                      : AppColors.primary,
                  backgroundColor: active == language.code
                      ? AppColors.primary
                      : AppColors.primarySoft,
                ),
                child:
                    Text(language.code == 'en' ? englishLabel : language.name),
              ),
            ),
      ],
    );
  }
}

/// Screen 18 — choose the supporting language for explanations and
/// story translations. English stays the primary learning language.
/// Uses 3D circular flag icons matching the storyboard design.
class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  static const routeName = '/language';

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  static const _previewNote = LocalizedText(
    en: 'Use am with I.',
    bn: 'I-এর সঙ্গে am বসে।',
    hi: 'I के साथ am लगता है।',
  );

  late String _selected = context.read<SettingsController>().supportLanguage;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Explanation language'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Text(
                    'English stays the main learning language. Choose whether supporting explanations and story translations appear in English, Bengali or Hindi.',
                    style: text.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  for (final option in _languages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Semantics(
                        container: true,
                        button: true,
                        selected: _selected == option.code,
                        inMutuallyExclusiveGroup: true,
                        excludeSemantics: true,
                        label: '${option.name}. ${option.detail}',
                        onTap: () => setState(() => _selected = option.code),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              minHeight: AccessibleLayout.minTouchTarget),
                          child: AppCard(
                            onTap: () =>
                                setState(() => _selected = option.code),
                            child: Row(
                              children: [
                                // 3D circular flag icon (storyboard frame 18).
                                ClipOval(
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Image.asset(
                                      'assets/icons/${option.icon}.webp',
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              AppColors.primary,
                                              AppColors.skyTop
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(22),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(option.flag,
                                            style:
                                                const TextStyle(fontSize: 22)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(option.name,
                                          style: text.titleMedium),
                                      Text(option.detail,
                                          style: text.bodyMedium),
                                    ],
                                  ),
                                ),
                                Icon(
                                  _selected == option.code
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: _selected == option.code
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Preview', style: text.titleMedium),
                        const SizedBox(height: AppSpacing.sm),
                        Text('I am holding my umbrella.',
                            style: text.bodyLarge),
                        Text(_previewNote.of(_selected),
                            style: text.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: AppButton(
                label: 'Continue',
                variant: AppButtonVariant.blue,
                onPressed: () async {
                  await context
                      .read<SettingsController>()
                      .setSupportLanguage(_selected);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
