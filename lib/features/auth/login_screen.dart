import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/progress_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/brand_logo.dart';
import '../home/home_shell.dart';
import 'google_auth.dart';

/// Profile setup — guest or local name by default, with an optional Google
/// sign-in for learners who want their progress on an account. Nothing here
/// runs at launch: the account sheet only opens on a tap.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();

  /// True while Google's account sheet or the credential exchange is running,
  /// so a double tap cannot open two sheets.
  bool _signingIn = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _nameController.text.trim();
    final settings = context.read<SettingsController>();
    if (name.isEmpty) {
      await settings.continueAsGuest();
    } else {
      await settings.signInLocally(name);
    }
    if (!mounted) return;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(HomeShell.routeName, (_) => false);
  }

  Future<void> _signInWithGoogle() async {
    if (_signingIn) return;
    setState(() => _signingIn = true);

    // Captured before the first await: the widget may be gone by the time the
    // account sheet closes.
    final settings = context.read<SettingsController>();
    final progress = context.read<ProgressController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final credential = await GoogleAuth.instance.signIn();
      final user = credential.user;
      if (user == null) throw const SignInUnavailable();
      final name = user.displayName?.trim();
      await settings.signInWithGoogle(
        displayName: (name == null || name.isEmpty) ? user.email ?? '' : name,
        userId: user.uid,
      );
      var backupSucceeded = false;
      try {
        await progress.connectCloudBackup(userId: user.uid);
        backupSucceeded = true;
      } catch (_) {
        // Authentication still succeeds; profile offers a retry for backup.
      }
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(backupSucceeded
            ? 'Google connected. Your progress is backed up.'
            : 'Google connected, but backup could not finish. Retry from Profile.'),
      ));
      navigator.pushNamedAndRemoveUntil(HomeShell.routeName, (_) => false);
    } on SignInCancelled {
      // Closing the account sheet is a choice, not an error worth a message.
    } on SignInUnavailable {
      messenger.showSnackBar(const SnackBar(
        content: Text(
          'Google sign-in needs this build\'s Firebase setup. You can still '
          'continue as a guest.',
        ),
      ));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not sign in with Google. Please try again.'),
      ));
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;
    final heroHeight = (MediaQuery.sizeOf(context).height * 0.24)
        .clamp(140.0, 220.0)
        .toDouble();
    final text = Theme.of(context).textTheme;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final fieldRadius = BorderRadius.circular(AppRadii.chip);
    final fieldBorder = OutlineInputBorder(
      borderRadius: fieldRadius,
      borderSide: const BorderSide(color: AppColors.textMuted),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: Column(
          children: [
            SizedBox(
              height: heroHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.skyBottom, AppColors.skyTop],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/illustrations/login_hero.webp',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: AppSpacing.xxl + AppSpacing.md,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.surface.withValues(alpha: 0),
                              AppColors.surface,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
                    left: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.cardSoft,
                      ),
                      child: Material(
                        color: AppColors.surface,
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox.square(
                          dimension: 48,
                          child: IconButton(
                            tooltip: 'Back',
                            style: IconButton.styleFrom(
                              minimumSize: const Size.square(48),
                              foregroundColor: AppColors.primaryDeeper,
                            ),
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -24),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadii.sheet),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 24,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  compact ? AppSpacing.md : AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: BrandLogo(
                        fontSize: compact ? 21 : 24,
                        compact: true,
                        showTagline: false,
                      ),
                    ),
                    SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
                    Text(
                      'Make it yours',
                      textAlign: TextAlign.center,
                      style: text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'No account needed. Your learning progress stays on this device.',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      alignment: WrapAlignment.center,
                      children: [
                        _ReassuranceChip(
                          icon: Icons.wifi_off_rounded,
                          label: 'Offline-ready',
                        ),
                        _ReassuranceChip(
                          icon: Icons.lock_outline_rounded,
                          label: 'Private on device',
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      maxLength: 32,
                      onSubmitted: (_) => _continue(),
                      decoration: InputDecoration(
                        labelText: 'Your name (optional)',
                        hintText: 'What should we call you?',
                        hintMaxLines: 2,
                        floatingLabelBehavior: largeText
                            ? FloatingLabelBehavior.always
                            : FloatingLabelBehavior.auto,
                        prefixIcon: largeText
                            ? null
                            : const Icon(Icons.person_outline_rounded),
                        prefixIconColor: AppColors.textSecondary,
                        hintStyle:
                            const TextStyle(color: AppColors.textSecondary),
                        labelStyle:
                            const TextStyle(color: AppColors.textSecondary),
                        floatingLabelStyle:
                            const TextStyle(color: AppColors.primaryDeeper),
                        counterStyle:
                            const TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.background,
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: fieldBorder.copyWith(
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      variant: AppButtonVariant.blue,
                      onPressed: _signingIn ? null : _continue,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        alignment: Alignment.center,
                      ),
                      onPressed: _signingIn
                          ? null
                          : () {
                              _nameController.clear();
                              _continue();
                            },
                      child: const Text(
                        'Continue without a name',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Expanded(child: _AlternativeRule()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: text.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Expanded(child: _AlternativeRule()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label:
                          _signingIn ? 'Signing in…' : 'Continue with Google',
                      icon: Icons.account_circle_outlined,
                      variant: AppButtonVariant.outline,
                      onPressed: _signingIn ? null : _signInWithGoogle,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Your profile stays on this device. Google sign-in is '
                      'optional and never asked for at launch.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReassuranceChip extends StatelessWidget {
  const _ReassuranceChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primaryDeeper),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primaryDeeper,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlternativeRule extends StatelessWidget {
  const _AlternativeRule();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.textMuted.withValues(alpha: 0.35),
    );
  }
}
