import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'dashed_border.dart';

/// The one tag chip, in the two sizes the boards use.
///
/// Board 3c: a selected chip is filled with the tag's own colour and carries a
/// ×; an unselected one is muted with a colour dot. Board 3a: the same chip at
/// 10.5px inside a link card.
class TagChip extends StatelessWidget {
  const TagChip({
    required this.label,
    this.color,
    this.selected = false,
    this.dot = false,
    this.compact = false,
    this.add = false,
    this.onTap,
    this.onRemove,
    super.key,
  });

  final String label;

  /// The tag's resolved colour. Null takes the theme accent.
  final Color? color;

  /// Filled in [color] rather than muted.
  final bool selected;

  /// Draws the 8dp colour dot an unselected chip carries in the picker.
  final bool dot;

  /// The 10.5px, 8dp-radius form used inside a link card.
  final bool compact;

  /// The dashed `＋ Add tag` affordance.
  final bool add;
  final VoidCallback? onTap;

  /// Draws the trailing ×.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final Color fill = color ?? c.primary;
    final Color fg = selected
        ? (color == null ? c.onPrimary : (c.isDark ? c.surface : c.onPrimary))
        : (compact ? c.onSurfaceVariant : c.onSurface);
    final BorderRadius shape = BorderRadius.circular(
      compact ? Radii.chip : Radii.full,
    );

    Widget chip = Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5)
          : EdgeInsets.symmetric(horizontal: 13, vertical: selected ? 8 : 7),
      decoration: BoxDecoration(
        color: add
            ? Colors.transparent
            : selected
            ? fill
            : (compact ? c.surfaceContainerHigh : c.surfaceContainer),
        borderRadius: shape,
        border: selected || add ? null : Border.all(color: c.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 7,
        children: <Widget>[
          if (add)
            Icon(Icons.add_rounded, size: 14, color: c.onSurfaceVariant)
          else if (dot && !selected)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
            ),
          Text(
            label,
            style: compact
                ? PerchType.label.copyWith(fontSize: 10.5, color: fg)
                : PerchType.label
                      .copyWith(
                        fontSize: 12.5,
                        color: add ? c.onSurfaceVariant : fg,
                      )
                      .weight(selected ? 600 : 500),
          ),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Semantics(
                button: true,
                label: 'Remove $label',
                // The glyph stays small; the target around it does not.
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: Icon(
                    Icons.close_rounded,
                    size: compact ? 12 : 14,
                    color: fg.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (add) {
      chip = CustomPaint(
        foregroundPainter: DashedBorderPainter(c.outline),
        child: chip,
      );
    }

    // A chip that can be acted on carries a 48dp row, even though it only
    // paints ~32 (board 1j, TOUCH TARGETS).
    final Widget sized = onTap == null && onRemove == null
        ? chip
        : SizedBox(height: IconSpec.tapTarget, child: Center(child: chip));

    if (onTap == null) return sized;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(onTap: onTap, borderRadius: shape, child: sized),
    );
  }
}
