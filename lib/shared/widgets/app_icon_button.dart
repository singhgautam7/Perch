import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';

/// The shared layout behind every icon action — back, search, share, overflow.
///
/// One place decides the hit area, the shape and the tint, so a top bar can
/// never grow a one-off button.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 46,
    this.filled = true,
    this.tint,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// Required — an icon-only control is invisible to a screen reader without it.
  final String semanticLabel;

  /// 46 on a page, 36–40 in a top bar.
  final double size;

  /// False for the quiet actions that sit on the surface with no container.
  final bool filled;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        // The visual is `size`; the tap target is never below 48.
        width: IconSpec.tapTarget,
        height: IconSpec.tapTarget,
        child: Center(
          child: Material(
            color: filled ? c.surfaceContainer : Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  icon,
                  size: IconSpec.size,
                  color: tint ?? c.icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
