import 'package:flutter/material.dart';

import 'oklch.dart';

/// The nine role tokens from board 1a, plus the few extra roles the screens
/// actually reference (divider, muted text, accent-on-surface, semantics).
///
/// Nothing in a screen names a raw color, so a theme swap is a single map
/// replacement — which is exactly what [ThemeFamily] does.
@immutable
class PerchColors extends ThemeExtension<PerchColors> {
  const PerchColors({
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.outline,
    required this.divider,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.onSurfaceMuted,
    required this.icon,
    required this.iconMuted,
    required this.primary,
    required this.primaryPressed,
    required this.primaryContainer,
    required this.onPrimary,
    required this.onPrimaryContainer,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.dangerContainer,
    required this.shadow,
  });

  /// Page background.
  final Color surface;

  /// Cards, rows, sheets.
  final Color surfaceContainer;

  /// Nav pill, chips, fields.
  final Color surfaceContainerHigh;

  /// 1px borders — depth lives here.
  final Color outline;

  /// Hairline between rows inside one container.
  final Color divider;

  /// Titles, note body.
  final Color onSurface;

  /// Domains, counts, labels.
  final Color onSurfaceVariant;

  /// Disabled labels.
  final Color onSurfaceMuted;

  /// Top-bar icon actions.
  final Color icon;

  /// Inactive nav glyphs — a step lighter than [icon].
  final Color iconMuted;

  /// FAB, Start, active indicator.
  final Color primary;
  final Color primaryPressed;

  /// Selected tab, tag chip on.
  final Color primaryContainer;

  /// Text on accent.
  final Color onPrimary;
  final Color onPrimaryContainer;

  /// Accent-coloured text and icons sitting directly on a surface.
  final Color accent;

  final Color success;
  final Color warning;
  final Color danger;
  final Color dangerContainer;

  /// Only the nav pill and the FAB cast one.
  final Color shadow;

  @override
  PerchColors copyWith({
    Color? surface,
    Color? surfaceContainer,
    Color? surfaceContainerHigh,
    Color? outline,
    Color? divider,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? onSurfaceMuted,
    Color? icon,
    Color? iconMuted,
    Color? primary,
    Color? primaryPressed,
    Color? primaryContainer,
    Color? onPrimary,
    Color? onPrimaryContainer,
    Color? accent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? dangerContainer,
    Color? shadow,
  }) {
    return PerchColors(
      surface: surface ?? this.surface,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh ?? this.surfaceContainerHigh,
      outline: outline ?? this.outline,
      divider: divider ?? this.divider,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      onSurfaceMuted: onSurfaceMuted ?? this.onSurfaceMuted,
      icon: icon ?? this.icon,
      iconMuted: iconMuted ?? this.iconMuted,
      primary: primary ?? this.primary,
      primaryPressed: primaryPressed ?? this.primaryPressed,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimary: onPrimary ?? this.onPrimary,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  PerchColors lerp(ThemeExtension<PerchColors>? other, double t) {
    if (other is! PerchColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return PerchColors(
      surface: l(surface, other.surface),
      surfaceContainer: l(surfaceContainer, other.surfaceContainer),
      surfaceContainerHigh: l(
        surfaceContainerHigh,
        other.surfaceContainerHigh,
      ),
      outline: l(outline, other.outline),
      divider: l(divider, other.divider),
      onSurface: l(onSurface, other.onSurface),
      onSurfaceVariant: l(onSurfaceVariant, other.onSurfaceVariant),
      onSurfaceMuted: l(onSurfaceMuted, other.onSurfaceMuted),
      icon: l(icon, other.icon),
      iconMuted: l(iconMuted, other.iconMuted),
      primary: l(primary, other.primary),
      primaryPressed: l(primaryPressed, other.primaryPressed),
      primaryContainer: l(primaryContainer, other.primaryContainer),
      onPrimary: l(onPrimary, other.onPrimary),
      onPrimaryContainer: l(onPrimaryContainer, other.onPrimaryContainer),
      accent: l(accent, other.accent),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      dangerContainer: l(dangerContainer, other.dangerContainer),
      shadow: l(shadow, other.shadow),
    );
  }
}

/// How dark a variant is. AMOLED is not a mode — it is a true-black toggle that
/// only applies while dark is in effect (board 1i).
enum Tone { light, dark, amoled }

/// One accent family. Board 1a ships four plus Android dynamic color; the two
/// browse-heavy families (Perch, Slate) also ship AMOLED.
@immutable
class ThemeFamily {
  const ThemeFamily({
    required this.id,
    required this.name,
    required this.blurb,
    required this.neutralHue,
    required this.neutralChroma,
    required this.primaryHue,
    required this.primaryLightness,
    required this.primaryChroma,
    required this.primaryContainerChroma,
    required this.hasAmoled,
  });

  final String id;
  final String name;
  final String blurb;

  /// Hue for the near-grey surfaces and text.
  final double neutralHue;

  /// Multiplier on the reference neutral chromas — Slate damps them, Ember
  /// warms them slightly.
  final double neutralChroma;

  final double primaryHue;
  final double primaryLightness;
  final double primaryChroma;
  final double primaryContainerChroma;
  final bool hasAmoled;

  static const ThemeFamily perch = ThemeFamily(
    id: 'perch',
    name: 'Perch',
    blurb: 'default',
    neutralHue: 265,
    neutralChroma: 1,
    primaryHue: 265,
    primaryLightness: 0.55,
    primaryChroma: 0.16,
    primaryContainerChroma: 0.045,
    hasAmoled: true,
  );

  static const ThemeFamily ember = ThemeFamily(
    id: 'ember',
    name: 'Ember',
    blurb: 'warm',
    neutralHue: 55,
    neutralChroma: 1.35,
    primaryHue: 45,
    primaryLightness: 0.60,
    primaryChroma: 0.14,
    primaryContainerChroma: 0.045,
    hasAmoled: false,
  );

  static const ThemeFamily fern = ThemeFamily(
    id: 'fern',
    name: 'Fern',
    blurb: 'cool',
    neutralHue: 160,
    neutralChroma: 1.15,
    primaryHue: 162,
    primaryLightness: 0.56,
    primaryChroma: 0.11,
    primaryContainerChroma: 0.04,
    hasAmoled: false,
  );

  static const ThemeFamily slate = ThemeFamily(
    id: 'slate',
    name: 'Slate',
    blurb: 'mono',
    neutralHue: 265,
    neutralChroma: 0.4,
    primaryHue: 265,
    primaryLightness: 0.42,
    primaryChroma: 0.012,
    primaryContainerChroma: 0.006,
    hasAmoled: true,
  );

  static const List<ThemeFamily> all = <ThemeFamily>[perch, ember, fern, slate];

  static ThemeFamily byId(String id) =>
      all.firstWhere((ThemeFamily f) => f.id == id, orElse: () => perch);

  /// Android hands over one wallpaper accent; the rest of the role map is
  /// derived exactly as a bundled family's is, so the two never diverge.
  static ThemeFamily fromSeed(Color seed) {
    final double hue = Oklch.hueOf(seed);
    return ThemeFamily(
      id: 'dynamic',
      name: 'Dynamic',
      blurb: 'wallpaper',
      neutralHue: hue,
      neutralChroma: 1,
      primaryHue: hue,
      primaryLightness: 0.55,
      primaryChroma: 0.14,
      primaryContainerChroma: 0.045,
      hasAmoled: true,
    );
  }

  PerchColors colors(Tone tone) =>
      tone == Tone.light ? _light() : _dark(amoled: tone == Tone.amoled);

  Oklch _n(double l, double c) => Oklch(l, c * neutralChroma, neutralHue);
  Oklch _p(double l, double c) => Oklch(l, c, primaryHue);

  PerchColors _light() {
    final double pc = primaryChroma;
    return PerchColors(
      surface: _n(0.99, 0.004).toColor(),
      surfaceContainer: _n(0.965, 0.008).toColor(),
      surfaceContainerHigh: _n(0.935, 0.011).toColor(),
      outline: _n(0.885, 0.012).toColor(),
      divider: _n(0.92, 0.008).toColor(),
      onSurface: _n(0.20, 0.02).toColor(),
      onSurfaceVariant: _n(0.52, 0.02).toColor(),
      onSurfaceMuted: _n(0.62, 0.02).toColor(),
      icon: _n(0.30, 0.02).toColor(),
      iconMuted: _n(0.45, 0.02).toColor(),
      primary: _p(primaryLightness, pc).toColor(),
      primaryPressed: _p(primaryLightness - 0.07, pc - 0.01).toColor(),
      primaryContainer: _p(0.92, primaryContainerChroma).toColor(),
      onPrimary: const Oklch(1, 0, 0).toColor(),
      onPrimaryContainer: _p(0.38, pc).toColor(),
      accent: _p(0.45, pc).toColor(),
      success: const Oklch(0.55, 0.10, 145).toColor(),
      warning: const Oklch(0.66, 0.13, 62).toColor(),
      danger: const Oklch(0.55, 0.16, 25).toColor(),
      dangerContainer: const Oklch(0.86, 0.05, 25).toColor(),
      shadow: const Oklch(0.35, 0.06, 265, 0.09).toColor(),
    );
  }

  PerchColors _dark({required bool amoled}) {
    // AMOLED drops the page to true black and sinks the containers under it;
    // everything else keeps its dark value.
    final double pcd = primaryChroma * 0.81;
    return PerchColors(
      surface: amoled
          ? const Oklch(0, 0, 0).toColor()
          : _n(0.205, 0.012).toColor(),
      surfaceContainer: _n(amoled ? 0.13 : 0.255, amoled ? 0.012 : 0.014)
          .toColor(),
      surfaceContainerHigh: _n(amoled ? 0.15 : 0.30, amoled ? 0.012 : 0.016)
          .toColor(),
      outline: _n(amoled ? 0.30 : 0.36, amoled ? 0.014 : 0.016).toColor(),
      divider: _n(amoled ? 0.24 : 0.30, 0.014).toColor(),
      onSurface: _n(0.96, 0.005).toColor(),
      onSurfaceVariant: _n(0.72, 0.012).toColor(),
      onSurfaceMuted: _n(0.60, 0.012).toColor(),
      icon: _n(0.90, 0.008).toColor(),
      iconMuted: _n(0.72, 0.012).toColor(),
      primary: _p(0.74, pcd).toColor(),
      primaryPressed: _p(0.68, pcd).toColor(),
      primaryContainer: _p(0.28, pcd * 0.46).toColor(),
      onPrimary: _n(0.14, 0.01).toColor(),
      onPrimaryContainer: _p(0.90, pcd * 0.46).toColor(),
      accent: _p(0.85, pcd * 0.69).toColor(),
      success: const Oklch(0.72, 0.11, 145).toColor(),
      warning: const Oklch(0.78, 0.12, 62).toColor(),
      danger: const Oklch(0.72, 0.14, 25).toColor(),
      dangerContainer: const Oklch(0.40, 0.08, 25).toColor(),
      shadow: const Oklch(0, 0, 0, 0.5).toColor(),
    );
  }
}
