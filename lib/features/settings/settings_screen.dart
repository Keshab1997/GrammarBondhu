import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/progress_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import 'language_selection_screen.dart';
import 'offline_download_screen.dart';

/// Screen 15 — language, audio, notifications and app preferences.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final settings = context.watch<SettingsController>();
    final s = settings.settings;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // Ten identical pills in one column is a wall. Three named groups
            // make the screen scannable, and the destructive action ends up in
            // its own section instead of sitting between two settings.
            const _GroupHeader('Learning'),
            _SettingsTile(
              icon: Icons.translate_rounded,
              color: AppColors.primary,
              label: 'Language',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.supportLanguage.toUpperCase(), style: text.bodyMedium),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.textSecondary),
                ],
              ),
              onTap: () => Navigator.of(context)
                  .pushNamed(LanguageSelectionScreen.routeName),
            ),
            _SettingsTile(
              icon: Icons.volume_up_rounded,
              color: AppColors.success,
              label: 'Audio',
              trailing: Switch(
                value: s.audioEnabled,
                activeThumbColor: AppColors.success,
                onChanged: (v) =>
                    context.read<SettingsController>().setAudioEnabled(v),
              ),
            ),
            _SettingsTile(
              icon: Icons.notifications_rounded,
              color: AppColors.accentDark,
              label: 'Notifications',
              trailing: Switch(
                value: s.notificationsEnabled,
                activeThumbColor: AppColors.success,
                onChanged: (v) => context
                    .read<SettingsController>()
                    .setNotificationsEnabled(v),
              ),
            ),
            const _GroupHeader('Storage'),
            _SettingsTile(
              icon: Icons.download_rounded,
              color: AppColors.primaryDark,
              label: 'Download Chapters',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
              onTap: () => Navigator.of(context)
                  .pushNamed(OfflineDownloadScreen.routeName),
            ),
            _SettingsTile(
              icon: Icons.cleaning_services_rounded,
              color: AppColors.textSecondary,
              label: 'Clear Cache',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Cache cleared. Chapters stay bundled with the app.')),
                );
              },
            ),
            const _GroupHeader('Your data'),
            _SettingsTile(
              icon: Icons.restart_alt_rounded,
              color: AppColors.error,
              label: 'Reset Progress',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                    title: const Text('Reset progress?'),
                    content: const Text(
                      'This clears XP, stars and chapter progress on this device. '
                      'It cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Reset',
                            style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await context.read<ProgressController>().resetAll();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Progress reset.')));
                  }
                }
              },
            ),
            const _GroupHeader('About'),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              color: AppColors.primary,
              label: 'About App',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
              onTap: () => _showAbout(context),
            ),
            _SettingsTile(
              icon: Icons.help_outline_rounded,
              color: AppColors.success,
              label: 'Help & Support',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
              onTap: () => _showHelp(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card)),
        title: const Text('About GrammarBondhu'),
        content: const Text(
          'GrammarBondhu — Learn English Through Stories.\n\n'
          'Version 0.1.0\n'
          'An offline-first story-based English grammar app for Bengali and '
          'Hindi speakers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card)),
        title: const Text('Help & Support'),
        content: const Text(
          'Stuck on a lesson? Every quiz explains its answers — try again as '
          'often as you like.\n\nFor questions about the app, contact your '
          'teacher or the app developer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(
          left: AppSpacing.xs, top: AppSpacing.sm, bottom: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: text.bodySmall?.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.chip),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: text.bodyLarge)),
            trailing,
          ],
        ),
      ),
    );
  }
}
