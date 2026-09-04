import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/link_repository.dart';
import '../../core/db/settings_repository.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/link_card.dart';
import '../../shared/widgets/section_header.dart';
import 'link_feed.dart';
import 'link_selection.dart';

/// The three list layouts, plus the pinned section board 3f floats above them.
///
/// Every layout is builder-based and asks for the next page as it nears the
/// end, so nothing ever holds the whole table.
class LinkList extends StatelessWidget {
  const LinkList({
    required this.feed,
    required this.mode,
    required this.paths,
    required this.onLoadMore,
    required this.countLabel,
    this.countTrailing,
    this.header,
    this.pinned = const <LinkWithTags>[],
    this.showLocation = true,
    this.selection = const LinkSelection(),
    this.onTapLink,
    this.onLongPressLink,
    super.key,
  });

  final LinkFeed feed;
  final LinkViewMode mode;

  /// `folderId → "Reading › Essays"`, for the quiet location line.
  final Map<int, String> paths;
  final VoidCallback onLoadMore;

  /// `ALL LINKS · 128`, or `EVERYTHING ELSE · 126` when pins are showing.
  final String countLabel;
  final Widget? countTrailing;

  /// Rendered above everything and scrolled with it.
  final Widget? header;

  /// Board 3f — pinned links gather into their own section, no reordering.
  final List<LinkWithTags> pinned;

  /// False inside Folders, where the location is wherever you are standing.
  final bool showLocation;

  final LinkSelection selection;
  final void Function(LinkWithTags item)? onTapLink;
  final void Function(LinkWithTags item, Offset at)? onLongPressLink;

  static const EdgeInsets _side = EdgeInsets.symmetric(
    horizontal: Space.screen,
  );

  void _maybeLoadMore(int index) {
    if (feed.hasMore && index >= feed.items.length - 6) onLoadMore();
  }

  Widget _card(BuildContext context, LinkWithTags item) {
    final String? path = item.link.folderId == null
        ? 'Unsorted'
        : paths[item.link.folderId!];
    return LinkCard(
      data: item,
      mode: mode,
      locationLabel: !showLocation || mode == LinkViewMode.grid ? null : path,
      onLocationTap: item.link.folderId == null
          ? null
          : () => context.go(Routes.folder(item.link.folderId!)),
      selectionMode: selection.active,
      selected: selection.contains(item.link.id),
      onLongPress: onLongPressLink == null
          ? null
          : (Offset at) => onLongPressLink!(item, at),
      onTap: () => onTapLink == null
          ? context.push(Routes.link(item.link.id))
          : onTapLink!(item),
    );
  }

  /// One section of cards, in whichever layout is active.
  Widget _sliver(List<LinkWithTags> items, {required bool paging}) {
    return switch (mode) {
      LinkViewMode.large => SliverPadding(
        padding: _side,
        sliver: SliverList.separated(
          itemCount: items.length,
          separatorBuilder: (BuildContext context, int _) =>
              const SizedBox(height: Space.sm),
          itemBuilder: (BuildContext context, int i) {
            if (paging) _maybeLoadMore(i);
            return _card(context, items[i]);
          },
        ),
      ),
      LinkViewMode.minimal => SliverPadding(
        padding: _side,
        sliver: SliverList.builder(
          itemCount: items.length,
          itemBuilder: (BuildContext context, int i) {
            if (paging) _maybeLoadMore(i);
            return _MinimalRow(
              isFirst: i == 0,
              isLast: i == items.length - 1,
              child: _card(context, items[i]),
            );
          },
        ),
      ),
      LinkViewMode.grid => SliverPadding(
        padding: _side,
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: Space.row,
            crossAxisSpacing: Space.row,
            childAspectRatio: 0.74,
          ),
          itemCount: items.length,
          itemBuilder: (BuildContext context, int i) {
            if (paging) _maybeLoadMore(i);
            return _card(context, items[i]);
          },
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        if (header != null) SliverToBoxAdapter(child: header),
        if (pinned.isNotEmpty) ...<Widget>[
          SliverToBoxAdapter(
            child: SectionHeader(label: 'Pinned · ${grouped(pinned.length)}'),
          ),
          _sliver(pinned, paging: false),
          const SliverToBoxAdapter(child: SizedBox(height: Space.lg)),
        ],
        SliverToBoxAdapter(
          child: SectionHeader(label: countLabel, trailing: countTrailing),
        ),
        _sliver(feed.items, paging: true),
        const SliverToBoxAdapter(
          child: SizedBox(height: Space.bottomSafe),
        ),
      ],
    );
  }
}

/// Minimal reads as one container with hairlines between rows rather than a
/// card per link — but it is still built lazily, so each row draws the piece of
/// the container it happens to sit at.
class _MinimalRow extends StatelessWidget {
  const _MinimalRow({
    required this.child,
    required this.isFirst,
    required this.isLast,
  });

  final Widget child;
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
      child: child,
    );
  }
}
