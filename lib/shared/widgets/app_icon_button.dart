import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';

/// Board 3a, A10 — back, search, share, overflow, edit and the view-switcher
/// are all *this* button. No second glyph style, no bare icons, no hamburger.
///
/// One place decides the hit area, the shape, the fill and the tint, so a top
/// bar can never grow a one-off.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.onPressed,
    required this.semanticLabel,
    this.icon,
    this.child,
    this.size = 40,
    this.glyphSize = 20,
    this.filled = true,
    this.active = false,
    this.tint,
    super.key,
  });

  /// Either an [icon] or a custom [child] glyph — never both.
  final IconData? icon;
  final Widget Function(Color color)? child;
  final VoidCallback? onPressed;

  /// Required — an icon-only control is invisible to a screen reader without it.
  final String semanticLabel;

  /// 40 everywhere the design shows one; 46 for the two page-level actions.
  final double size;
  final double glyphSize;

  /// False only for the quiet in-field dismisses that sit on a tinted card.
  final bool filled;

  /// The one variation the board allows: the open view-switcher.
  final bool active;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final Color fg = tint ?? (active ? c.onPrimaryContainer : c.icon);
    final Color bg = active
        ? c.primaryContainer
        : (filled ? c.surfaceContainerHigh : Colors.transparent);

    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        // The visual is `size`; the tap target is never below 48.
        width: IconSpec.tapTarget,
        height: IconSpec.tapTarget,
        child: Center(
          child: Material(
            color: bg,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                width: size,
                height: size,
                child: Center(
                  child: child != null
                      ? child!(fg)
                      : Icon(icon, size: glyphSize, color: fg),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
