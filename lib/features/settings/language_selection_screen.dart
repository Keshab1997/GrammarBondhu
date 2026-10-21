import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';

/// Screen 18 — choose the supporting language for explanations and
/// story translations. English stays the primary learning language.
class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  static const routeName = '/language';

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  late String _selected = context.read<SettingsController>().supportLanguage;

  static const _options = [
    (code: 'en', flag: '🇬🇧', name: 'English', detail: 'Main Language'),
    (code: 'bn', flag: '🇧🇩', name: 'বাংলা', detail: 'Translation'),
    (code: 'hi', flag: '🇮🇳', name: 'हिन्दी', detail: 'Translation'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Select Language'),
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
                    'Choose your preferred language for explanations and story text.',
                    style: text.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  for (final option in _options)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: AppCard(
                        onTap: () => setState(() => _selected = option.code),
                        child: Row(
                          children: [
                            Text(option.flag,
                                style: const TextStyle(fontSize: 28)),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(option.name, style: text.titleMedium),
                                  Text(option.detail, style: text.bodyMedium),
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
