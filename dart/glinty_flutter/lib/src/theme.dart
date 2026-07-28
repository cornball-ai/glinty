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

/// What each CSS generic resolves to here, preserving its role. CSS
/// resolves generics itself; Flutter resolves whatever the platform
/// font collection knows -- Android registers 'sans-serif', 'serif'
/// and 'monospace' as real family names (the framework's own error
/// style says fontFamily: 'monospace'), Apple platforms only know
/// concrete faces. So each role leads with the generic name and
/// falls back to faces every desktop and Apple platform ships,
/// which is what keeps body: "monospace" mono and mono: "serif"
/// serif instead of collapsing every generic to the default sans.
const _roleStacks = <String, List<String>>{
  'system-ui': ['sans-serif'],
  'ui-sans-serif': ['sans-serif'],
  'sans-serif': ['sans-serif'],
  'serif': ['serif', 'Georgia', 'Times New Roman'],
  'ui-serif': ['serif', 'Georgia', 'Times New Roman'],
  'monospace': ['monospace', 'Menlo', 'Courier New'],
  'ui-monospace': ['monospace', 'Menlo', 'Courier New'],
};

/// The mono role's own stack, the fallback for everything monospaced.
const glintyMonoRole = ['monospace', 'Menlo', 'Courier New'];

/// Resolve one font token to a family stack.
///
/// Absent tokens take [fallback]; a generic takes its role's stack;
/// a custom family leads and degrades through [fallback], so a
/// missing bundled font lands within its role rather than on sans.
List<String> glintyFontStack(dynamic v,
    {List<String> fallback = const []}) {
  if (v is! String || v.isEmpty) return fallback;
  final generic = _roleStacks[v];
  if (generic != null) return generic;
  return [v, ...fallback];
}

/// The stack for verbatim output, from the theme's mono token.
List<String> glintyMonoStack(Map<String, dynamic>? theme) {
  final font = theme?['font'];
  return glintyFontStack(font is Map ? font['mono'] : null,
      fallback: glintyMonoRole);
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

  final bodyStack = glintyFontStack(font['body']);

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    fontFamily: bodyStack.isEmpty ? null : bodyStack.first,
    fontFamilyFallback: bodyStack.length > 1 ? bodyStack.sublist(1) : null,
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
