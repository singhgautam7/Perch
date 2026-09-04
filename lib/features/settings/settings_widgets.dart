import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_icon_button.dart';

/// Board 3g — the settings row: a title, its current value on the line below,
/// and either a trailing control or a chevron.
///
/// The value sits *under* the label rather than beside it, which is what keeps
/// a long value ("Everything stays on this device") from overflowing the row at
/// a large OS text scale. More and Data share this row.
class SettingsListRow extends StatelessWidget {
  const SettingsListRow({
    required this.label,
    this.value,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String label;
  final String? value;

  /// Replaces the chevron — a button, or a switch.
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final Widget row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        spacing: Space.md,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: PerchType.titleMedium.copyWith(
                    fontSize: 14,
                    color: c.onSurface,
                  ),
                ),
                if (value != null) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    value!,
                    style: PerchType.bodySmall.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: c.onSurfaceMuted,
            ),
        ],
      ),
    );

    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: value == null ? label : '$label, $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: row,
      ),
    );
  }
}

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
      // Rows grow vertically under OS text scale; they never clip.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          spacing: 13,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.lg),
              child: Icon(icon, size: 20, color: c.icon),
            ),
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

/// A row whose choice is made in place: the label with its current default in
/// mono on the right, and a full-width two-option control underneath.
///
/// Two choices do not earn a screen (board 2e), and the icons make the choice
/// legible without reading.
class SettingsChoiceRow<T> extends StatelessWidget {
  const SettingsChoiceRow({
    required this.label,
    required this.value,
    required this.options,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final String label;

  /// Shown in mono on the right, matching every other row on this hub.
  final String value;
  final List<(T, String, Widget Function(Color))> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: PerchType.titleMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: c.onSurface,
                  ),
                ),
              ),
              Text(
                value.toUpperCase(),
                style: PerchType.monoLabel.copyWith(color: c.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Container(
            height: 42,
            padding: const EdgeInsets.all(Space.xs),
            decoration: BoxDecoration(
              color: c.surfaceContainerHigh,
              borderRadius: Radii.fullR,
            ),
            child: Row(
              children: <Widget>[
                for (final (T, String, Widget Function(Color)) o in options)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: o.$1 == selected,
                      child: InkWell(
                        onTap: () => onChanged(o.$1),
                        borderRadius: Radii.fullR,
                        child: AnimatedContainer(
                          duration: Motion.of(context, Motion.fast),
                          decoration: BoxDecoration(
                            color: o.$1 == selected
                                ? c.primaryContainer
                                : Colors.transparent,
                            borderRadius: Radii.fullR,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            spacing: 7,
                            children: <Widget>[
                              o.$3(
                                o.$1 == selected ? c.onPrimaryContainer : c.iconMuted,
                              ),
                              Text(
                                o.$2,
                                style: PerchType.label
                                    .copyWith(
                                      fontSize: 13,
                                      color: o.$1 == selected
                                          ? c.onPrimaryContainer
                                          : c.iconMuted,
                                    )
                                    .weight(o.$1 == selected ? 600 : 500),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
