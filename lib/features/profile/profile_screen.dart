import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/progress_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/asset_images.dart';
import '../../data/models/progress.dart';
import '../progress/progress_screen.dart';
import '../settings/language_selection_screen.dart';
import '../settings/settings_screen.dart';

/// Profile tab — level, quick stats and entries to settings.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final settings = context.watch<SettingsController>();
    final p = context.watch<ProgressController>().progress;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              const CharacterAvatar(characterId: 'rahul', size: 72),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(settings.greetingName, style: text.titleLarge),
                    Text(
                      'Level ${p.level} · ${p.levelTitle}',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Journey', style: text.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                AppProgressBar(value: p.xpIntoLevel / UserProgress.xpPerLevel),
                const SizedBox(height: 4),
                Text('${p.xpIntoLevel} / ${UserProgress.xpPerLevel} XP to next level',
                    style: text.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _MenuTile(
            icon: Icons.insights_rounded,
            label: 'My Progress',
            onTap: () => Navigator.of(context).pushNamed(ProgressScreen.routeName),
          ),
          _MenuTile(
            icon: Icons.translate_rounded,
            label: 'Language',
            trailing: settings.supportLanguage.toUpperCase(),
            onTap: () => Navigator.of(context).pushNamed(LanguageSelectionScreen.routeName),
          ),
          _MenuTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => Navigator.of(context).pushNamed(SettingsScreen.routeName),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: text.bodyLarge)),
            if (trailing != null) ...[
              Text(trailing!, style: text.bodyMedium),
              const SizedBox(width: AppSpacing.sm),
            ],
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
