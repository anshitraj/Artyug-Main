import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Premium light-theme auth background for ARYUG.
///
/// Motion system layers (slow, subtle, non-distracting):
/// - soft warm base gradients
/// - drifting mesh diffusion blobs
/// - faint contour-wave line field
/// - fine editorial grid
/// - orbital arcs for art-tech identity
/// - ultra-subtle grain texture
class AuthBackground extends StatefulWidget {
  const AuthBackground({super.key});

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 34),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: size,
        painter: _PremiumAuthBgPainter(_ctrl.value),
      ),
    );
  }
}

class _PremiumAuthBgPainter extends CustomPainter {
  _PremiumAuthBgPainter(this.t);

  final double t;

  static const Color _baseIvory = Color(0xFFFAF7F2);
  static const Color _baseWarm = Color(0xFFFFF8F0);
  static const Color _peach = Color(0xFFFFD8C2);
  static const Color _apricot = Color(0xFFFFC89F);
  static const Color _amber = Color(0xFFFFB983);
  static const Color _line = Color(0xFFE5DCCE);
  static const Color _ink = Color(0xFF151515);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final minDim = math.min(w, h);

    // 1) Warm editorial base.
    final base = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      base,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_baseIvory, _baseWarm],
        ).createShader(base),
    );

    // 2) Soft ambient diffusion fields.
    _drawDiffuseBlob(
      canvas,
      size,
      cx: w * (0.12 + 0.02 * math.sin(t * math.pi * 2)),
      cy: h * (0.18 + 0.015 * math.cos(t * math.pi * 2)),
      radius: minDim * 0.95,
      inner: _peach.withValues(alpha: 0.42),
      outer: _peach.withValues(alpha: 0.0),
    );
    _drawDiffuseBlob(
      canvas,
      size,
      cx: w * (0.86 + 0.018 * math.cos((t + 0.2) * math.pi * 2)),
      cy: h * (0.14 + 0.02 * math.sin((t + 0.1) * math.pi * 2)),
      radius: minDim * 0.82,
      inner: _apricot.withValues(alpha: 0.28),
      outer: _apricot.withValues(alpha: 0.0),
    );
    _drawDiffuseBlob(
      canvas,
      size,
      cx: w * (0.62 + 0.02 * math.sin((t + 0.36) * math.pi * 2)),
      cy: h * (0.84 + 0.015 * math.cos((t + 0.42) * math.pi * 2)),
      radius: minDim * 1.05,
      inner: _amber.withValues(alpha: 0.18),
      outer: _amber.withValues(alpha: 0.0),
    );

    // 3) Subtle topographic-wave contour lines.
    _drawContourWaves(canvas, size, t);

    // 4) Fine grid overlay.
    _drawGrid(canvas, size, minDim);

    // 5) Faint orbital line system.
    _drawOrbitalArcs(canvas, size, t);

    // 6) Gentle directional vignette for focus.
    canvas.drawRect(
      base,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 1.1,
          colors: [
            Colors.transparent,
            _ink.withValues(alpha: 0.05),
          ],
          stops: const [0.58, 1.0],
        ).createShader(base),
    );

    // 7) Micro grain for luxury editorial texture.
    _drawGrain(canvas, size);
  }

  void _drawDiffuseBlob(
    Canvas canvas,
    Size size, {
    required double cx,
    required double cy,
    required double radius,
    required Color inner,
    required Color outer,
  }) {
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [inner, outer],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius)),
    );
  }

  void _drawContourWaves(Canvas canvas, Size size, double time) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = _line.withValues(alpha: 0.27)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (int i = 0; i < 16; i++) {
      final path = Path();
      final yBase = h * (0.08 + i * 0.058);
      final amp = 7.0 + (i % 4) * 1.8;
      final waveShift = (time * math.pi * 2 * 0.35) + i * 0.36;

      path.moveTo(0, yBase);
      for (double x = 0; x <= w; x += 4) {
        final normalizedX = x / w;
        final y = yBase +
            math.sin(normalizedX * math.pi * 3.1 + waveShift) * amp +
            math.cos(normalizedX * math.pi * 1.2 - waveShift * 0.65) * 2.2;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawGrid(Canvas canvas, Size size, double minDim) {
    final step = minDim * 0.1;
    final paint = Paint()
      ..color = _line.withValues(alpha: 0.12)
      ..strokeWidth = 0.7;

    for (double x = -step; x <= size.width + step; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = -step; y <= size.height + step; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawOrbitalArcs(Canvas canvas, Size size, double time) {
    final w = size.width;
    final h = size.height;

    final centers = <Offset>[
      Offset(w * 0.16, h * 0.12),
      Offset(w * 0.88, h * 0.24),
      Offset(w * 0.72, h * 0.84),
    ];

    for (int i = 0; i < centers.length; i++) {
      final center = centers[i];
      final baseRadius = (w * 0.28) + (i * 26);
      final arcPaint = Paint()
        ..color = _amber.withValues(alpha: 0.13 - i * 0.02)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9;

      final pulse = 1 + 0.03 * math.sin((time + i * 0.22) * math.pi * 2);
      final rect = Rect.fromCircle(center: center, radius: baseRadius * pulse);

      canvas.drawArc(
        rect,
        (math.pi * 0.12) + (time * math.pi * 2 * 0.08),
        math.pi * 1.36,
        false,
        arcPaint,
      );
      canvas.drawArc(
        rect.inflate(22),
        (math.pi * 1.15) - (time * math.pi * 2 * 0.06),
        math.pi * 0.8,
        false,
        arcPaint..color = _peach.withValues(alpha: 0.11),
      );
    }
  }

  void _drawGrain(Canvas canvas, Size size) {
    final seed = (t * 10000).toInt();
    final random = math.Random(seed);
    final paint = Paint();

    for (int i = 0; i < 850; i++) {
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final alpha = 0.010 + random.nextDouble() * 0.017;
      paint.color = _ink.withValues(alpha: alpha);
      canvas.drawRect(Rect.fromLTWH(dx, dy, 1.2, 1.2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PremiumAuthBgPainter oldDelegate) =>
      oldDelegate.t != t;
}
