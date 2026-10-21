import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/brand_logo.dart';
import '../home/home_shell.dart';

/// Screen 5 — optional account, guest access always available.
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
    Navigator.of(context).pushNamedAndRemoveUntil(HomeShell.routeName, (_) => false);
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
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BrandLogo(fontSize: 30, showTagline: false),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Welcome Back!', textAlign: TextAlign.center, style: text.headlineMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Login to continue your journey',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _accountController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration('Email or Phone', Icons.person_outline_rounded),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Please enter your email or phone';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    decoration: _inputDecoration('Password', Icons.lock_outline_rounded).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (value) =>
                        (value == null || value.length < 4) ? 'Password needs 4+ characters' : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password reset arrives with the online release.'),
                          ),
                        );
                      },
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  AppButton(
                    label: 'Login',
                    variant: AppButtonVariant.blue,
                    onPressed: _signIn,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: Text('or', style: text.bodyMedium),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: 'Sign Up',
                    variant: AppButtonVariant.outline,
                    onPressed: _signIn,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextButton.icon(
                    onPressed: _continueAsGuest,
                    icon: const Icon(Icons.explore_outlined),
                    label: const Text('Continue as Guest'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surface,
      prefixIcon: Icon(icon, color: AppColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
        borderSide: BorderSide.none,
      ),
    );
  }
}
