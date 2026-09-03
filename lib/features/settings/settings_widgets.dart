import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_icon_button.dart';

/// A titled group of rows, drawn as one rounded container with hairlines
/// between them.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.label, required this.children, super.key});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Text(
              label.toUpperCase(),
              style: PerchType.sectionHeader.copyWith(
                fontSize: 10.5,
                color: c.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: c.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < children.length; i++) ...<Widget>[
                  if (i > 0) Divider(color: c.divider, height: 1),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row: an icon, a label, its current value in mono on the right, and a
/// chevron if it leads somewhere. Most questions are answered without opening
/// anything.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  /// Replaces the value and chevron — a switch, or a segmented control.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: SizedBox(
        height: 56,
        child: Row(
          spacing: 13,
          children: <Widget>[
            Icon(icon, size: 20, color: c.icon),
            Expanded(
              child: Text(
                label,
                style: PerchType.titleMedium.copyWith(color: c.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null)
              trailing!
            else ...<Widget>[
              if (value != null)
                Text(
                  value!,
                  style: PerchType.monoLabel.copyWith(
                    fontSize: 11.5,
                    color: c.onSurfaceVariant,
                  ),
                ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: c.onSurfaceMuted,
                ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return content;
    return Semantics(
      button: true,
      label: value == null ? label : '$label, $value',
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// A two-option segmented control. Two choices do not earn a screen.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    required this.options,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<(T, String, IconData)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
      height: 38,
      padding: const EdgeInsets.all(Space.xs),
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: Radii.fullR,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final (T, String, IconData) o in options)
            Semantics(
              button: true,
              selected: o.$1 == selected,
              child: InkWell(
                onTap: () => onChanged(o.$1),
                borderRadius: Radii.fullR,
                child: AnimatedContainer(
                  duration: Motion.of(context, Motion.fast),
                  padding: const EdgeInsets.symmetric(horizontal: Space.md),
                  decoration: BoxDecoration(
                    color: o.$1 == selected ? c.surface : Colors.transparent,
                    borderRadius: Radii.fullR,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 6,
                    children: <Widget>[
                      Icon(
                        o.$3,
                        size: 15,
                        color: o.$1 == selected ? c.onSurface : c.iconMuted,
                      ),
                      Text(
                        o.$2,
                        style: PerchType.label.copyWith(
                          color: o.$1 == selected
                              ? c.onSurface
                              : c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The standard sub-page header: back button, title.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, 6),
              child: Row(
                spacing: Space.row,
                children: <Widget>[
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                    semanticLabel: 'Back',
                    size: 40,
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: PerchType.screenTitle.copyWith(color: c.onSurface),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.screen,
                  Space.md,
                  Space.screen,
                  Space.xxl,
                ),
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
