import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/progress_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/progress.dart';
import 'language_selection_screen.dart';

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
              label: 'Explanation language',
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
            _DailyGoalSetting(),
            _SettingsTile(
              icon: Icons.volume_up_rounded,
              color: AppColors.success,
              label: 'Voice narration',
              trailing: Switch(
                value: s.audioEnabled,
                activeThumbColor: AppColors.success,
                onChanged: (v) =>
                    context.read<SettingsController>().setAudioEnabled(v),
              ),
            ),
            _SettingsTile(
              icon: Icons.play_circle_outline_rounded,
              color: AppColors.primary,
              label: 'Auto-play stories',
              trailing: Switch(
                value: s.autoPlayStory,
                activeThumbColor: AppColors.primary,
                onChanged: (v) =>
                    context.read<SettingsController>().setAutoPlayStory(v),
              ),
            ),
            const _GroupHeader('Offline learning'),
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.offline_pin_rounded,
                      color: AppColors.success, size: 22),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ready to learn offline', style: text.titleMedium),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Stories, lessons and quizzes are included in the app. '
                          'No chapter downloads or account are needed.',
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const _GroupHeader('Your data'),
            _SettingsTile(
              icon: Icons.restart_alt_rounded,
              color: AppColors.error,
              label: 'Reset Progress',
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
              onTap: () => _resetProgress(context),
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

  Future<void> _resetProgress(BuildContext context) async {
    final settings = context.read<SettingsController>();
    final progress = context.read<ProgressController>();
    bool cloudConnected() => settings.cloudConnected || progress.cloudConnected;

    if (cloudConnected()) {
      await _showDisconnectBeforeReset(context);
      return;
    }

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
            child:
                const Text('Reset', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // The backup may have connected while the confirmation was open.
    if (cloudConnected()) {
      await _showDisconnectBeforeReset(context);
      return;
    }

    await progress.resetAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress reset.')),
      );
    }
  }

  Future<void> _showDisconnectBeforeReset(BuildContext context) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Disconnect Google first'),
          content: const Text(
            'Reset Progress only clears progress on this device. Disconnect '
            'Google in Profile first. Your cloud backup will not change.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );

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

/// Daily question target: a row of chips, not a slider or a text field.
///
/// The goal has to be legible at a glance and tappable without precision, and
/// the five presets are the whole range that makes sense for a learner doing
/// one chapter a day. Choosing one writes straight through to the progress
/// snapshot, so it survives a restart and the Home card reflects it.
class _DailyGoalSetting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final progress = context.watch<ProgressController>();
    final selected = progress.dailyGoalQuestions;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentDark.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: const Icon(Icons.flag_rounded,
                      color: AppColors.accentDark, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily question goal', style: text.bodyLarge),
                      const SizedBox(height: 2),
                      Text(
                        'How many quiz questions you aim to answer each day',
                        style: text.bodySmall
                            ?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            // Wrap, so the chips fold onto a second line at a large font
            // scale or on a 320 dp phone instead of overflowing.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final target in UserProgress.dailyGoalChoices)
                  _GoalChip(
                    target: target,
                    selected: target == selected,
                    onTap: () =>
                        context.read<ProgressController>().setDailyGoal(target),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({
    required this.target,
    required this.selected,
    required this.onTap,
  });

  final int target;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Announced as a choice with its state; the tick only decorates it, so
    // the chip is excluded from semantics and described in one label.
    return Semantics(
      button: true,
      selected: selected,
      label: '$target questions a day',
      child: ExcludeSemantics(
        child: Material(
          color: selected ? AppColors.accentDark : AppColors.background,
          borderRadius: BorderRadius.circular(AppRadii.chip),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.chip),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: 48,
                minWidth: 56,
              ),
              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selected) ...[
                        const Icon(Icons.check_rounded,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        '$target',
                        style: TextStyle(
                          color:
                              selected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
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
