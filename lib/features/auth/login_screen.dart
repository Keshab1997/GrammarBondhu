import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/brand_logo.dart';
import '../home/home_shell.dart';

/// Screen 5 — optional account, guest access always available.
///
/// Layout: an illustrated hero band with rounded shoulders, then a white sheet
/// that lifts over it. The wordmark lives *on the sheet*, not on the artwork —
/// gold type over a gold book cover is unreadable, which is what the old
/// overlay did.
///
/// Guest access is a first-class action here, not a footnote: the app is
/// guest-first by design (see AGENTS.md invariants), so it gets a full-width
/// tonal button instead of a small text link at the very bottom.
///
/// v1 has no backend: "login" creates a local profile on the device.
/// Everything works identically in guest mode.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context)
        .pushNamedAndRemoveUntil(HomeShell.routeName, (_) => false);
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final raw = _accountController.text.trim();
    // Use the part before @ / the phone label as the friendly display name.
    final name = raw.contains('@') ? raw.split('@').first : raw;
    await context.read<SettingsController>().signInLocally(name);
    _goHome();
  }

  Future<void> _continueAsGuest() async {
    await context.read<SettingsController>().continueAsGuest();
    _goHome();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Tall phones get a taller banner, but never so tall that the form falls
    // below the fold on a small screen.
    // On short phones the form has to fit under the banner without the guest
    // path disappearing below the fold, so both the banner and the spacing
    // tighten instead.
    final compact = size.height < 700;
    final heroHeight =
        (size.height * (compact ? 0.215 : 0.26)).clamp(140.0, 230.0).toDouble();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: GestureDetector(
        // Tapping the sheet dismisses the keyboard — an auth form that traps
        // the keyboard has no obvious way out.
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _HeroBanner(height: heroHeight),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
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
                    AppSpacing.lg,
                  ),
                  child: _Form(
                    compact: compact,
                    formKey: _formKey,
                    accountController: _accountController,
                    passwordController: _passwordController,
                    obscure: _obscure,
                    onToggleObscure: () => setState(() => _obscure = !_obscure),
                    onSubmit: _signIn,
                    onGuest: _continueAsGuest,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

/// The illustrated band at the top.
///
/// `kHeroIsCutout` is the one switch to flip when the artwork arrives with a
/// transparent background: a cut-out is laid out whole over the sky gradient
/// (`contain`) instead of being cropped (`cover`), so Rahul/the owl is never
/// cropped at the shoulders by a wide phone.
const bool kHeroIsCutout = false;

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppRadii.sheet),
      ),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Sky wash: visible around a cut-out, and the fallback if the
            // artwork ever fails to decode.
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
              fit: kHeroIsCutout ? BoxFit.contain : BoxFit.cover,
              alignment:
                  kHeroIsCutout ? Alignment.bottomCenter : Alignment.center,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            // A gentle bottom scrim so the white sheet's shadow has something
            // to sit on and the art does not end in a hard line.
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0, 0.55),
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00FFFFFF), Color(0x38FFFFFF)],
                  ),
                ),
              ),
            ),
            // Back out to the previous screen without committing to anything.
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 12,
              child: _RoundIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
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
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: const Color(0x33000000),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 20, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form
// ---------------------------------------------------------------------------

class _Form extends StatelessWidget {
  const _Form({
    required this.compact,
    required this.formKey,
    required this.accountController,
    required this.passwordController,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onGuest,
  });

  /// True on short phones: trims paddings so the guest button stays visible.
  final bool compact;
  final GlobalKey<FormState> formKey;
  final TextEditingController accountController;
  final TextEditingController passwordController;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onGuest;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AutofillGroup(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand on the sheet: readable at any artwork, no scrim needed.
            Center(
              child: BrandLogo(
                fontSize: compact ? 21 : 24,
                compact: true,
                showTagline: false,
              ),
            ),
            SizedBox(height: compact ? AppSpacing.sm + 2 : AppSpacing.md),
            Text(
              'Welcome Back!',
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs + 2),
            Text(
              'Login to continue your journey',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
            TextFormField(
              controller: accountController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              decoration: _decoration(
                label: 'Email or Phone',
                icon: Icons.alternate_email_rounded,
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Please enter your email or phone';
                return null;
              },
            ),
            SizedBox(height: compact ? AppSpacing.sm + 2 : AppSpacing.md - 4),
            TextFormField(
              controller: passwordController,
              obscureText: obscure,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => onSubmit(),
              decoration: _decoration(
                label: 'Password',
                icon: Icons.lock_outline_rounded,
              ).copyWith(
                suffixIcon: IconButton(
                  tooltip: obscure ? 'Show password' : 'Hide password',
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  onPressed: onToggleObscure,
                ),
              ),
              validator: (value) => (value == null || value.length < 4)
                  ? 'Password needs 4+ characters'
                  : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Password reset arrives with the online release.'),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: text.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                child: const Text('Forgot Password?'),
              ),
            ),
            SizedBox(height: compact ? AppSpacing.xs : AppSpacing.sm),
            AppButton(
              label: 'Login',
              variant: AppButtonVariant.blue,
              onPressed: onSubmit,
            ),
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
            Row(
              children: [
                const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md - 4),
                  child: Text(
                    'or',
                    style: text.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ),
                const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              ],
            ),
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
            AppButton(
              label: 'Sign Up',
              variant: AppButtonVariant.outline,
              onPressed: onSubmit,
            ),
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md - 4),
            // Guest is a real destination, so it gets a real button.
            _GuestButton(onTap: onGuest),
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
            Text(
              'No account needed — guest mode keeps your progress on this '
              'device.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration({required String label, required IconData icon}) {
    return InputDecoration(
      hintText: label,
      hintStyle: const TextStyle(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.md + 2),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 12, right: 8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadii.xs + 2),
          ),
          child: Icon(icon, size: 18, color: AppColors.primary),
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 32),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: const BorderSide(color: Color(0xFFE6EDF7)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: const BorderSide(color: AppColors.error, width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    );
  }
}

/// Tonal button for the guest path: quieter than the primary CTA, louder than
/// a text link.
class _GuestButton extends StatelessWidget {
  const _GuestButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(AppRadii.button),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.button),
        child: SizedBox(
          height: 54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.explore_outlined,
                  size: 19, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Continue as Guest',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
