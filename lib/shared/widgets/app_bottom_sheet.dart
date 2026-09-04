import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'app_icon_button.dart';

/// The one sheet shell — drag handle, 28dp top radius, safe area, scrollable
/// body. Filters, pickers, option lists and confirmations all sit in it.
///
/// Boards 3b, 3c and 3e: the title is Instrument Serif, the close is the same
/// [AppIconButton] every header uses, and an [expand] sheet gets a sticky
/// header rule and a sticky footer.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    required this.child,
    this.title,
    this.titleSize = 22,
    this.description,
    this.headerAction,
    this.actions,
    this.showClose = true,
    this.scrollable = true,
    this.expand = false,
    super.key,
  });

  final Widget child;
  final String? title;
  final double titleSize;
  final String? description;

  /// Sits left of the close button — the filter sheet's Reset pill.
  final Widget? headerAction;

  /// Pinned under the body, outside the scroll area.
  final Widget? actions;
  final bool showClose;
  final bool scrollable;

  /// Board 3e — a full-height sheet whose body is the only thing that scrolls.
  final bool expand;

  bool get _hasHeader => title != null || description != null;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final Widget body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      child: child,
    );

    final Widget header = Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, 6, Space.lg, Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title != null)
                  Text(
                    title!,
                    style: PerchType.sheetTitle.copyWith(
                      fontSize: titleSize,
                      color: c.onSurface,
                    ),
                  ),
                if (description != null) ...<Widget>[
                  if (title != null) const SizedBox(height: 5),
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
          ?headerAction,
          if (showClose)
            AppIconButton(
              icon: Icons.close_rounded,
              onPressed: () => Navigator.of(context).pop(),
              semanticLabel: 'Close',
            ),
        ],
      ),
    );

    final Widget column = Column(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: <Widget>[
        const SizedBox(height: Space.md),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(color: c.outline, borderRadius: Radii.fullR),
        ),
        const SizedBox(height: Space.sm),
        if (_hasHeader) ...<Widget>[
          header,
          if (expand) Divider(color: c.outline, height: 1),
        ],
        const SizedBox(height: Space.lg),
        Flexible(
          fit: expand ? FlexFit.tight : FlexFit.loose,
          child: scrollable ? SingleChildScrollView(child: body) : body,
        ),
        if (actions != null) ...<Widget>[
          if (expand) Divider(color: c.outline, height: 1),
          const SizedBox(height: Space.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg),
            child: actions,
          ),
        ],
        const SizedBox(height: Space.screen),
      ],
    );

    return Container(
      constraints: expand
          ? BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height * 0.9,
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            )
          : const BoxConstraints(),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: Radii.sheetR,
        border: Border.all(color: c.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(top: false, child: column),
    );
  }
}

/// Opens [builder] in the shared sheet shell. Everything that presents a sheet
/// goes through here so none of them drift apart.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  double titleSize = 22,
  String? description,
  Widget? headerAction,
  Widget? actions,
  bool showClose = true,
  bool expand = false,
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
        titleSize: titleSize,
        description: description,
        headerAction: headerAction,
        actions: actions,
        showClose: showClose,
        expand: expand,
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
}) {
  return showAppBottomSheet<T>(
    context: context,
    title: title,
    description: description,
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
