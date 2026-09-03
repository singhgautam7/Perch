import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// `ALL LINKS · 128` on the left, an action or a value on the right.
///
/// In Folders the trailing slot carries `＋ New folder`.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.label, this.trailing, super.key});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.screen,
        6,
        Space.screen,
        Space.md,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: PerchType.sectionHeader.copyWith(
                color: c.onSurfaceVariant,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// The `＋ New folder` pill that lives in a section header.
class HeaderActionPill extends StatelessWidget {
  const HeaderActionPill({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.fullR,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          decoration: BoxDecoration(
            color: c.surfaceContainerHigh,
            borderRadius: Radii.fullR,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: Space.xs,
            children: <Widget>[
              Icon(Icons.add_rounded, size: 15, color: c.accent),
              Text(
                label,
                style: PerchType.labelStrong.copyWith(color: c.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
