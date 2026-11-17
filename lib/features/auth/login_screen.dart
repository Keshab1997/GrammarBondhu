import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final credential = await GoogleAuth.instance.signIn();
      final user = credential.user;
      if (user == null) throw const SignInUnavailable();
      final name = user.displayName?.trim();
      await settings.signInWithGoogle(
        (name == null || name.isEmpty) ? user.email ?? '' : name,
      );
      if (!mounted) return;
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

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SingleChildScrollView(
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
                        colors: [Color(0xFFBDE6FF), Color(0xFF7FC4F5)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/illustrations/login_hero.webp',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 8,
                    left: 12,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
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
                        prefixIcon: const Icon(Icons.person_outline_rounded),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadii.button),
                          borderSide: BorderSide.none,
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
                      onPressed: _signingIn
                          ? null
                          : () {
                              _nameController.clear();
                              _continue();
                            },
                      child: const Text('Continue without a name'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: text.bodySmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppButton(
                      label: _signingIn ? 'Signing in…' : 'Continue with Google',
                      icon: Icons.account_circle_outlined,
                      variant: AppButtonVariant.outline,
                      onPressed: _signingIn ? null : _signInWithGoogle,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Your profile stays on this device. Google sign-in is '
                      'optional and never asked for at launch.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall?.copyWith(color: AppColors.textMuted),
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
