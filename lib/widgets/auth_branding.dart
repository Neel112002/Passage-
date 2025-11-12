import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated gradient background with a subtle moving radial glow.
class AuthAnimatedBackground extends StatefulWidget {
  const AuthAnimatedBackground({super.key});

  @override
  State<AuthAnimatedBackground> createState() => _AuthAnimatedBackgroundState();
}

class _AuthAnimatedBackgroundState extends State<AuthAnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, _) {
        final t = _bgController.value * 2 * math.pi;
        final dx = math.sin(t) * 0.8;
        final dy = math.cos(t) * 0.8;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Base gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF6F3FF), Color(0xFFE7F7FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Moving glow
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(dx, dy),
                    radius: 1.2,
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                    stops: const [0, 1],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Brand header with bounce-in logo, gentle pulse, and shimmer text for "Passage".
class AuthBrandHeader extends StatefulWidget {
  const AuthBrandHeader({
    super.key,
    this.iconSize = 80,
    this.titleStyle,
    this.subtitle,
    this.subtitleStyle,
  });

  final double iconSize;
  final TextStyle? titleStyle;
  final String? subtitle;
  final TextStyle? subtitleStyle;

  @override
  State<AuthBrandHeader> createState() => _AuthBrandHeaderState();
}

class _AuthBrandHeaderState extends State<AuthBrandHeader>
    with TickerProviderStateMixin {
  late final AnimationController _fadeSlideController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _logoSlide;

  late final AnimationController _logoPulseController;
  late final Animation<double> _logoScale;

  late final AnimationController _textShimmerController;

  late final AnimationController _logoBounceController;
  late final Animation<double> _logoBounceScale;

  @override
  void initState() {
    super.initState();

    _fadeSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _fadeSlideController, curve: Curves.easeOut);
    _logoSlide = Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _fadeSlideController, curve: Curves.easeOut));

    _logoPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _logoScale = Tween<double>(begin: 1.0, end: 1.06)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_logoPulseController);

    _textShimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _logoBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoBounceScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoBounceController, curve: Curves.elasticOut),
    );

    _logoBounceController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          _logoPulseController.repeat(reverse: true);
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fadeSlideController.forward();
      _logoBounceController.forward();
    });
  }

  @override
  void dispose() {
    _fadeSlideController.dispose();
    _logoPulseController.dispose();
    _textShimmerController.dispose();
    _logoBounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = widget.titleStyle ??
        theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800);

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _logoSlide,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _logoBounceScale,
              child: ScaleTransition(
                scale: _logoScale,
                child: Hero(
                  tag: 'app-logo',
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: widget.iconSize,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _shimmerPassageText(context, style: titleStyle),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.subtitle!,
                style: (widget.subtitleStyle ?? theme.textTheme.titleMedium)
                    ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _shimmerPassageText(BuildContext context, {TextStyle? style}) {
    final theme = Theme.of(context);
    final effectiveStyle = (style ?? theme.textTheme.headlineMedium)
            ?.copyWith(fontWeight: FontWeight.w800) ??
        const TextStyle(fontSize: 24, fontWeight: FontWeight.w800);

    return AnimatedBuilder(
      animation: _textShimmerController,
      builder: (context, child) {
        final t = _textShimmerController.value; // 0..1
        final base = theme.colorScheme.onSurface;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                base.withValues(alpha: 0.5),
                theme.colorScheme.primary,
                base.withValues(alpha: 0.5),
              ],
              stops: const [0.2, 0.5, 0.8],
              begin: Alignment(-1.0 + 2 * t, 0),
              end: Alignment(1.0 + 2 * t, 0),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcIn,
          child: Text('Passage', style: effectiveStyle),
        );
      },
    );
  }
}
