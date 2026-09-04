import 'package:flutter/material.dart';

/// Design tokens from `/specs/design/` board 1a (foundations) and 1b (motion).
///
/// Nothing in a feature names a raw color, size, radius or duration — it comes
/// from here or from [PerchColors].

/// 4 · 8 · 12 · 16 · 24 · 32, plus the screen-level values called out in 1a.
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Screen margin.
  static const double screen = 20;

  /// Gap between rows in a list.
  static const double row = 10;

  /// Gap between sections on a screen.
  static const double section = 28;

  /// Bottom padding on every scrollable so content clears the floating nav.
  static const double bottomSafe = 108;
}

/// 8 · chip, 14 · thumb, 20 · card, 28 · sheet, full · pill/FAB.
abstract final class Radii {
  static const double chip = 8;
  static const double thumb = 14;
  static const double card = 20;
  static const double sheet = 28;
  static const double full = 999;

  static const BorderRadius chipR = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius thumbR = BorderRadius.all(Radius.circular(thumb));
  static const BorderRadius cardR = BorderRadius.all(Radius.circular(card));
  static const BorderRadius sheetR = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
  static const BorderRadius fullR = BorderRadius.all(Radius.circular(full));
}

/// One rounded outline set, 24dp, 1.75 stroke, 48dp tap target.
abstract final class IconSpec {
  static const double size = 24;
  static const double stroke = 1.75;
  static const double tapTarget = 48;
}

/// Board 1b — 150–260ms, spring for finger-caused, decelerate for system-caused.
abstract final class Motion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration navIndicator = Duration(milliseconds: 220);
  static const Duration containerTransform = Duration(milliseconds: 240);
  static const Duration sheet = Duration(milliseconds: 260);
  static const Duration folderOpen = Duration(milliseconds: 200);
  static const Duration reflow = Duration(milliseconds: 230);
  static const Duration navHide = Duration(milliseconds: 160);
  static const Duration shimmerLoop = Duration(milliseconds: 1100);

  /// Board 3h — the snackbar enters from its anchored edge and leaves the way
  /// the finger sent it.
  static const Duration snackEnter = Duration(milliseconds: 180);
  static const Duration snackExit = Duration(milliseconds: 140);

  /// Anything the finger caused.
  static const Curve spring = Curves.easeOutBack;

  /// Anything the system caused.
  static const Curve decelerate = Curves.easeOutCubic;
  static const Curve standard = Curves.easeInOut;

  /// Under OS reduced motion: transforms become cross-fades, springs go linear.
  static const Duration reducedFade = Duration(milliseconds: 90);
  static const Duration reducedSpring = Duration(milliseconds: 120);

  static bool reduced(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    return mq.disableAnimations || mq.accessibleNavigation;
  }

  /// Duration to actually use, honouring reduced motion.
  static Duration of(BuildContext context, Duration full) =>
      reduced(context) ? reducedFade : full;

  static Curve curveOf(BuildContext context, Curve full) =>
      reduced(context) ? Curves.linear : full;
}

/// Depth lives in 1px outlines; shadow is reserved for the two floating objects.
abstract final class Elevations {
  static const double navPill = 6;
  static const double fab = 6;
}
