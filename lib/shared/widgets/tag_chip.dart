import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// Board 1j — one chip, four states.
enum ChipStyle {
  /// Neutral fill.
  plain,

  /// Accent fill, for a chosen value in a sheet.
  selected,

  /// Accent tint, for an active filter that can be removed.
  active,

  /// Dashed — "add one".
  add,
}

class TagChip extends StatelessWidget {
  const TagChip({
    required this.label,
    this.style = ChipStyle.plain,
    this.onTap,
    this.onRemove,
    this.compact = false,
    super.key,
  });

  final String label;
  final ChipStyle style;
  final VoidCallback? onTap;

  /// Draws the trailing ×.
  final VoidCallback? onRemove;

  /// The 10.5px form used inside a link card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final (Color bg, Color fg) = switch (style) {
      ChipStyle.plain => (c.surfaceContainerHigh, c.onSurfaceVariant),
      ChipStyle.selected => (c.primary, c.onPrimary),
      ChipStyle.active => (c.primaryContainer, c.accent),
      ChipStyle.add => (Colors.transparent, c.onSurfaceVariant),
    };
    final BorderRadius shape = BorderRadius.circular(compact ? Radii.chip : 9);

    final Widget chip = Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: Space.md, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: shape,
        border: style == ChipStyle.add ? Border.all(color: c.outline) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: Space.xs,
        children: <Widget>[
          if (style == ChipStyle.add)
            Icon(Icons.add_rounded, size: 14, color: fg),
          Text(
            label,
            style: compact
                ? PerchType.label.copyWith(fontSize: 10.5, color: fg)
                : PerchType.label.copyWith(color: fg),
          ),
          if (style == ChipStyle.selected)
            Icon(Icons.check_rounded, size: 13, color: fg),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Semantics(
                button: true,
                label: 'Remove $label',
                // The glyph stays 13px; the target around it does not.
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: Icon(Icons.close_rounded, size: 13, color: fg),
                ),
              ),
            ),
        ],
      ),
    );

    // A chip that can be acted on carries a 48dp row, even though it only
    // paints 30 (board 1j, TOUCH TARGETS).
    final Widget sized = onTap == null && onRemove == null
        ? chip
        : SizedBox(height: IconSpec.tapTarget, child: Center(child: chip));

    if (onTap == null) return sized;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(onTap: onTap, borderRadius: shape, child: sized),
    );
  }
}
