import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/app_widgets.dart';
import '../onboarding/onboarding_screen.dart';
import '../home/home_shell.dart';

/// Screen 1 — a short, scripted title sequence rather than a static poster.
///
/// It is built as a beat sheet: one timeline controller drives every element
/// on its own [Interval], so the screen plays like a video instead of
/// everything fading in together.
///
///   0.00–0.90  sky wakes: sun bloom, clouds slide in
///   0.15–1.45  the storybook card rises and settles with a soft overshoot
///   0.90–1.50  cap badge pops
///   1.15–1.85  wordmark scales up, tagline pill springs in behind it
///   1.85–2.50  CTA rises, one shine sweep crosses it
///   2.30–2.80  trust chip fades in
///   2.60–      ambient motion only: character breathes, clouds drift,
///              sparkles twinkle
///
/// Every animation here is finite on purpose. A looping controller never lets
/// `pumpAndSettle` settle, which turns every widget test that pumps this app
/// into a timeout.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const routeName = '/';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  /// The script. One clock, many beats.
  late final AnimationController _timeline = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );

  /// Idle life after the script ends. Runs once — see the class comment.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  );

  static const _artAspect = 768 / 1376;

  late final Animation<double> _skyIn;
  late final Animation<double> _cloudsIn;
  late final Animation<double> _cardIn;
  late final Animation<double> _badgeIn;
  late final Animation<double> _wordmarkIn;
  late final Animation<double> _taglineIn;
  late final Animation<double> _ctaIn;
  late final Animation<double> _trustIn;

  @override
  void initState() {
    super.initState();

    Animation<double> beat(double begin, double end, [Curve? curve]) =>
        CurvedAnimation(
          parent: _timeline,
          curve: Interval(
            begin,
            end,
            curve: curve ?? Curves.easeOutCubic,
          ),
        );

    _skyIn = beat(0.00, 0.30);
    _cloudsIn = beat(0.00, 0.35, Curves.easeOut);
    _cardIn = beat(0.15, 0.48, Curves.easeOutBack);
    _badgeIn = beat(0.30, 0.50, Curves.elasticOut);
    _wordmarkIn = beat(0.38, 0.62, Curves.easeOutCubic);
    _taglineIn = beat(0.50, 0.72, Curves.easeOutBack);
    _ctaIn = beat(0.62, 0.84, Curves.easeOutCubic);
    _trustIn = beat(0.77, 0.93, Curves.easeOut);

    _timeline.forward();
    _ambient.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final content = context.read<ContentController>();
      if (!content.isLoaded && !content.isLoading) {
        content.load();
      }
    });
  }

  @override
  void dispose() {
    _timeline.dispose();
    _ambient.dispose();
    super.dispose();
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
    // Short phones get a smaller lockup so the card keeps its room.
    final logoSize = (size.height * 0.038).clamp(26.0, 34.0).toDouble();

    return Scaffold(
      backgroundColor: _SplashPalette.navyDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ---------- Layer 1: the sky ----------
          FadeTransition(
            opacity: _skyIn,
            child: const _SkyBackdrop(),
          ),

          // ---------- Layer 2: drifting clouds (behind everything else) ----------
          FadeTransition(
            opacity: _cloudsIn,
            child: AnimatedBuilder(
              animation: _ambient,
              builder: (context, _) => CustomPaint(
                painter: _CloudPainter(progress: _ambient.value),
              ),
            ),
          ),

          // ---------- Layer 3: the storybook card ----------
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
              child: Column(
                children: [
                  _Lockup(
                    logoSize: logoSize,
                    badgeIn: _badgeIn,
                    wordmarkIn: _wordmarkIn,
                    taglineIn: _taglineIn,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: Center(
                      child: _StorybookCard(
                        entrance: _cardIn,
                        ambient: _ambient,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _Dock(
                    ctaIn: _ctaIn,
                    trustIn: _trustIn,
                    onBegin: _begin,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),

          // ---------- Layer 4: sparkles in front ----------
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _ambient,
              builder: (context, _) => CustomPaint(
                painter: _SparklePainter(progress: _ambient.value),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The lockup
// ---------------------------------------------------------------------------

class _Lockup extends StatelessWidget {
  const _Lockup({
    required this.logoSize,
    required this.badgeIn,
    required this.wordmarkIn,
    required this.taglineIn,
  });

  final double logoSize;
  final Animation<double> badgeIn;
  final Animation<double> wordmarkIn;
  final Animation<double> taglineIn;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([badgeIn, wordmarkIn]),
      builder: (context, child) => Transform.scale(
        // Badge pops first (elastic), the wordmark then grows into place.
        scale: 0.72 + 0.28 * badgeIn.value,
        child: Opacity(
          opacity: wordmarkIn.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - wordmarkIn.value)),
            child: child,
          ),
        ),
      ),
      child: BrandLogo(
        fontSize: logoSize,
        compact: true,
        // The tagline rides in on its own beat instead of with the wordmark.
        taglineReveal: taglineIn,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The storybook card
// ---------------------------------------------------------------------------

/// The hero art framed like a storybook portrait: it keeps the artwork's own
/// aspect ratio, so the character is always whole — head to shoes — instead of
/// being cropped by whatever the phone's aspect happens to be.
class _StorybookCard extends StatelessWidget {
  const _StorybookCard({required this.entrance, required this.ambient});

  final Animation<double> entrance;
  final Animation<double> ambient;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([entrance, ambient]),
      builder: (context, child) {
        final e = entrance.value;
        // Two full breath cycles, ending where it started, so the idle motion
        // stops cleanly instead of freezing mid-pose.
        final breathe = math.sin(ambient.value * math.pi * 4) * 1.6;
        return Transform.translate(
          offset: Offset(0, 40 * (1 - e) + breathe),
          child: Transform.scale(
            scale: (0.86 + 0.14 * e) * (1 + 0.005 * e),
            child: Opacity(opacity: e.clamp(0.0, 1.0), child: child),
          ),
        );
      },
      child: AspectRatio(
        aspectRatio: _SplashScreenState._artAspect,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: _SplashPalette.navyDeep.withValues(alpha: 0.34),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.45),
                blurRadius: 2,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The art, whole. No fade at the bottom: once the frame
                // supplies the edge, fading the scene inside it just reads as
                // fog over the character's feet.
                ColoredBox(
                  color: _SplashPalette.navyDeep,
                  child: Image.asset(
                    'assets/illustrations/splash_hero.webp',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                // A whisper of shade at the very bottom so the white keyline
                // never sits on a blown-out bright edge.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(0, 0.86),
                      end: Alignment.bottomCenter,
                      colors: [Color(0x0013276B), Color(0x6613276B)],
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The dock
// ---------------------------------------------------------------------------

class _Dock extends StatelessWidget {
  const _Dock({
    required this.ctaIn,
    required this.trustIn,
    required this.onBegin,
  });

  final Animation<double> ctaIn;
  final Animation<double> trustIn;
  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctaIn,
      builder: (context, child) => Opacity(
        opacity: ctaIn.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 26 * (1 - ctaIn.value)),
          child: child,
        ),
      ),
      child: Column(
        children: [
          AppButton(
            label: "Let's Begin",
            icon: Icons.arrow_forward_rounded,
            variant: AppButtonVariant.primary,
            shine: true,
            onPressed: onBegin,
          ),
          const SizedBox(height: AppSpacing.sm),
          FadeTransition(opacity: trustIn, child: const _TrustChip()),
        ],
      ),
    );
  }
}

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
// Sky, clouds, sparkles
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
        // Brand glow under the dock so the bottom never reads as empty space.
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
      ],
    );
  }
}

/// A handful of soft clouds that drift a little, then rest. `progress` runs
/// 0→1 once; the drift is one full sine period so the clouds park where they
/// started rather than stopping mid-slide.
class _CloudPainter extends CustomPainter {
  const _CloudPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final drift = math.sin(progress * math.pi * 2);
    final puffs = <(double dx, double dy, double r, double drift, double a)>[
      (0.18, 0.10, 0.13, 26, 0.30),
      (0.82, 0.16, 0.10, -20, 0.24),
      (0.06, 0.30, 0.09, 14, 0.18),
      (0.95, 0.36, 0.12, -16, 0.16),
    ];
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    for (final (dx, dy, r, d, a) in puffs) {
      final unit = size.width * r;
      paint.color =
          Colors.white.withValues(alpha: a * (0.75 + 0.25 * (1 - drift.abs())));
      final cx = size.width * dx + d * drift;
      final cy = size.height * dy;
      // Three lobes make a cloud silhouette without an asset.
      canvas.drawCircle(Offset(cx, cy), unit, paint);
      canvas.drawCircle(
          Offset(cx - unit * 0.85, cy + unit * 0.28), unit * 0.72, paint);
      canvas.drawCircle(
          Offset(cx + unit * 0.9, cy + unit * 0.22), unit * 0.66, paint);
    }
  }

  @override
  bool shouldRepaint(_CloudPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Three sparkles that twinkle three times and settle. Positioned clear of the
/// lockup so they never sit on top of the wordmark.
class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final spots = <(double x, double y, double r, double phase)>[
      (0.12, 0.30, 7, 0.0),
      (0.88, 0.44, 5.5, 0.35),
      (0.20, 0.62, 4.5, 0.7),
      (0.80, 0.70, 6, 0.15),
    ];
    for (final (x, y, r, phase) in spots) {
      final pulse = (math.sin((progress * 3 + phase) * math.pi * 2) + 1) / 2;
      final radius = r * (0.55 + 0.45 * pulse);
      final alpha = 0.25 + 0.55 * pulse;
      _drawSparkle(canvas, Offset(size.width * x, size.height * y), radius,
          Colors.white.withValues(alpha: alpha));
    }
  }

  void _drawSparkle(Canvas canvas, Offset c, double r, Color color) {
    final paint = Paint()..color = color;
    final glow = Paint()
      ..color = color.withValues(alpha: color.a * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    // Four-point star: two crossed tapered diamonds.
    for (final angle in [0.0, math.pi / 2]) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(angle);
      final path = Path()
        ..moveTo(0, -r)
        ..quadraticBezierTo(r * 0.16, -r * 0.16, r, 0)
        ..quadraticBezierTo(r * 0.16, r * 0.16, 0, r)
        ..quadraticBezierTo(-r * 0.16, r * 0.16, -r, 0)
        ..quadraticBezierTo(-r * 0.16, -r * 0.16, 0, -r)
        ..close();
      canvas.drawPath(path, glow);
      canvas.drawPath(path, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
