import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:perch/core/theme/oklch.dart';
import 'package:perch/core/theme/palette.dart';

String hex(Color c) {
  int ch(double v) => (v * 255).round();
  return '#${ch(c.r).toRadixString(16).padLeft(2, '0')}'
      '${ch(c.g).toRadixString(16).padLeft(2, '0')}'
      '${ch(c.b).toRadixString(16).padLeft(2, '0')}';
}

void main() {
  test('OKLCh round-trips the sRGB primaries exactly', () {
    // If the matrix or the gamma encode drifts, these stop being the
    // primaries — the cheapest possible check that the conversion is right.
    expect(hex(const Oklch(0.62796, 0.25768, 29.234).toColor()), '#ff0000');
    expect(hex(const Oklch(0.86644, 0.29483, 142.495).toColor()), '#00ff00');
    expect(hex(const Oklch(0.45201, 0.31321, 264.052).toColor()), '#0000ff');
    expect(hex(const Oklch(1, 0, 0).toColor()), '#ffffff');
    expect(hex(const Oklch(0, 0, 0).toColor()), '#000000');
  });

  test('the Perch role tokens land where the boards put them', () {
    expect(hex(const Oklch(0.99, 0.004, 265).toColor()), '#fafcff');
    expect(hex(const Oklch(0.55, 0.16, 265).toColor()), '#426bce');
    expect(hex(const Oklch(0.205, 0.012, 265).toColor()), '#14171d');
    expect(hex(const Oklch(0.96, 0.005, 265).toColor()), '#f0f2f5');
  });

  test('dark surfaces are dark and dark text is light', () {
    final PerchColors dark = ThemeFamily.perch.colors(Tone.dark);
    expect(dark.surface.computeLuminance(), lessThan(0.1));
    expect(dark.onSurface.computeLuminance(), greaterThan(0.7));

    final PerchColors light = ThemeFamily.perch.colors(Tone.light);
    expect(light.surface.computeLuminance(), greaterThan(0.9));
    expect(light.onSurface.computeLuminance(), lessThan(0.1));
  });
}
