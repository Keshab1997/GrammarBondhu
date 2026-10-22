import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/state/content_controller.dart';
import '../../app/state/settings_controller.dart';
import '../../app/theme/app_theme.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/app_widgets.dart';
import '../onboarding/onboarding_screen.dart';
import '../home/home_shell.dart';

/// Screen 1 — branding, hero character, "Let's Begin".
///
/// Composition: the artwork is laid out at its own aspect ratio from the top
/// of the screen, so the whole scene — head to shoes — is always visible. The
/// band under it is not a flat slab: a scrim starting 150 dp *inside* the
/// artwork fades the stone path into brand navy, so the artwork and the CTA
/// dock read as one continuous image rather than an image with a cut edge.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const routeName = '/';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  /// Slow settle on the artwork: a still illustration that breathes keeps the
  /// first screen from looking like a static poster.
  late final AnimationController _breath = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 6000))
    ..forward();
  late final Animation<double> _fade;
  late final Animation<Offset> _logoSlide;
  late final Animation<Offset> _btnSlide;
  late final Animation<double> _trustFade;

  /// `assets/illustrations/splash_hero.webp` is 768 × 1376.
  static const _artAspect = 1376 / 768;

  /// Sky the artwork opens on, and the navy the dock settles into. The scrim
  /// also passes through `0xFF5A4E46` — the average colour of the artwork's
  /// last row (the stone path) — which is what makes the seam invisible.
  static const _skyMid = Color(0xFF5F9EDE);
  static const _navyDeep = Color(0xFF13276B);

  @override
  void initState() {
    super.initState();
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));
    _btnSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ac,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
    ));
    _trustFade = CurvedAnimation(
      parent: _ac,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );
    _ac.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final content = context.read<ContentController>();
      if (!content.isLoaded && !content.isLoading) {
        content.load();
      }
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    _breath.dispose();
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
    // Single-screen fit on short and tall phones alike.
    final logoSize = (size.height * 0.042).clamp(30.0, 38.0).toDouble();

    return Scaffold(
      backgroundColor: _navyDeep,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Where the artwork's bottom edge lands on this screen.
          final artBottom = (constraints.maxWidth * _artAspect)
              .clamp(0.0, constraints.maxHeight);
          // The colour bridge starts inside the artwork, at the point where
          // the artwork's own alpha starts to fall away.
          final scrimTop = (artBottom - 240).clamp(0.0, constraints.maxHeight);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Base wash: sky at the top, brand navy under the dock. Also the
              // fallback if the artwork ever fails to decode.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF3E7CC4),
                      _skyMid,
                      Color(0xFF2E5AA8),
                      _navyDeep,
                    ],
                    stops: [0.0, 0.35, 0.78, 1.0],
                  ),
                ),
              ),

              // The scene, whole and uncropped, pinned to the top, with its
              // own last 240 dp faded to alpha. A colour band laid *over* the
              // art still leaves the art's edge legible; fading the pixels
              // themselves is what actually removes the cut under his shoes.
              ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [
                    Colors.white,
                    Colors.white,
                    Colors.transparent
                  ],
                  stops: [
                    0.0,
                    ((artBottom - 240) / constraints.maxHeight).clamp(0.0, 1.0),
                    (artBottom / constraints.maxHeight).clamp(0.0, 1.0),
                  ],
                ).createShader(rect),
                child: AnimatedBuilder(
                  animation: _breath,
                  builder: (context, child) => Transform.scale(
                    // 1.03 → 1.0 with a long ease; invisible frame to frame,
                    // alive over six seconds.
                    scale:
                        1.03 - 0.03 * Curves.easeInOut.transform(_breath.value),
                    alignment: Alignment.topCenter,
                    child: child,
                  ),
                  child: Image.asset(
                    'assets/illustrations/splash_hero.webp',
                    fit: BoxFit.fitWidth,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

              // Colour bridge under the faded artwork: warms the stone path
              // into brand navy so the dock never reads as an empty slab.
              Positioned(
                top: scrimTop,
                left: 0,
                right: 0,
                bottom: 0,
                child: const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        // A hint of the path's own stone tone (not a full
                        // wash — that read as brown haze over the meadow).
                        colors: [
                          Color(0x005A4E46),
                          Color(0x405A4E46),
                          Color(0xCC1F3A7A),
                          _navyDeep,
                        ],
                        stops: [0.0, 0.32, 0.70, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // A soft brand glow behind the CTA so the dock has depth instead
              // of reading as empty space.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 220,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, 0.55),
                        radius: 0.85,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.38),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Soft halo *behind the wordmark* instead of a full-width
              // feather: the old band washed the treetops in the corners and
              // made the whole top of the scene look hazy.
              Positioned(
                top: -60,
                left: 0,
                right: 0,
                height: 250,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, 0.35),
                        radius: 0.75,
                        // Very light: the wordmark already carries a white
                        // stroke, so this only needs to lift it off the sky —
                        // a stronger halo turns into a visible white cloud.
                        colors: [
                          Colors.white.withValues(alpha: 0.16),
                          Colors.white.withValues(alpha: 0.05),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              FadeTransition(
                opacity: _fade,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      children: [
                        SlideTransition(
                          position: _logoSlide,
                          // Compact one-line lockup: stays in the sky band of
                          // the artwork, clear of the hero character's head.
                          child: BrandLogo(fontSize: logoSize, compact: true),
                        ),
                        const Spacer(),
                        SlideTransition(
                          position: _btnSlide,
                          child: Column(
                            children: [
                              AppButton(
                                label: "Let's Begin",
                                icon: Icons.arrow_forward_rounded,
                                variant: AppButtonVariant.primary,
                                shine: true,
                                onPressed: _begin,
                              ),
                              const SizedBox(height: AppSpacing.sm + 2),
                              FadeTransition(
                                opacity: _trustFade,
                                child: const _TrustLine(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One quiet line of reassurance under the CTA — the first thing a parent
/// wants to know about a kids' learning app.
class _TrustLine extends StatelessWidget {
  const _TrustLine();

  static const _style = TextStyle(
    color: Color(0xE6FFFFFF),
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  @override
  Widget build(BuildContext context) {
    // A glass chip anchors the line: bare text on a gradient looks like it
    // drifted up from the CTA instead of being part of the design.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
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
