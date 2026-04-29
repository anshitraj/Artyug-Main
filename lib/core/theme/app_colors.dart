import 'package:flutter/material.dart';

// Premium dark-first Artyug palette
const kOrange = Color(0xFFFF6A2B);
const kOrangeDark = Color(0xFFD84F1A);
const kOrangeLight = Color(0x26FF6A2B);
const kBlack = Color(0xFF0A0D14);
const kGrey = Color(0xFFA9B1C1);
const kBorder = Color(0xFF2A3447);
const kBg = Color(0xFF090D15);
const kWhite = Color(0xFFFFFFFF);

class AppColors {
  AppColors._();

  // Dark palette
  static const Color background = Color(0xFF070B12);
  static const Color surface = Color(0xFF141C2C);
  static const Color surfaceVariant = Color(0xFF1C2739);
  static const Color surfaceHigh = Color(0xFF2A3A52);
  static const Color sidebar = Color(0xFF121A2A);

  // Brand
  static const Color primary = Color(0xFFFF6A2B);
  static const Color primaryDark = Color(0xFFD84F1A);
  static const Color primaryLight = Color(0x26FF6A2B);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Dark text
  static const Color textPrimary = Color(0xFFF7F9FF);
  static const Color textSecondary = Color(0xFFB5C0D4);
  static const Color textTertiary = Color(0xFF72809A);
  static const Color textOnLight = Color(0xFF151515);
  static const Color textOnLightSecondary = Color(0xFF6F6F76);

  // Borders
  static const Color border = Color(0xFF354056);
  static const Color borderStrong = Color(0xFF4A5D7A);

  // Semantic
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF4F8BFF);

  // Backward-compat aliases
  static const Color primarySoft = Color(0x26FF6A2B);
  static const Color badgeBlue = Color(0xFF4F8BFF);
  static const Color badgeGold = Color(0xFFF59E0B);

  // Light aliases retained for compatibility
  static const Color lightBackground = Color(0xFFFAF7F2);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE8E2D8);
  static const Color lightText = Color(0xFF151515);

  // Gradients
  static const Gradient goldGradient = LinearGradient(
    colors: [Color(0xFFFF7A3B), Color(0xFFFF5A1F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient cardOverlay = LinearGradient(
    colors: [Colors.transparent, Color(0xCC060A12)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Gradient heroGradient = LinearGradient(
    colors: [Color(0xFF0C1220), Color(0xFF111826)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color darkBg = background;
  static const Color darkSurface = surface;
  static const Color darkBorder = border;
  static const Color darkText = textPrimary;

  // Light theme palette
  static const Color _lightCanvas = Color(0xFFFAF7F2);
  static const Color _lightCanvasSoft = Color(0xFFFFF8F0);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceSoft = Color(0xFFFFFDF9);
  static const Color _lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color _lightBorder = Color(0xFFE8E2D8);
  static const Color _lightBorderStrong = Color(0xFFDDD4C8);
  static const Color _lightTextPrimary = Color(0xFF151515);
  static const Color _lightTextSecondary = Color(0xFF6F6F76);
  static const Color _lightTextMuted = Color(0xFF9A938B);
  static const Color _lightAccent = Color(0xFFFF5A1F);
  static const Color _lightAccentSoft = Color(0xFFFFF0E8);

  // Dark theme semantic companions
  static const Color _darkCanvasSoft = Color(0xFF0D1320);
  static const Color _darkSurfaceSoft = Color(0xFF1A2437);
  static const Color _darkSurfaceElevated = Color(0xFF202C42);
  static const Color _darkTextMuted = Color(0xFF8A97AF);
  static const Color _darkAccentSoft = Color(0x292B6A2B);

  static const Color accentGradientStart = Color(0xFFFF7A2F);
  static const Color accentGradientEnd = Color(0xFFFF3D00);
  static const Color cardShadowLight = Color.fromRGBO(18, 18, 18, 0.08);
  static const Color cardShadowDark = Color.fromRGBO(0, 0, 0, 0.34);

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color canvas(BuildContext context) =>
      _isDark(context) ? background : _lightCanvas;

  static Color canvasOf(BuildContext context) => canvas(context);

  static Color canvasSoftOf(BuildContext context) =>
      _isDark(context) ? _darkCanvasSoft : _lightCanvasSoft;

  static Color surfaceOf(BuildContext context) =>
      _isDark(context) ? surface : _lightSurface;

  static Color surfaceSoftOf(BuildContext context) =>
      _isDark(context) ? _darkSurfaceSoft : _lightSurfaceSoft;

  static Color surfaceElevatedOf(BuildContext context) =>
      _isDark(context) ? _darkSurfaceElevated : _lightSurfaceElevated;

  static Color surfaceMutedOf(BuildContext context) =>
      _isDark(context) ? surfaceVariant : _lightSurfaceSoft;

  static Color surfaceHighOf(BuildContext context) =>
      _isDark(context) ? surfaceHigh : const Color(0xFFEFE8DD);

  static Color borderOf(BuildContext context) =>
      _isDark(context) ? border : _lightBorder;

  static Color borderStrongOf(BuildContext context) =>
      _isDark(context) ? borderStrong : _lightBorderStrong;

  static Color textPrimaryOf(BuildContext context) =>
      _isDark(context) ? textPrimary : _lightTextPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      _isDark(context) ? textSecondary : _lightTextSecondary;

  static Color textTertiaryOf(BuildContext context) =>
      _isDark(context) ? textTertiary : _lightTextMuted;

  static Color textMutedOf(BuildContext context) =>
      _isDark(context) ? _darkTextMuted : _lightTextMuted;

  static Color accentOf(BuildContext context) =>
      _isDark(context) ? primary : _lightAccent;

  static Color accentSoftOf(BuildContext context) =>
      _isDark(context) ? _darkAccentSoft : _lightAccentSoft;

  static Color shadowOf(BuildContext context, {double alpha = 1}) {
    final base = _isDark(context) ? cardShadowDark : cardShadowLight;
    return base.withValues(alpha: base.a * alpha);
  }

  static Gradient accentGradientOf(BuildContext context) {
    final start = _isDark(context) ? primary : accentGradientStart;
    return LinearGradient(
      colors: [start, accentGradientEnd],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static Gradient heroGradientOf(BuildContext context) {
    if (_isDark(context)) return heroGradient;
    return const LinearGradient(
      colors: [Color(0xFFFFFDF8), Color(0xFFF4ECE0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static List<BoxShadow> cardShadows(BuildContext context, {bool hovered = false}) {
    final a = _isDark(context) ? (hovered ? 0.45 : 0.32) : (hovered ? 0.14 : 0.08);
    final blur = hovered ? 28.0 : 20.0;
    return [
      BoxShadow(
        color: shadowOf(context, alpha: a),
        blurRadius: blur,
        offset: const Offset(0, 12),
      ),
    ];
  }
}

