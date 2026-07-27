/// Theme tokens -> ThemeData.
///
/// The Flutter lowering of the same closed token set the browser
/// turns into CSS custom properties. Tokens are semantic and the
/// mapping is explicit: no seed-color derivation, because a server
/// that says surface means that surface, not a tonal neighbour of
/// the primary.
library;

import 'package:flutter/material.dart';

/// Parse a "#rrggbb" or "#rrggbbaa" token into a Color.
///
/// Anything else returns null and the caller's fallback applies --
/// a malformed token from a newer server degrades to the default
/// look rather than an exception.
Color? glintyColor(dynamic hex) {
  if (hex is! String) return null;
  final m = RegExp(r'^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$').firstMatch(hex);
  if (m == null) return null;
  final rgb = int.parse(m.group(1)!, radix: 16);
  final alpha = m.group(2) == null ? 0xff : int.parse(m.group(2)!, radix: 16);
  return Color((alpha << 24) | rgb);
}

/// The theme's base spacing unit in logical pixels, or the glinty
/// default. spacer() sizes and layout gaps are multiples of it, the
/// same rule the browser applies through --g-space. Zero is a valid
/// unit (R allows it, the browser honours it), so only absence and
/// nonsense fall back.
double glintySpacing(Map<String, dynamic>? theme) {
  final v = theme?['spacing'];
  return v is num && v >= 0 ? v.toDouble() : 4;
}

/// Font tokens that name a platform role rather than a family. CSS
/// resolves these itself; Flutter has no registry for them, so they
/// mean "use the platform's own" here -- passing one through as a
/// fontFamily would silently miss and land on the default *sans*
/// face, which for the mono token is exactly wrong.
const _genericFonts = <String>{
  'system-ui', 'sans-serif', 'serif', 'monospace',
  'ui-monospace', 'ui-sans-serif', 'ui-serif',
};

String? _familyOrNull(dynamic v) {
  if (v is! String || v.isEmpty || _genericFonts.contains(v)) return null;
  return v;
}

/// The theme's mono font family, for verbatim output. Null when the
/// theme is absent or the token names a generic role: the renderer's
/// platform monospace applies then. A custom family only takes
/// effect if the app bundled that font asset.
String? glintyMonoFamily(Map<String, dynamic>? theme) {
  final font = theme?['font'];
  return _familyOrNull(font is Map ? font['mono'] : null);
}

/// Build ThemeData from a welcome's theme tokens.
ThemeData glintyThemeData(Map<String, dynamic> theme) {
  final colors =
      (theme['colors'] as Map?)?.cast<String, dynamic>() ?? const {};
  Color pick(String name, Color fallback) =>
      glintyColor(colors[name]) ?? fallback;

  final background = pick('background', Colors.white);
  final brightness = ThemeData.estimateBrightnessForColor(background);
  final base = brightness == Brightness.dark
      ? const ColorScheme.dark()
      : const ColorScheme.light();
  final scheme = base.copyWith(
    primary: pick('primary', base.primary),
    onPrimary: pick('on_primary', base.onPrimary),
    surface: pick('surface', base.surface),
    onSurface: pick('text', base.onSurface),
    // muted is what the browser spends on secondary text; Material's
    // slot for that role is onSurfaceVariant, which _textStyleFor
    // reads for the muted variant.
    onSurfaceVariant: pick('muted', base.onSurfaceVariant),
    error: pick('danger', base.error),
    outline: pick('border', base.outline),
  );

  final font = (theme['font'] as Map?)?.cast<String, dynamic>() ?? const {};
  final size = font['size'] is num ? (font['size'] as num).toDouble() : null;

  // radius lands where the browser spends --g-radius: cards (panel
  // variant card) and the button family.
  final radiusV = theme['radius'];
  final shape = radiusV is num && radiusV >= 0
      ? RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusV.toDouble()))
      : null;

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    fontFamily: _familyOrNull(font['body']),
    cardTheme: shape == null ? null : CardThemeData(shape: shape),
    filledButtonTheme: shape == null
        ? null
        : FilledButtonThemeData(style: FilledButton.styleFrom(shape: shape)),
    elevatedButtonTheme: shape == null
        ? null
        : ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(shape: shape)),
    outlinedButtonTheme: shape == null
        ? null
        : OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(shape: shape)),
    // ghost buttons are TextButtons; without this they were the one
    // family the radius token missed
    textButtonTheme: shape == null
        ? null
        : TextButtonThemeData(style: TextButton.styleFrom(shape: shape)),
    textTheme: size == null
        ? null
        // Partial: unset styles keep the typography defaults.
        : TextTheme(
            bodyLarge: TextStyle(fontSize: size + 2),
            bodyMedium: TextStyle(fontSize: size),
            bodySmall: TextStyle(fontSize: size - 2),
          ),
  );
}
