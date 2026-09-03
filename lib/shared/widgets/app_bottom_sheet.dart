import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// The one sheet shell — drag handle, 28dp top radius, safe area, scrollable
/// body. Filters, pickers, option lists and confirmations all sit in it.
///
/// The header is built from whichever of [icon], [title], [description] and
/// [showClose] are supplied; a sheet with none of them is just the handle and
/// the body.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    required this.child,
    this.icon,
    this.title,
    this.description,
    this.actions,
    this.showClose = true,
    this.scrollable = true,
    super.key,
  });

  final Widget child;

  /// Sits in a tinted rounded square to the left of the title.
  final IconData? icon;
  final String? title;
  final String? description;

  /// Pinned under the body, outside the scroll area.
  final Widget? actions;
  final bool showClose;
  final bool scrollable;

  bool get _hasHeader => title != null || description != null || icon != null;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final Widget body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
      child: child,
    );

    return Container(
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.sheetR,
        border: Border.all(color: c.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SizedBox(height: Space.md),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.outline,
                borderRadius: Radii.fullR,
              ),
            ),
            if (_hasHeader) ...<Widget>[
              const SizedBox(height: Space.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: Space.md,
                  children: <Widget>[
                    if (icon != null)
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: c.primaryContainer,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(icon, size: 19, color: c.accent),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (title != null)
                            Text(
                              title!,
                              style: PerchType.title.copyWith(
                                color: c.onSurface,
                              ),
                            ),
                          if (description != null) ...<Widget>[
                            if (title != null) const SizedBox(height: Space.xs),
                            Text(
                              description!,
                              style: PerchType.bodySmall.copyWith(
                                height: 1.5,
                                color: c.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (showClose)
                      _CloseButton(onTap: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Space.lg),
            Flexible(child: scrollable ? SingleChildScrollView(child: body) : body),
            if (actions != null) ...<Widget>[
              const SizedBox(height: Space.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                child: actions,
              ),
            ],
            const SizedBox(height: Space.screen),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Semantics(
      button: true,
      label: 'Close',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: c.surfaceContainerHigh,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.close_rounded, size: 17, color: c.icon),
        ),
      ),
    );
  }
}

/// Opens [builder] in the shared sheet shell. Everything that presents a sheet
/// goes through here so none of them drift apart.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  String? description,
  IconData? icon,
  Widget? actions,
  bool showClose = true,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // The root navigator, so a sheet covers the floating nav instead of being
    // drawn underneath it by whichever tab branch opened it.
    useRootNavigator: true,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: context.colors.onSurface.withValues(alpha: 0.32),
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: AppBottomSheet(
        title: title,
        description: description,
        icon: icon,
        actions: actions,
        showClose: showClose,
        child: Builder(builder: builder),
      ),
    ),
  );
}

/// One choice in [showOptionSheet].
class SheetOption<T> {
  const SheetOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.leading,
  });

  final T value;
  final String label;
  final String? description;
  final IconData? icon;

  /// Used where the choice has its own mark rather than a Material icon — the
  /// nav glyphs, or a view-mode diagram.
  final Widget Function(Color color)? leading;
}

/// A single-select list in the shared sheet: the option, what it means, and a
/// tick on the one in effect.
Future<T?> showOptionSheet<T>({
  required BuildContext context,
  required String title,
  required List<SheetOption<T>> options,
  required T selected,
  String? description,
  IconData? icon,
}) {
  return showAppBottomSheet<T>(
    context: context,
    title: title,
    description: description,
    icon: icon,
    builder: (BuildContext sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final SheetOption<T> option in options)
          _OptionRow<T>(
            option: option,
            selected: option.value == selected,
            onTap: () => Navigator.of(sheetContext).pop(option.value),
          ),
      ],
    ),
  );
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SheetOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final Color mark = selected ? c.accent : c.iconMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: Space.md,
            ),
            decoration: BoxDecoration(
              color: selected ? c.primaryContainer : c.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? c.accent : Colors.transparent,
              ),
            ),
            child: Row(
              spacing: Space.md,
              children: <Widget>[
                if (option.leading != null)
                  SizedBox(width: 22, child: Center(child: option.leading!(mark)))
                else if (option.icon != null)
                  SizedBox(
                    width: 22,
                    child: Icon(option.icon, size: 20, color: mark),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        option.label,
                        style: PerchType.titleMedium.copyWith(
                          color: selected ? c.onPrimaryContainer : c.onSurface,
                        ),
                      ),
                      if (option.description != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          option.description!,
                          style: PerchType.bodySmall.copyWith(
                            fontSize: 11.5,
                            color: selected ? c.accent : c.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: c.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: c.onPrimary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
