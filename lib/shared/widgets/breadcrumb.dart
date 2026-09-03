import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

class Crumb {
  const Crumb(this.label, this.folderId);

  final String label;

  /// Null for the root.
  final int? folderId;
}

/// `Root › … › Reading › AI papers`.
///
/// Deep nesting keeps the first crumb and the last two; the middle collapses to
/// a tappable `…` (board 1j, DEEP NESTING).
class Breadcrumb extends StatelessWidget {
  const Breadcrumb({
    required this.crumbs,
    this.onTap,
    this.compact = false,
    super.key,
  });

  final List<Crumb> crumbs;
  final void Function(int? folderId)? onTap;

  /// The 10px form that sits beside a domain on a link card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final TextStyle base = (compact ? PerchType.monoSmall : PerchType.monoLabel)
        .copyWith(color: c.onSurfaceVariant);

    final List<Widget> children = <Widget>[];
    void add(Crumb crumb, {required bool isLast}) {
      children.add(
        _CrumbText(
          label: crumb.label,
          style: isLast ? base.copyWith(color: c.accent) : base,
          onTap: onTap == null || isLast ? null : () => onTap!(crumb.folderId),
        ),
      );
    }

    final List<Crumb> shown;
    final bool collapsed = crumbs.length > 4;
    if (collapsed) {
      shown = <Crumb>[crumbs.first, ...crumbs.sublist(crumbs.length - 2)];
    } else {
      shown = crumbs;
    }

    for (int i = 0; i < shown.length; i++) {
      if (i > 0) children.add(_Separator(style: base));
      if (collapsed && i == 1) {
        children
          ..add(
            _CrumbText(
              label: '…',
              style: base,
              // Tapping the ellipsis goes to the crumb it hides nearest the top.
              onTap: onTap == null
                  ? null
                  : () => onTap!(crumbs[crumbs.length - 3].folderId),
            ),
          )
          ..add(_Separator(style: base));
      }
      add(shown[i], isLast: i == shown.length - 1);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: Space.xs,
      children: children,
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator({required this.style});

  final TextStyle style;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: 0.5,
    child: Text('›', style: style),
  );
}

class _CrumbText extends StatelessWidget {
  const _CrumbText({required this.label, required this.style, this.onTap});

  final String label;
  final TextStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget text = Text(label, style: style, overflow: TextOverflow.ellipsis);
    if (onTap == null) return text;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.chipR,
        // Every crumb stays a real target even though the text is 10px.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: text,
        ),
      ),
    );
  }
}
