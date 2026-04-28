/// CRED-style animated background: mesh-gradient orbs + moving line art.
/// Combines floating orb glow with drifting diagonal lines, wandering
/// geometric frames (diamond / rectangle outlines), and subtle particle dots.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

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
      duration: const Duration(seconds: 16),
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
        painter: _ArtBgPainter(_ctrl.value),
      ),
    );
  }
}

// ─── Painter ─────────────────────────────────────────────────────────────────

class _ArtBgPainter extends CustomPainter {
  _ArtBgPainter(this.t);
  final double t; // 0..1 looping

  // ── Orbs: [relX, relY, radiusFactor, driftX, driftY, speed, phase] ─────────
  static const _orbs = [
    [0.10, 0.12, 0.85, 0.16, 0.12, 0.75, 0.00],
    [0.88, 0.08, 0.70, -0.14, 0.16, 0.60, 0.25],
    [0.50, 0.40, 1.05, 0.09, 0.09, 0.42, 0.55],
    [0.10, 0.80, 0.75, 0.12, -0.10, 0.65, 0.40],
    [0.90, 0.85, 0.65, -0.10, -0.09, 0.85, 0.70],
    [0.25, 0.55, 0.55, 0.07, 0.13, 0.52, 0.88],
  ];

  static const _orbColors = [
    [Color(0xFFFF6B1A), Color(0xFFE8380A)],
    [Color(0xFFFF8C00), Color(0xFFE05500)],
    [Color(0xFFCC3300), Color(0xFF8B1A00)],
    [Color(0xFFFF7722), Color(0xFFCC4400)],
    [Color(0xFFFFAA00), Color(0xFFE06600)],
    [Color(0xFF992200), Color(0xFF550A00)],
  ];

  // ── Diagonal lines: [startX, startY, angle(deg), length, speed, phase, opacity] ──
  static const _lines = [
    [0.05, 0.30,  55.0, 1.20, 0.30, 0.00, 0.18],
    [0.80, 0.10,  55.0, 0.90, 0.25, 0.33, 0.14],
    [0.15, 0.70,  55.0, 1.50, 0.20, 0.66, 0.20],
    [0.60, 0.55,  55.0, 0.70, 0.35, 0.15, 0.12],
    [0.40, 0.15, -35.0, 1.10, 0.28, 0.50, 0.16],
    [0.70, 0.80, -35.0, 0.80, 0.32, 0.80, 0.13],
    [0.25, 0.50,  55.0, 0.60, 0.40, 0.10, 0.10],
    [0.90, 0.40,  55.0, 1.00, 0.22, 0.60, 0.15],
  ];

  // ── Geometric frames: [relX, relY, size, rotSpeed, phase, shape(0=diamond,1=rect)] ──
  static const _shapes = [
    [0.15, 0.20, 0.14, 0.18, 0.00, 0], // diamond
    [0.80, 0.15, 0.10, 0.22, 0.30, 1], // rect
    [0.70, 0.70, 0.18, 0.12, 0.55, 0], // diamond
    [0.20, 0.80, 0.12, 0.20, 0.70, 1], // rect
    [0.50, 0.08, 0.09, 0.30, 0.45, 0], // small diamond top
    [0.88, 0.50, 0.11, 0.15, 0.20, 1], // rect right
  ];

  // ── Particle dots: [relX, relY, driftX, driftY, speed, phase] ──────────────
  static const _dots = [
    [0.30, 0.25, 0.06, 0.08, 0.40, 0.10],
    [0.60, 0.18, -0.05, 0.07, 0.35, 0.55],
    [0.75, 0.60, 0.04, -0.06, 0.50, 0.30],
    [0.20, 0.65, 0.07, -0.05, 0.45, 0.75],
    [0.85, 0.35, -0.06, 0.08, 0.38, 0.60],
    [0.45, 0.85, 0.05, 0.06, 0.42, 0.20],
    [0.10, 0.45, 0.08, -0.07, 0.36, 0.90],
    [0.65, 0.90, -0.07, -0.05, 0.44, 0.40],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final minDim = math.min(w, h);

    // ── 1. Near-black base ──────────────────────────────────────────────────
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF080407));

    // ── 2. Orb glows ────────────────────────────────────────────────────────
    for (int i = 0; i < _orbs.length; i++) {
      final o = _orbs[i];
      final c = _orbColors[i];
      final phase = (t * o[5] + o[6]) % 1.0;
      final angle = phase * math.pi * 2;
      final cx = (o[0] + math.sin(angle * 0.73) * o[2] * o[3]) * w;
      final cy = (o[1] + math.cos(angle * 0.61) * o[2] * o[4]) * h;
      final breathe = 1.0 + 0.10 * math.sin(angle * 1.7 + i);
      final radius = o[2] * minDim * breathe;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              c[0].withOpacity(0.72),
              c[1].withOpacity(0.45),
              c[1].withOpacity(0.15),
              Colors.transparent,
            ],
            stops: const [0.0, 0.28, 0.58, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius)),
      );
    }

    // ── 3. Diagonal lines ────────────────────────────────────────────────────
    for (final l in _lines) {
      final phase = (t * l[4] + l[5]) % 1.0;
      final lineAngle = l[2] * math.pi / 180.0;

      // Drift lines slowly down along their angle
      final drift = phase * minDim * 0.9;
      final perpX = math.cos(lineAngle + math.pi / 2) * drift;
      final perpY = math.sin(lineAngle + math.pi / 2) * drift;

      final startX = l[0] * w + perpX;
      final startY = l[1] * h + perpY;
      final len = l[3] * minDim;
      final endX = startX + math.cos(lineAngle) * len;
      final endY = startY + math.sin(lineAngle) * len;

      // Fade in/out so they loop seamlessly
      final fade = math.sin(phase * math.pi); // 0→1→0 over one cycle
      final opacity = l[6] * fade;

      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        Paint()
          ..color = const Color(0xFFFF6B1A).withOpacity(opacity)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke,
      );
    }

    // ── 4. Geometric outline shapes ─────────────────────────────────────────
    for (final s in _shapes) {
      final phase = (t * s[3] + s[4]) % 1.0;
      final rot = phase * math.pi * 2;
      final pulse = 1.0 + 0.08 * math.sin(rot * 1.5);
      final shapeSize = s[2] * minDim * pulse;
      final cx = s[0] * w;
      final cy = s[1] * h;

      // Gentle opacity breathe
      final opacFade = 0.12 + 0.08 * math.sin(rot * 0.8);

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(rot * (s[5] == 0 ? 1.0 : 0.25)); // diamonds spin faster

      final paint = Paint()
        ..color = const Color(0xFFFF7722).withOpacity(opacFade)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      if (s[5] == 0) {
        // Diamond (square rotated 45°)
        final half = shapeSize / 2;
        final path = Path()
          ..moveTo(0, -half)
          ..lineTo(half, 0)
          ..lineTo(0, half)
          ..lineTo(-half, 0)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        // Rectangle outline
        final hw = shapeSize / 2;
        final hh = shapeSize * 0.65 / 2;
        canvas.drawRect(Rect.fromLTRB(-hw, -hh, hw, hh), paint);
      }

      canvas.restore();
    }

    // ── 5. Particle dots ────────────────────────────────────────────────────
    for (final d in _dots) {
      final phase = (t * d[4] + d[5]) % 1.0;
      final angle = phase * math.pi * 2;
      final px = (d[0] + math.sin(angle * 0.6) * d[2]) * w;
      final py = (d[1] + math.cos(angle * 0.5) * d[3]) * h;
      final opacity = 0.15 + 0.15 * math.sin(angle * 1.2);
      canvas.drawCircle(
        Offset(px, py),
        2.2,
        Paint()..color = const Color(0xFFFFAA44).withOpacity(opacity),
      );
    }

    // ── 6. Edge vignette — keeps card readable ───────────────────────────────
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.black.withOpacity(0.62)],
          stops: const [0.42, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  @override
  bool shouldRepaint(_ArtBgPainter old) => old.t != t;
}
