import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class PremiumGlowSpec {
  final Alignment alignment;
  final double size;
  final Color color;

  const PremiumGlowSpec({
    required this.alignment,
    required this.size,
    required this.color,
  });
}

class PremiumBackdrop extends StatelessWidget {
  final List<PremiumGlowSpec> glows;

  const PremiumBackdrop({
    super.key,
    required this.glows,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: AppColors.background),
        ...glows.map(
          (g) => Align(
            alignment: g.alignment,
            child: Container(
              width: g.size,
              height: g.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [g.color, Colors.transparent],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PremiumStaggerReveal extends StatelessWidget {
  final int index;
  final Widget child;
  final int baseMs;
  final int stepMs;
  final double offsetY;

  const PremiumStaggerReveal({
    super.key,
    required this.index,
    required this.child,
    this.baseMs = 230,
    this.stepMs = 25,
    this.offsetY = 12,
  });

  @override
  Widget build(BuildContext context) {
    final delay = index.clamp(0, 12) * stepMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: baseMs + delay),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, c) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * offsetY),
            child: c,
          ),
        );
      },
    );
  }
}

class PremiumGlassCard extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final List<Color>? gradientColors;
  final Color? borderColor;
  final double shadowAlpha;
  final double shadowBlur;
  final Offset shadowOffset;

  const PremiumGlassCard({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.padding,
    this.gradientColors,
    this.borderColor,
    this.shadowAlpha = 0.16,
    this.shadowBlur = 14,
    this.shadowOffset = const Offset(0, 7),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: premiumGlassDecoration(
        borderRadius: borderRadius,
        gradientColors: gradientColors,
        borderColor: borderColor,
        shadowAlpha: shadowAlpha,
        shadowBlur: shadowBlur,
        shadowOffset: shadowOffset,
      ),
      child: child,
    );
  }
}

BoxDecoration premiumGlassDecoration({
  BorderRadius borderRadius = const BorderRadius.all(Radius.circular(14)),
  List<Color>? gradientColors,
  Color? borderColor,
  double shadowAlpha = 0.16,
  double shadowBlur = 14,
  Offset shadowOffset = const Offset(0, 7),
}) {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: gradientColors ??
          [
            AppColors.surface.withValues(alpha: 0.9),
            AppColors.surfaceVariant.withValues(alpha: 0.72),
          ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: borderRadius,
    border: Border.all(color: borderColor ?? AppColors.border),
    boxShadow: [
      if (shadowAlpha > 0)
        BoxShadow(
          color: Colors.black.withValues(alpha: shadowAlpha),
          blurRadius: shadowBlur,
          offset: shadowOffset,
        ),
    ],
  );
}
