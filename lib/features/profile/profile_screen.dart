import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app/state/progress_controller.dart';
import '../auth/google_auth.dart';
import '../auth/login_screen.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/asset_images.dart';
import '../../data/models/progress.dart';
import '../home/home_shell.dart';
import '../progress/progress_screen.dart';
import '../settings/language_selection_screen.dart';
import '../settings/settings_screen.dart';

/// Profile tab — level, quick stats and entries to settings.
/// Polished hero with large avatar, gradient banner and level pill.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final settings = context.watch<SettingsController>();
    final progressController = context.watch<ProgressController>();
    final p = progressController.progress;
    final cloudConnected = settings.cloudConnected;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
        children: [
          // Hero banner with gradient + avatar.
          AppCard(
            gradient: const LinearGradient(
              colors: [
                AppColors.primaryDark,
                AppColors.primary,
                AppColors.skyTop
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            padding: const EdgeInsets.all(AppSpacing.lg),
            elevation: false,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, Colors.white],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: SizedBox(
                      width: 78,
                      height: 78,
                      child: Image.asset(
                        'assets/illustrations/progress_avatar.webp',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const CharacterAvatar(
                            characterId: 'rahul', size: 78),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(settings.greetingName,
                          style: text.titleLarge
                              ?.copyWith(color: Colors.white, fontSize: 22)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            AppColors.goldTop,
                            AppColors.accentDark
                          ]),
                          borderRadius: BorderRadius.circular(AppRadii.chip),
                        ),
                        child: Text(
                          'Level ${p.level} · ${p.levelTitle}',
                          style: text.bodySmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      cloudConnected
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      color: cloudConnected
                          ? AppColors.success
                          : AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cloudConnected
                                ? 'Google account connected'
                                : 'Learning as a guest',
                            style: text.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            cloudConnected
                                ? _backupStatus(progressController)
                                : 'Your progress is saved on this device. '
                                    'Connect Google when you want to back it up.',
                            style: text.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (cloudConnected) ...[
                  AppButton(
                    label: progressController.cloudSyncing
                        ? 'Syncing…'
                        : 'Sync backup now',
                    icon: Icons.cloud_sync_rounded,
                    variant: AppButtonVariant.blue,
                    onPressed: progressController.cloudSyncing
                        ? null
                        : () => _syncBackup(context, settings),
                  ),
                  TextButton(
                    onPressed: () => _signOut(context),
                    child: const Text('Disconnect Google account'),
                  ),
                ] else
                  AppButton(
                    label: 'Connect Google',
                    icon: Icons.account_circle_outlined,
                    variant: AppButtonVariant.outline,
                    onPressed: () =>
                        Navigator.of(context).pushNamed(LoginScreen.routeName),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_graph_rounded,
                        color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Your Journey', style: text.titleMedium),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                AppProgressBar(
                  value: p.xpIntoLevel / UserProgress.xpPerLevel,
                  gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.skyTop]),
                ),
                const SizedBox(height: 6),
                Text(
                    '${p.xpIntoLevel} / ${UserProgress.xpPerLevel} XP to next level',
                    style: text.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _MenuTile(
            icon: Icons.insights_rounded,
            iconColor: AppColors.primary,
            label: 'My Progress',
            onTap: () =>
                Navigator.of(context).pushNamed(ProgressScreen.routeName),
          ),
          _MenuTile(
            icon: Icons.translate_rounded,
            iconColor: AppColors.success,
            label: 'Explanation language',
            trailing: settings.supportLanguage.toUpperCase(),
            onTap: () => Navigator.of(context)
                .pushNamed(LanguageSelectionScreen.routeName),
          ),
          _MenuTile(
            icon: Icons.emoji_events_rounded,
            iconColor: AppColors.accentDark,
            label: 'Achievements',
            onTap: () {
              if (!HomeShell.selectTab(context, 2)) {
                Navigator.of(context)
                    .pushNamed(HomeShell.routeName, arguments: 2);
              }
            },
          ),
          _MenuTile(
            icon: Icons.settings_outlined,
            iconColor: AppColors.purpleTop,
            label: 'Settings',
            onTap: () =>
                Navigator.of(context).pushNamed(SettingsScreen.routeName),
          ),
        ],
      ),
    );
  }

  String _backupStatus(ProgressController progress) {
    if (progress.cloudSyncing) return 'Syncing your progress…';
    if (progress.lastCloudSyncError != null) {
      return 'Your progress is safe on this device. The last backup failed; '
          'tap Sync backup now to retry.';
    }
    if (!progress.cloudConnected) {
      return 'Google is connected. Sync your local progress to this account.';
    }
    return 'Progress stays on this device and syncs after learning.';
  }

  Future<void> _syncBackup(
      BuildContext context, SettingsController settings) async {
    final userId = settings.settings.cloudAccountId;
    if (userId == null) return;
    final progress = context.read<ProgressController>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await progress.connectCloudBackup(userId: userId);
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Progress backup is up to date.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Backup could not reach Firebase. Your local progress is safe; '
              'please try again when you are online.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google?'),
        content: const Text(
          'Your progress stays on this device. The cloud copy remains in your '
          'account and stops syncing until you connect again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final settings = context.read<SettingsController>();
    final progress = context.read<ProgressController>();
    final messenger = ScaffoldMessenger.of(context);
    await GoogleAuth.instance.signOut();
    progress.disconnectCloudBackup();
    await settings.signOutToGuest();
    if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Disconnected. Progress stays on device.')),
      );
    }
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.iconColor = AppColors.primary,
  });

  final IconData icon;
  final Color iconColor;
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadii.chip),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: text.bodyLarge)),
            if (trailing != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: Text(trailing!,
                    style: text.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800, color: AppColors.primary)),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
