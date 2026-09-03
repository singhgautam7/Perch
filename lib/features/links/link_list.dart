import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/link_repository.dart';
import '../../core/db/settings_repository.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/link_card.dart';
import 'link_feed.dart';

/// The three list layouts. Every one is builder-based and asks for the next
/// page as it nears the end, so nothing ever holds the whole table.
class LinkList extends StatelessWidget {
  const LinkList({
    required this.feed,
    required this.mode,
    required this.paths,
    required this.onLoadMore,
    this.header,
    super.key,
  });

  final LinkFeed feed;
  final LinkViewMode mode;

  /// `folderId → "Reading › Essays"`, for the quiet location line.
  final Map<int, String> paths;
  final VoidCallback onLoadMore;

  /// Rendered above the links and scrolled with them.
  final Widget? header;

  static const EdgeInsets _padding = EdgeInsets.fromLTRB(
    Space.screen,
    0,
    Space.screen,
    Space.bottomSafe,
  );

  void _maybeLoadMore(int index) {
    if (feed.hasMore && index >= feed.items.length - 6) onLoadMore();
  }

  Widget _card(BuildContext context, int index) {
    _maybeLoadMore(index);
    final LinkWithTags item = feed.items[index];
    final String? path = item.link.folderId == null
        ? 'Unsorted'
        : paths[item.link.folderId!];
    return LinkCard(
      data: item,
      mode: mode,
      locationLabel: mode == LinkViewMode.grid ? null : path,
      onLocationTap: item.link.folderId == null
          ? null
          : () => context.go(Routes.folder(item.link.folderId!)),
      onTap: () => context.push(Routes.link(item.link.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      LinkViewMode.large => CustomScrollView(
        slivers: <Widget>[
          if (header != null) SliverToBoxAdapter(child: header),
          SliverPadding(
            padding: _padding,
            sliver: SliverList.separated(
              itemCount: feed.items.length,
              separatorBuilder: (BuildContext context, int _) =>
                  const SizedBox(height: Space.sm),
              itemBuilder: _card,
            ),
          ),
        ],
      ),
      LinkViewMode.minimal => CustomScrollView(
        slivers: <Widget>[
          if (header != null) SliverToBoxAdapter(child: header),
          SliverPadding(
            padding: _padding,
            sliver: SliverList.builder(
              itemCount: feed.items.length,
              itemBuilder: (BuildContext context, int index) => _MinimalRow(
                list: this,
                index: index,
                isFirst: index == 0,
                isLast: index == feed.items.length - 1,
              ),
            ),
          ),
        ],
      ),
      LinkViewMode.grid => CustomScrollView(
        slivers: <Widget>[
          if (header != null) SliverToBoxAdapter(child: header),
          SliverPadding(
            padding: _padding,
            sliver: SliverGrid.builder(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: Space.row,
                    crossAxisSpacing: Space.row,
                    childAspectRatio: 0.74,
                  ),
              itemCount: feed.items.length,
              itemBuilder: _card,
            ),
          ),
        ],
      ),
    };
  }
}

/// Minimal reads as one container with hairlines between rows rather than a
/// card per link — but it is still built lazily, so each row draws the piece of
/// the container it happens to sit at.
class _MinimalRow extends StatelessWidget {
  const _MinimalRow({
    required this.list,
    required this.index,
    required this.isFirst,
    required this.isLast,
  });

  final LinkList list;
  final int index;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    const Radius r = Radius.circular(16);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        border: Border(
          left: BorderSide(color: c.outline),
          right: BorderSide(color: c.outline),
          top: BorderSide(color: isFirst ? c.outline : c.divider),
          bottom: isLast ? BorderSide(color: c.outline) : BorderSide.none,
        ),
        borderRadius: BorderRadius.vertical(
          top: isFirst ? r : Radius.zero,
          bottom: isLast ? r : Radius.zero,
        ),
      ),
      child: list._card(context, index),
    );
  }
}
