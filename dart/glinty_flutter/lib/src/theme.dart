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
  // The platform UI faces are one cluster of neutral grotesques;
  // naming each platform's member gives the same face the browser's
  // `system-ui` picks, so both frontends match on any one machine.
  // Flutter tries names in order and each platform ships exactly
  // one. CanvasKit can't reach system fonts and keeps its bundled
  // Roboto -- also a member of the cluster, so it stays a cousin.
  'system-ui': [
    '.AppleSystemUIFont',
    'Segoe UI',
    'Ubuntu',
    'Cantarell',
    'sans-serif'
  ],
  'ui-sans-serif': [
    '.AppleSystemUIFont',
    'Segoe UI',
    'Ubuntu',
    'Cantarell',
    'sans-serif'
  ],
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

/// ThemeData for the platform's brightness.
///
/// A theme carrying a `dark` palette follows the system setting: the
/// dark colors replace `colors` wholesale when the platform asks for
/// dark, and [glintyThemeData]'s brightness estimate then picks the
/// dark base scheme from the dark background on its own. Without
/// `dark` the supplied tokens are exact in both schemes, which is
/// the pre-`dark` contract unchanged.
/// glinty's stock look, in the welcome's wire shape: the values the
/// browser stylesheet falls back to when an app sets no theme
/// (R theme_defaults() light tokens, DARK_COLOR_DEFAULTS for dark).
/// An unthemed app must be the same product in both lowerings --
/// falling back to Material's seed purple made it two.
const Map<String, dynamic> glintyStockTheme = {
  'colors': {
    'primary': '#2456d6',
    'on_primary': '#ffffff',
    'surface': '#ffffff',
    'background': '#ffffff',
    'text': '#1a1a1a',
    'muted': '#6a6a6a',
    'border': '#d0d0d5',
    'danger': '#b3261e',
    'success': '#1a7f37',
    'warning': '#9a6700',
  },
  'dark': {
    'primary': '#6f95f5',
    'on_primary': '#10131a',
    'surface': '#1e2128',
    'background': '#16181d',
    'text': '#e6e6e6',
    'muted': '#9a9aa2',
    'border': '#3a3d45',
    'danger': '#e5484d',
    'success': '#3fb950',
    'warning': '#d29922',
  },
  'spacing': 4,
  'radius': 6,
  'font': {'body': 'system-ui', 'mono': 'ui-monospace', 'size': 16},
};

/// The status tokens Material's ColorScheme has no slots for.
///
/// `danger` maps onto `ColorScheme.error`; `success` and `warning`
/// have no Material seat, so they ride a ThemeExtension and the text
/// variants read them off Theme.of(context). glintyThemeData always
/// installs one, defaulted from the stock palette for the scheme's
/// brightness, so an unthemed app shows the same status colors the
/// browser stylesheet ships.
class GlintyStatusColors extends ThemeExtension<GlintyStatusColors> {
  const GlintyStatusColors({required this.success, required this.warning});

  final Color success;
  final Color warning;

  @override
  GlintyStatusColors copyWith({Color? success, Color? warning}) =>
      GlintyStatusColors(
          success: success ?? this.success,
          warning: warning ?? this.warning);

  @override
  GlintyStatusColors lerp(GlintyStatusColors? other, double t) {
    if (other == null) return this;
    return GlintyStatusColors(
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
    );
  }
}

ThemeData glintyThemeDataFor(
    Map<String, dynamic> theme, Brightness? brightness) {
  final dark = theme['dark'];
  if (brightness == Brightness.dark && dark is Map) {
    final swapped = Map<String, dynamic>.from(theme);
    swapped['colors'] = dark.cast<String, dynamic>();
    return glintyThemeData(swapped);
  }
  return glintyThemeData(theme);
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

  // success/warning fall back to the stock palette for this
  // brightness rather than to a Material slot, because none exists.
  final stockStatus = ((brightness == Brightness.dark
          ? glintyStockTheme['dark']
          : glintyStockTheme['colors']) as Map)
      .cast<String, dynamic>();
  final status = GlintyStatusColors(
    success: pick('success',
        glintyColor(stockStatus['success']) ?? scheme.primary),
    warning: pick('warning',
        glintyColor(stockStatus['warning']) ?? scheme.primary),
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
    extensions: [status],
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
