@Tags(<String>['tool'])
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:perch/core/theme/oklch.dart';

/// Draws the launcher icon from board 2f and writes the PNGs
/// `flutter_launcher_icons` consumes.
///
/// It lives as a test because that is the one place a Flutter project can paint
/// with `dart:ui` and write files without pulling in an image dependency.
/// Re-run with: `flutter test tool/generate_icons_test.dart`.
///
/// Geometry is the board's, on its own 216px canvas, scaled to the output size.
void main() {
  const double board = 216;
  const double out = 1024;
  const double s = out / board;

  // A link at rest on a perch — the app's own card, and the bar it lands on.
  final ui.Color cardFill = const Oklch(0.985, 0.006, 265).toColor();
  final ui.Color barTop = const Oklch(0.72, 0.03, 265).toColor();
  final ui.Color barBottom = const Oklch(0.84, 0.02, 265).toColor();
  final ui.Color bgBase = const Oklch(0.42, 0.15, 265).toColor();
  final ui.Color bgLift = const Oklch(0.58, 0.16, 265).toColor();

  void drawCard(ui.Canvas canvas, {required ui.Color fill, bool bars = true}) {
    const ui.Rect card = ui.Rect.fromLTWH(44 * s, 56 * s, 128 * s, 60 * s);
    canvas
      ..save()
      // The tilt is 4°: enough to read as "settling" at 108dp, still legible
      // at 48dp where the text bars drop out and only the silhouette remains.
      ..translate(card.center.dx, card.center.dy)
      ..rotate(-4 * 3.1415926535 / 180)
      ..translate(-card.center.dx, -card.center.dy);

    if (bars) {
      // A drop shadow that belongs to the icon, not to the launcher.
      canvas.drawRRect(
        ui.RRect.fromRectAndRadius(
          card.translate(0, 8 * s),
          const ui.Radius.circular(20 * s),
        ),
        ui.Paint()
          ..color = const Oklch(0.20, 0.10, 265, 0.35).toColor()
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 9 * s),
      );
    }

    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(card, const ui.Radius.circular(20 * s)),
      ui.Paint()..color = fill,
    );

    if (bars) {
      canvas
        ..drawRRect(
          ui.RRect.fromRectAndRadius(
            const ui.Rect.fromLTWH(58 * s, 74 * s, 56 * s, 8 * s),
            const ui.Radius.circular(4 * s),
          ),
          ui.Paint()..color = barTop,
        )
        ..drawRRect(
          ui.RRect.fromRectAndRadius(
            const ui.Rect.fromLTWH(58 * s, 88 * s, 34 * s, 8 * s),
            const ui.Radius.circular(4 * s),
          ),
          ui.Paint()..color = barBottom,
        );
    }
    canvas.restore();

    // The perch.
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(36 * s, 140 * s, 144 * s, 10 * s),
        const ui.Radius.circular(5 * s),
      ),
      ui.Paint()..color = fill,
    );
  }

  void drawBackground(ui.Canvas canvas) {
    const ui.Rect full = ui.Rect.fromLTWH(0, 0, out, out);
    canvas
      ..drawRect(full, ui.Paint()..color = bgBase)
      // One soft radial lift toward the top-left, so the shape survives
      // circular masking on darker wallpapers.
      ..drawRect(
        full,
        ui.Paint()
          ..shader = ui.Gradient.radial(
            const ui.Offset(0.30 * out, 0.22 * out),
            0.70 * out,
            <ui.Color>[bgLift, bgLift.withValues(alpha: 0)],
          ),
      );
  }

  Future<void> write(
    String name,
    void Function(ui.Canvas canvas) paint,
  ) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    paint(ui.Canvas(recorder));
    final ui.Image image = await recorder.endRecording().toImage(
      out.toInt(),
      out.toInt(),
    );
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    await File('assets/icon/$name.png').writeAsBytes(
      bytes!.buffer.asUint8List(),
    );
  }

  test('writes the launcher icon layers', () async {
    // Legacy square icon: both layers, flattened.
    await write('icon', (ui.Canvas canvas) {
      drawBackground(canvas);
      drawCard(canvas, fill: cardFill);
    });

    // Adaptive background: the ultramarine and its lift, nothing else.
    await write('background', drawBackground);

    // The board draws the icon as it appears after masking — a 216px frame
    // standing for the 72dp visible area of a 108dp canvas. So the art has to
    // end up at 0.667 (its share of that frame) × 0.667 (the frame's share of
    // the canvas) ≈ 44% of the canvas. The icon generator insets the adaptive
    // layers to 68%, which leaves the art almost exactly where the board's own
    // 144/216 proportion already puts it.
    const double safeZoneFit = 1.0;
    void scaledArt(ui.Canvas canvas, ui.Color fill, {required bool bars}) {
      canvas
        ..save()
        ..translate(out / 2, out / 2)
        ..scale(safeZoneFit)
        ..translate(-out / 2, -out / 2);
      drawCard(canvas, fill: fill, bars: bars);
      canvas.restore();
    }

    await write('foreground', (ui.Canvas canvas) {
      scaledArt(canvas, cardFill, bars: true);
    });

    // Android 13+ themed icons: one flat silhouette at full opacity.
    await write('monochrome', (ui.Canvas canvas) {
      scaledArt(canvas, const ui.Color(0xFF000000), bars: false);
    });

    // The Android 12+ splash masks its icon to a circle of 2/3 the canvas, so
    // the art is drawn smaller here than on the launcher icon.
    await write('splash', (ui.Canvas canvas) {
      canvas
        ..save()
        ..translate(out / 2, out / 2)
        ..scale(0.62)
        ..translate(-out / 2, -out / 2);
      drawCard(canvas, fill: cardFill);
      canvas.restore();
    });

    for (final String name in <String>[
      'icon',
      'background',
      'foreground',
      'monochrome',
      'splash',
    ]) {
      expect(File('assets/icon/$name.png').existsSync(), isTrue);
    }
  });
}
