import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:Bloomee/core/theme/app_theme.dart';

/// Standalone TarangX Splash Screen displaying a smooth pulsing animation
/// of the TarangX logo with dynamic soundwave equalizers and luxury glowing aura.
class TarangXSplashScreen extends StatefulWidget {
  final String statusMessage;

  const TarangXSplashScreen({
    super.key,
    this.statusMessage = 'Starting TarangX...',
  });

  @override
  State<TarangXSplashScreen> createState() => _TarangXSplashScreenState();
}

class _TarangXSplashScreenState extends State<TarangXSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.20, end: 0.45).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.themeColor,
      alignment: Alignment.center,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Glowing Aura & Animated Logo ─────────────────────────────
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer radiant ambient glow
                  Container(
                    width: 140 * _scaleAnimation.value,
                    height: 140 * _scaleAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Default_Theme.accentColor2
                              .withValues(alpha: _glowAnimation.value),
                          Default_Theme.accentColor2.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.65, 1.0],
                      ),
                    ),
                  ),

                  // Smooth pulsing logo
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Default_Theme.accentColor2
                                .withValues(alpha: _glowAnimation.value * 0.6),
                            blurRadius: 28,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icons/tarangx_logo.png',
                          width: 96,
                          height: 96,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.music_note_rounded,
                              size: 48,
                              color: Default_Theme.accentColor2,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Brand Title ───────────────────────────────────────────────
              Text(
                'TARANGX',
                style: AppTheme.brandTextStyle.copyWith(
                  color: Colors.white,
                  fontSize: 22,
                  letterSpacing: 6.0,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Default_Theme.accentColor2.withValues(alpha: 0.5),
                      blurRadius: 18,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Animated Music Equalizer Bars ─────────────────────────────
              _SoundwaveBars(animationValue: _pulseController.value),

              const SizedBox(height: 14),

              // ── Status Text ───────────────────────────────────────────────
              Text(
                widget.statusMessage,
                style: Default_Theme.secondoryTextStyleMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Equalizer soundwave visualizer that bounces smoothly with rhythmic phase offsets.
class _SoundwaveBars extends StatelessWidget {
  final double animationValue;

  const _SoundwaveBars({required this.animationValue});

  @override
  Widget build(BuildContext context) {
    const barCount = 5;
    const minHeight = 6.0;
    const maxHeight = 24.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(barCount, (index) {
        // Compute staggered sinusoidal height for each bar
        final phase = (index / barCount) * math.pi * 2;
        final sineWave = (math.sin(animationValue * 2 * math.pi + phase) + 1) / 2;
        final height = minHeight + (maxHeight - minHeight) * sineWave;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2.5),
          width: 3.5,
          height: height,
          decoration: BoxDecoration(
            color: Default_Theme.accentColor2,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Default_Theme.accentColor2.withValues(alpha: 0.4),
                blurRadius: 6,
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Overlay wrapper that keeps the smooth TarangX splash screen visible during
/// initial launch until core components are initialized, then fades out cleanly.
class TarangXSplashWrapper extends StatefulWidget {
  final Widget child;

  const TarangXSplashWrapper({
    super.key,
    required this.child,
  });

  /// Tracks whether the initial app startup splash animation has already finished
  /// during this session, preventing re-displaying it on subsequent internal route changes.
  static bool hasShownInitialSplash = false;

  @override
  State<TarangXSplashWrapper> createState() => _TarangXSplashWrapperState();
}

class _TarangXSplashWrapperState extends State<TarangXSplashWrapper> {
  bool _showSplash = !TarangXSplashWrapper.hasShownInitialSplash;
  double _opacity = 1.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_showSplash) {
      _startSplashCountdown();
    }
  }

  void _startSplashCountdown() {
    // Keep splash active for at least 1350ms so user clearly perceives the smooth animation.
    _timer = Timer(const Duration(milliseconds: 1350), () {
      if (!mounted) return;
      _dismissSplash();
    });
  }

  void _dismissSplash() {
    if (!_showSplash || _opacity == 0.0) return;
    setState(() {
      _opacity = 0.0;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSplash) {
      return widget.child;
    }

    return Stack(
      children: [
        // App loads beneath the splash overlay so content is ready when it fades
        widget.child,

        // Smoothly animated splash overlay
        AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          onEnd: () {
            if (_opacity == 0.0 && mounted) {
              TarangXSplashWrapper.hasShownInitialSplash = true;
              setState(() {
                _showSplash = false;
              });
            }
          },
          child: const TarangXSplashScreen(),
        ),
      ],
    );
  }
}
