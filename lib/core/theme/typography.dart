import 'package:flutter/material.dart';

/// Board 1a, section 03 — the type scale.
///
/// Instrument Sans carries the interface. Instrument Serif appears only at
/// display size, in welcome and empty states. Counts and stats use a tabular
/// mono so columns lock.
///
/// Instrument Sans is a variable font, so every weight sets `fontVariations`
/// alongside `fontWeight` — the axis is what actually moves the glyphs.
abstract final class PerchType {
  static const String sans = 'Instrument Sans';
  static const String serif = 'Instrument Serif';

  /// The platform's own monospace — `ui-monospace` in the boards.
  static const String mono = 'monospace';

  static FontWeight _fw(int weight) => FontWeight.values[weight ~/ 100 - 1];

  static TextStyle _sans(
    double size,
    double height,
    int weight, {
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: sans,
      fontSize: size,
      height: height,
      fontWeight: _fw(weight),
      fontVariations: <FontVariation>[FontVariation('wght', weight.toDouble())],
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle _mono(double size, int weight, {double? letterSpacing}) {
    return TextStyle(
      fontFamily: mono,
      fontSize: size,
      height: 1.3,
      fontWeight: _fw(weight),
      letterSpacing: letterSpacing,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
  }

  /// `display 40/1.05` — Instrument Serif, welcome and empty states only.
  static const TextStyle display = TextStyle(
    fontFamily: serif,
    fontSize: 40,
    height: 1.05,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.6,
  );

  /// Screen title in every header — Instrument Sans 22.
  static TextStyle get headerTitle =>
      _sans(22, 1.25, 600, letterSpacing: -0.2);

  /// A sheet's own title, one step down from [headerTitle].
  static const TextStyle sheetTitle = TextStyle(
    fontFamily: serif,
    fontSize: 22,
    height: 1.1,
    fontWeight: FontWeight.w400,
  );

  /// Screen title in the top bar.
  static TextStyle get screenTitle =>
      _sans(19, 1.25, 600, letterSpacing: -0.19);

  /// `title 20/1.25 · 600`
  static TextStyle get title => _sans(20, 1.25, 600, letterSpacing: -0.2);

  /// Folder name, button label, settings row.
  static TextStyle get titleMedium => _sans(14.5, 1.3, 600);

  /// Link card title.
  static TextStyle get titleSmall => _sans(13.5, 1.3, 600);

  /// `body 15/1.55`
  static TextStyle get body => _sans(15, 1.55, 400);

  /// Note body and rendered markdown.
  static TextStyle get note => _sans(13.5, 1.65, 400);

  static TextStyle get bodySmall => _sans(12, 1.5, 400);

  /// `label 12/1.3 · 500`
  static TextStyle get label => _sans(12, 1.3, 500);

  static TextStyle get labelStrong => _sans(12, 1.3, 600);

  /// `mono/tabular 13` — counts and stats.
  static TextStyle get monoTabular => _mono(13, 500);

  /// Domain rows, breadcrumbs, counts under a name.
  static TextStyle get monoLabel => _mono(11, 500);

  static TextStyle get monoSmall => _mono(10, 500);

  /// Section headers: `600 11px · letter-spacing .08em`.
  static TextStyle get sectionHeader => _mono(11, 600, letterSpacing: 0.88);

  static TextTheme textTheme(Color onSurface, Color onSurfaceVariant) {
    return TextTheme(
      displayLarge: display.copyWith(color: onSurface),
      headlineSmall: screenTitle.copyWith(color: onSurface),
      titleLarge: title.copyWith(color: onSurface),
      titleMedium: titleMedium.copyWith(color: onSurface),
      titleSmall: titleSmall.copyWith(color: onSurface),
      bodyLarge: body.copyWith(color: onSurface),
      bodyMedium: note.copyWith(color: onSurface),
      bodySmall: bodySmall.copyWith(color: onSurfaceVariant),
      labelLarge: titleMedium.copyWith(color: onSurface),
      labelMedium: label.copyWith(color: onSurfaceVariant),
      labelSmall: monoLabel.copyWith(color: onSurfaceVariant),
    );
  }
}

extension PerchTextStyle on TextStyle {
  /// Sets the weight on a variable-font style. Plain `copyWith(fontWeight:)`
  /// does nothing for Instrument Sans — the `wght` axis has to move too.
  TextStyle weight(int w) => copyWith(
    fontWeight: PerchType._fw(w),
    fontVariations: fontFamily == PerchType.sans
        ? <FontVariation>[FontVariation('wght', w.toDouble())]
        : null,
  );
}
