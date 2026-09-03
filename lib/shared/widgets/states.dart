import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'app_button.dart';

/// Board 1d — three stacked cards settling onto a perch. One editorial line at
/// display size does more here than an illustration.
class _PerchMark extends StatelessWidget {
  const _PerchMark();

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    BoxDecoration slab({Color? fill, bool outlined = false}) => BoxDecoration(
      color: fill ?? c.surfaceContainer,
      borderRadius: Radii.chipR,
      border: outlined ? Border.all(color: c.outline) : null,
    );

    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        children: <Widget>[
          Positioned(
            left: 4,
            top: 6,
            child: Container(
              width: 56,
              height: 20,
              decoration: slab(fill: c.primaryContainer),
            ),
          ),
          Positioned(
            right: 0,
            top: 32,
            child: Container(
              width: 44,
              height: 20,
              decoration: slab(outlined: true),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 24,
            child: Container(
              width: 60,
              height: 20,
              decoration: slab(outlined: true),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Opacity(
              opacity: 0.9,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nothing here yet — the display line, one sentence, and at most one action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.showMark = true,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool showMark;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(34, 60, 34, Space.bottomSafe),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showMark) ...<Widget>[
              const _PerchMark(),
              const SizedBox(height: Space.xl),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: PerchType.display.copyWith(
                fontSize: 26,
                height: 1.2,
                color: c.onSurface,
              ),
            ),
            const SizedBox(height: Space.row),
            Text(
              message,
              textAlign: TextAlign.center,
              style: PerchType.body.copyWith(
                fontSize: 14.5,
                height: 1.6,
                color: c.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null) ...<Widget>[
              const SizedBox(height: Space.screen),
              AppButton(
                label: actionLabel!,
                onPressed: onAction,
                type: AppButtonType.outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Something failed that the user can retry. Never a dialog.
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    title: 'That did not load',
    message: message,
    showMark: false,
    actionLabel: onRetry == null ? null : 'Try again',
    onAction: onRetry,
  );
}

/// A grey block standing in for a line of text while a page loads.
class SkeletonBar extends StatelessWidget {
  const SkeletonBar({this.width, this.height = 10, super.key});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(height / 2),
    ),
  );
}

/// The placeholder row shown while the first page of a list is read.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({this.rows = 5, super.key});

  final int rows;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: Space.screen),
      itemCount: rows,
      separatorBuilder: (BuildContext context, int _) =>
          const SizedBox(height: Space.sm),
      itemBuilder: (BuildContext context, int _) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: Radii.cardR,
          border: Border.all(color: c.outline),
        ),
        child: Row(
          spacing: Space.md,
          children: <Widget>[
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: c.surfaceContainerHigh,
                borderRadius: Radii.thumbR,
              ),
            ),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.sm,
                children: <Widget>[
                  SkeletonBar(width: 180),
                  SkeletonBar(width: 110, height: 9),
                  SkeletonBar(width: 140, height: 9),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
