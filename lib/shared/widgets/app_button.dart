import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'dashed_border.dart';

/// Board 1j — every Save / Next / Cancel in the app is one of these.
enum AppButtonType {
  /// Accent fill. One per screen.
  primary,

  /// Filled, quiet — sits next to a primary.
  secondary,

  /// 1px outline on the page surface.
  outlined,

  /// Reads as unavailable without being disabled.
  muted,

  /// Dashed — "add another one of these".
  dotted,

  /// Destructive.
  danger,
}

/// The one button. Height, radius, padding and label style all come from
/// tokens, so a button never drifts from the sheet.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.type = AppButtonType.primary,
    this.icon,
    this.loading = false,
    this.fullWidth = false,
    this.compact = false,
    super.key,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final AppButtonType type;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;

  /// The 30–32dp inline form — "Create" beside a new-folder field.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final bool disabled = onPressed == null || loading;
    final _ButtonSkin skin = _skin(c, disabled: disabled);
    final double height = compact ? 32 : 46;

    final Widget content = Row(
      mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: Space.sm,
      children: <Widget>[
        if (loading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: skin.fg),
          )
        else if (icon != null)
          Icon(icon, size: compact ? 16 : 18, color: skin.fg),
        Text(
          label,
          style: (compact ? PerchType.labelStrong : PerchType.titleMedium)
              .copyWith(color: skin.fg),
        ),
      ],
    );

    final bool dashed = type == AppButtonType.dotted && !disabled;
    Widget button = SizedBox(
      height: height,
      width: fullWidth ? double.infinity : null,
      child: Material(
        color: skin.bg,
        shape: StadiumBorder(
          side: skin.border == null || dashed
              ? BorderSide.none
              : BorderSide(color: skin.border!),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 13 : 22),
            child: content,
          ),
        ),
      ),
    );

    // The dashes belong to the button's own outline, so they are painted around
    // it rather than around its label.
    if (dashed) {
      button = CustomPaint(
        foregroundPainter: DashedBorderPainter(skin.border!),
        child: button,
      );
    }

    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: button,
    );
  }

  _ButtonSkin _skin(PerchColors c, {required bool disabled}) {
    if (disabled) {
      return _ButtonSkin(bg: c.surfaceContainerHigh, fg: c.onSurfaceMuted);
    }
    return switch (type) {
      AppButtonType.primary => _ButtonSkin(bg: c.primary, fg: c.onPrimary),
      AppButtonType.secondary => _ButtonSkin(
        bg: c.surfaceContainerHigh,
        fg: c.onSurface,
      ),
      AppButtonType.outlined => _ButtonSkin(
        bg: Colors.transparent,
        fg: c.onSurface,
        border: c.outline,
      ),
      AppButtonType.muted => _ButtonSkin(
        bg: c.surfaceContainer,
        fg: c.onSurfaceVariant,
      ),
      AppButtonType.dotted => _ButtonSkin(
        bg: Colors.transparent,
        fg: c.onSurfaceVariant,
        border: c.outline,
      ),
      AppButtonType.danger => _ButtonSkin(bg: c.danger, fg: c.onPrimary),
    };
  }
}

class _ButtonSkin {
  const _ButtonSkin({required this.bg, required this.fg, this.border});

  final Color bg;
  final Color fg;
  final Color? border;
}
