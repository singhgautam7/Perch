import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';

/// The four destination glyphs from board 2a. They are drawn rather than taken
/// from an icon font because their geometry is specified exactly: 1.75 stroke,
/// rounded outline, sized to a 20×15 box inside a 24dp slot.
///
/// Everything else in the app uses Material Symbols Rounded, which is the same
/// drawing language at the same weight.
enum PerchGlyph { links, folders, stats, more }

class PerchIcon extends StatelessWidget {
  const PerchIcon(
    this.glyph, {
    required this.color,
    this.filled = false,
    this.background,
    super.key,
  });

  final PerchGlyph glyph;
  final Color color;

  /// The active tab fills its glyph instead of outlining it.
  final bool filled;

  /// What the [PerchGlyph.more] knobs are punched out of — the pill behind them.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 16,
      child: Center(
        child: switch (glyph) {
          PerchGlyph.links => _Links(color: color),
          PerchGlyph.folders => _Folder(color: color, filled: filled),
          PerchGlyph.stats => _Stats(color: color),
          PerchGlyph.more => _More(
            color: color,
            background: background ?? Theme.of(context).colorScheme.surface,
          ),
        },
      ),
    );
  }
}

/// Two overlapping chain links.
class _Links extends StatelessWidget {
  const _Links({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final BoxDecoration ring = BoxDecoration(
      border: Border.all(color: color, width: IconSpec.stroke),
      borderRadius: Radii.fullR,
    );
    return SizedBox(
      width: 20,
      height: 14,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 0,
            top: 0,
            child: Container(width: 13, height: 14, decoration: ring),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(width: 13, height: 14, decoration: ring),
          ),
        ],
      ),
    );
  }
}

/// A tab-folder silhouette — square top-left corner, rounded elsewhere.
class _Folder extends StatelessWidget {
  const _Folder({required this.color, required this.filled});

  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    const BorderRadius shape = BorderRadius.only(
      topLeft: Radius.circular(3),
      topRight: Radius.circular(6),
      bottomLeft: Radius.circular(6),
      bottomRight: Radius.circular(6),
    );
    return Container(
      width: 20,
      height: 15,
      decoration: BoxDecoration(
        color: filled ? color : null,
        border: filled
            ? null
            : Border.all(color: color, width: IconSpec.stroke),
        borderRadius: shape,
      ),
    );
  }
}

/// Three bars, bottom-aligned.
class _Stats extends StatelessWidget {
  const _Stats({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget bar(double height) => Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(2)),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: 3,
      children: <Widget>[bar(9), bar(15), bar(6)],
    );
  }
}

/// A two-slider tuner mark — a place with settings in it, not an overflow menu.
class _More extends StatelessWidget {
  const _More({required this.color, required this.background});

  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    Widget slider({required bool knobOnLeft}) => SizedBox(
      width: 19,
      height: 8,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: <Widget>[
          Container(
            width: 19,
            height: 2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.all(Radius.circular(2)),
            ),
          ),
          Positioned(
            left: knobOnLeft ? 3 : null,
            right: knobOnLeft ? null : 3,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: background,
                border: Border.all(color: color, width: IconSpec.stroke),
                borderRadius: const BorderRadius.all(Radius.circular(3)),
              ),
            ),
          ),
        ],
      ),
    );
    // The two 8px slider rows stack flush: that puts the bars 8 apart, which
    // is the board's 2px bar + 6px gap, and keeps the mark inside its 16px box.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        slider(knobOnLeft: true),
        slider(knobOnLeft: false),
      ],
    );
  }
}
