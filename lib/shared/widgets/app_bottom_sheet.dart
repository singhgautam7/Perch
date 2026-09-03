import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// The one sheet shell — drag handle, 28dp top radius, safe area, scrollable
/// body. Filters, folder picker, quick save and confirmations all sit in it.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    required this.child,
    this.title,
    this.actions,
    this.scrollable = true,
    super.key,
  });

  final Widget child;
  final String? title;

  /// Pinned under the body, outside the scroll area.
  final Widget? actions;
  final bool scrollable;

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
            if (title != null) ...<Widget>[
              const SizedBox(height: Space.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.screen),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title!,
                    style: PerchType.title.copyWith(color: c.onSurface),
                  ),
                ),
              ),
            ],
            const SizedBox(height: Space.lg),
            Flexible(
              child: scrollable
                  ? SingleChildScrollView(child: body)
                  : body,
            ),
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

/// Opens [builder] in the shared sheet shell. Everything that presents a sheet
/// goes through here so none of them drift apart.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  Widget? actions,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: context.colors.onSurface.withValues(alpha: 0.32),
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: AppBottomSheet(
        title: title,
        actions: actions,
        child: Builder(builder: builder),
      ),
    ),
  );
}
