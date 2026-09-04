import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/oklch.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/folder_card.dart';
import '../../shared/widgets/tag_chip.dart';

/// The wash behind the hero — three soft radial lifts in blue, violet and
/// cyan. It is the one place in the app with a gradient.
class HeroGlow extends StatelessWidget {
  const HeroGlow({super.key});

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    // The dark theme takes the same hues at lower lightness, so the wash reads
    // as light spilling in rather than as a grey film.
    final double l = dark ? 0.42 : 0.72;

    return IgnorePointer(
      child: RepaintBoundary(
        // Faded out along the bottom, so the wash dissolves into the page
        // instead of ending on a straight edge.
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (Rect bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Colors.white, Colors.white, Colors.transparent],
            stops: <double>[0, 0.55, 1],
          ).createShader(bounds),
          child: CustomPaint(
            painter: _GlowPainter(
              <(Alignment, double, Color)>[
                (
                  const Alignment(-0.48, -0.32),
                  0.52,
                  Oklch(l, 0.14, 265, dark ? 0.5 : 0.55).toColor(),
                ),
                (
                  const Alignment(0.48, -0.60),
                  0.44,
                  Oklch(l + 0.08, 0.10, 300, dark ? 0.4 : 0.45).toColor(),
                ),
                (
                  const Alignment(0.08, 0.30),
                  0.46,
                  Oklch(l + 0.16, 0.07, 230, dark ? 0.36 : 0.5).toColor(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter(this.lights);

  final List<(Alignment, double, Color)> lights;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (Alignment at, double extent, Color color) in lights) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            center: at,
            radius: extent * 2,
            colors: <Color>[color, color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }
  }

  @override
  bool shouldRepaint(_GlowPainter oldDelegate) =>
      oldDelegate.lights != lights;
}

/// Step 2's art: nested folders on the left, one link with its tags on the
/// right — the two halves of how Perch organises.
class OrganiseArt extends StatelessWidget {
  const OrganiseArt({super.key});

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;

    Widget folderRow(String name, int count, {required bool nested}) {
      return Padding(
        padding: EdgeInsets.only(left: nested ? Space.lg : 0, bottom: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.outline),
          ),
          child: Row(
            spacing: Space.sm,
            children: <Widget>[
              FolderGlyph(color: nested ? c.accent : c.primary, width: 17),
              Expanded(
                child: Text(
                  name,
                  style: PerchType.label.copyWith(
                    fontSize: 12.5,
                    color: c.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$count',
                style: PerchType.monoSmall.copyWith(color: c.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.md,
      children: <Widget>[
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              folderRow('Reading', 41, nested: false),
              folderRow('AI papers', 28, nested: true),
              folderRow('Essays', 19, nested: true),
              folderRow('Recipes', 9, nested: false),
            ],
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(Space.row),
            decoration: BoxDecoration(
              color: c.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  spacing: Space.sm,
                  children: <Widget>[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: c.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 6,
                        children: <Widget>[
                          _Bar(width: double.infinity, color: c.onSurfaceMuted),
                          _Bar(width: 40, color: c.outline, height: 5),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Space.row),
                const Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: <Widget>[
                    TagChip(label: 'reading', selected: true, compact: true),
                    TagChip(label: 'essays', compact: true),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.color, this.height = 6});

  final double width;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

/// A theme card: the family's three defining colours, its name, and a tick.
class ThemeSwatchCard extends StatelessWidget {
  const ThemeSwatchCard({
    required this.family,
    required this.tone,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final ThemeFamily family;
  final Tone tone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final PerchColors light = family.colors(Tone.light);
    final PerchColors dark = family.colors(Tone.dark);

    return Semantics(
      button: true,
      selected: selected,
      label: '${family.name} theme',
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.cardR,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: Radii.cardR,
            border: Border.all(
              color: selected ? c.primary : c.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                spacing: 5,
                children: <Widget>[
                  for (final Color swatch in <Color>[
                    light.surface,
                    light.primary,
                    dark.surface,
                  ])
                    Expanded(
                      child: Container(
                        height: 34,
                        decoration: BoxDecoration(
                          color: swatch,
                          borderRadius: Radii.chipR,
                          border: Border.all(color: c.outline),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      family.name,
                      style: PerchType.titleSmall.copyWith(
                        fontSize: 13.5,
                        color: c.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: c.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: c.onPrimary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A card, not a tooltip — it survives being read slowly and needs no dismissal.
class ShareHintCard extends StatelessWidget {
  const ShareHintCard({super.key});

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 14),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        spacing: Space.md,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(Icons.north_east_rounded, size: 19, color: c.accent),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Next: open any app, hit ',
                style: PerchType.bodySmall.copyWith(
                  fontSize: 12.5,
                  height: 1.5,
                  color: c.onSurfaceVariant,
                ),
                children: <InlineSpan>[
                  TextSpan(
                    text: 'Share → Perch',
                    style: PerchType.labelStrong.copyWith(
                      fontSize: 12.5,
                      color: c.onSurface,
                    ),
                  ),
                  const TextSpan(text: ' to save your first link.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
