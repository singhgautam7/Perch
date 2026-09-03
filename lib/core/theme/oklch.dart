import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// A color expressed in OKLCh, the space the design boards are authored in.
///
/// Keeping spec values verbatim (`oklch(0.55 0.16 265)`) means a palette in this
/// codebase can be diffed against `/specs/design/` by eye. Conversion happens once
/// per theme build, and themes are cached — see `app_theme.dart`.
@immutable
class Oklch {
  const Oklch(this.l, this.c, this.h, [this.alpha = 1.0]);

  /// Perceptual lightness, 0..1.
  final double l;

  /// Chroma, 0..~0.4.
  final double c;

  /// Hue in degrees.
  final double h;
  final double alpha;

  Oklch withAlpha(double a) => Oklch(l, c, h, a);

  /// Same hue and chroma, different lightness — used for pressed/hover states.
  Oklch lightness(double newL) => Oklch(newL, c, h, alpha);

  Color toColor() {
    final double hRad = h * math.pi / 180.0;
    final double a = c * math.cos(hRad);
    final double b = c * math.sin(hRad);

    final double lp = l + 0.3963377774 * a + 0.2158037573 * b;
    final double mp = l - 0.1055613458 * a - 0.0638541728 * b;
    final double sp = l - 0.0894841775 * a - 1.2914855480 * b;

    final double lc = lp * lp * lp;
    final double mc = mp * mp * mp;
    final double sc = sp * sp * sp;

    final double r = 4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc;
    final double g = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc;
    final double bl = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc;

    return Color.from(
      alpha: alpha,
      red: _encode(r),
      green: _encode(g),
      blue: _encode(bl),
    );
  }

  /// Linear-light channel to gamma-encoded sRGB, clamped into gamut.
  static double _encode(double v) {
    final double s = v <= 0.0031308
        ? 12.92 * v
        : 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;
    return s.clamp(0.0, 1.0);
  }

  @override
  bool operator ==(Object other) =>
      other is Oklch &&
      other.l == l &&
      other.c == c &&
      other.h == h &&
      other.alpha == alpha;

  @override
  int get hashCode => Object.hash(l, c, h, alpha);
}
