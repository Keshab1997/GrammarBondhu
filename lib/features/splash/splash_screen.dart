import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/app_widgets.dart';
import '../home/home_shell.dart';
import '../onboarding/onboarding_screen.dart';
import 'hero_frames.dart';

/// Screen 1 — fixed chrome, moving scene.
///
/// The layout is deliberately static: wordmark, tagline, the storybook frame,
/// the CTA and the trust chip are painted once and never move. The only thing
/// that changes is the illustration *inside* the frame, which cross-fades
/// between ten near-identical renders of Rahul (see `hero_frames.dart`). Same
/// camera, same school, same light — so the screen reads as a scene in motion
/// rather than a slideshow swapping pictures.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const routeName = '/';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Content loads quietly behind the scene; nothing here animates the
    // chrome, so the screen is complete on its very first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final content = context.read<ContentController>();
      if (!content.isLoaded && !content.isLoading) {
        content.load();
      }
    });
  }

  void _begin() {
    final settings = context.read<SettingsController>().settings;
    Navigator.of(context).pushReplacementNamed(
      settings.onboardingComplete
          ? HomeShell.routeName
          : OnboardingScreen.routeName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Short phones get a smaller lockup so the frame keeps its room.
    final logoSize = (size.height * 0.038).clamp(26.0, 34.0).toDouble();

    return Scaffold(
      backgroundColor: _SplashPalette.navyDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SkyBackdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
              child: Column(
                children: [
                  BrandLogo(fontSize: logoSize, compact: true),
                  const SizedBox(height: AppSpacing.sm),
                  const Expanded(
                    child: Center(child: _StorybookFrame()),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    label: "Let's Begin",
                    icon: Icons.arrow_forward_rounded,
                    variant: AppButtonVariant.primary,
                    onPressed: _begin,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _TrustChip(),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The storybook frame
// ---------------------------------------------------------------------------

/// The illustration, framed like a printed page. The frame itself never moves;
/// only the scene inside it does.
class _StorybookFrame extends StatelessWidget {
  const _StorybookFrame();

  /// 768 × 1376 — the artwork's own ratio, so Rahul is never cropped.
  static const _artAspect = 768 / 1376;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _artAspect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _SplashPalette.navyDeep.withValues(alpha: 0.34),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const HeroFrames(),
              // A whisper of shade at the very bottom so the white keyline
              // never sits on a blown-out bright edge.
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(0, 0.86),
                      end: Alignment.bottomCenter,
                      colors: [Color(0x0013276B), Color(0x6613276B)],
                    ),
                  ),
                ),
              ),
              // Inner keyline — the "printed page" edge.
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.75),
                      width: 2.5,
                    ),
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
// Trust chip
// ---------------------------------------------------------------------------

class _TrustChip extends StatelessWidget {
  const _TrustChip();

  static const _style = TextStyle(
    color: Color(0xE6FFFFFF),
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 13, color: Color(0xE6FFFFFF)),
            SizedBox(width: 5),
            Text('Works offline', style: _style),
            SizedBox(width: 9),
            Text('·', style: _style),
            SizedBox(width: 9),
            Icon(Icons.lock_outline_rounded,
                size: 13, color: Color(0xE6FFFFFF)),
            SizedBox(width: 5),
            Text('No sign-up', style: _style),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sky
// ---------------------------------------------------------------------------

class _SplashPalette {
  const _SplashPalette._();

  static const navyDeep = Color(0xFF13276B);
  static const navyMid = Color(0xFF1F3A7A);
  static const skyMid = Color(0xFF5F9EDE);
  static const skyHigh = Color(0xFF3E7CC4);
}

class _SkyBackdrop extends StatelessWidget {
  const _SkyBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _SplashPalette.skyHigh,
                _SplashPalette.skyMid,
                Color(0xFF2E5AA8),
                _SplashPalette.navyMid,
                _SplashPalette.navyDeep,
              ],
              stops: [0.0, 0.26, 0.58, 0.82, 1.0],
            ),
          ),
        ),
        // Sun bloom behind the lockup — the scene's only warm light.
        Positioned(
          top: -130,
          left: 0,
          right: 0,
          height: 430,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.55),
                radius: 0.55,
                colors: [
                  const Color(0xFFFFF3D6).withValues(alpha: 0.55),
                  const Color(0xFFFFE3A8).withValues(alpha: 0.18),
                  Colors.white.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        // Brand glow under the CTA so the bottom never reads as empty space.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 260,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.75),
                radius: 0.8,
                colors: [
                  AppColors.primary.withValues(alpha: 0.40),
                  AppColors.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        // Soft clouds: still decoration behind the frame, no motion.
        IgnorePointer(child: CustomPaint(painter: _CloudPainter())),
      ],
    );
  }
}

class _CloudPainter extends CustomPainter {
  const _CloudPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    const puffs = <(double dx, double dy, double r, double a)>[
      (0.18, 0.10, 0.13, 0.26),
      (0.82, 0.16, 0.10, 0.20),
      (0.96, 0.36, 0.12, 0.14),
    ];
    for (final (dx, dy, r, a) in puffs) {
      final unit = size.width * r;
      paint.color = Colors.white.withValues(alpha: a);
      final c = Offset(size.width * dx, size.height * dy);
      canvas.drawCircle(c, unit, paint);
      canvas.drawCircle(
          c - Offset(unit * 0.85, -unit * 0.28), unit * 0.72, paint);
      canvas.drawCircle(
          c + Offset(unit * 0.9, -unit * 0.22), unit * 0.66, paint);
    }
  }

  @override
  bool shouldRepaint(_CloudPainter oldDelegate) => false;
}
