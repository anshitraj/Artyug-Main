import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

class DashboardBackground extends StatelessWidget {
  final Widget child;

  const DashboardBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accentA = (dark ? const Color(0xFF4F8BFF) : const Color(0xFFFFA16C))
        .withValues(alpha: dark ? 0.11 : 0.08);
    final accentB = (dark ? AppColors.primary : const Color(0xFFFFD4BC))
        .withValues(alpha: dark ? 0.09 : 0.1);
    final accentC = (dark ? const Color(0xFF2B6A2B) : const Color(0xFF2A2520))
        .withValues(alpha: dark ? 0.06 : 0.04);

    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: AppColors.canvasOf(context)),
        ),
        Positioned(
          top: -90,
          right: -70,
          child: _AmbientBlob(size: 240, color: accentA),
        ),
        Positioned(
          top: 240,
          left: -120,
          child: _AmbientBlob(size: 260, color: accentB),
        ),
        Positioned(
          bottom: -120,
          right: 30,
          child: _AmbientBlob(size: 220, color: accentC),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ContourPainter(
                lineColor: (dark
                        ? const Color(0xFFE6EDFF)
                        : const Color(0xFF2E2A25))
                    .withValues(alpha: dark ? 0.06 : 0.05),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _AmbientBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _ContourPainter extends CustomPainter {
  final Color lineColor;

  const _ContourPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 7; i++) {
      final path = Path();
      final baseY = size.height * (0.08 + (i * 0.14));
      path.moveTo(0, baseY);
      for (double x = 0; x <= size.width; x += 12) {
        final y = baseY +
            math.sin((x / size.width * math.pi * 2) + i * 0.8) *
                (7 + i * 0.6);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, p);
    }

    final orbitPaint = Paint()
      ..color = lineColor.withValues(alpha: lineColor.a * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final center = Offset(size.width * 0.85, size.height * 0.18);
    canvas.drawCircle(center, 58, orbitPaint);
    canvas.drawCircle(center, 82, orbitPaint);
  }

  @override
  bool shouldRepaint(covariant _ContourPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}

