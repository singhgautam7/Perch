import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/link_repository.dart';
import '../../core/db/settings_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_menu.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/view_mode_button.dart';
import '../folders/folder_providers.dart';
import 'link_feed.dart';
import 'link_selection.dart';
import 'link_list.dart';
import 'selection_bar.dart';

/// Boards 2b and 3a — the flat list of everything, under the one common header.
/// Identical to Folders in every respect except the body list.
class LinksScreen extends ConsumerWidget {
  const LinksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LinkViewMode mode = ref.watch(
      settingsProvider.select((AppSettings s) => s.viewMode),
    );
    final LinkSort sort = ref.watch(
      settingsProvider.select((AppSettings s) => s.sort),
    );
    final int count = ref.watch(linkCountProvider).valueOrNull ?? 0;
    final AsyncValue<LinkFeed> feed = ref.watch(linkFeedProvider(kAllLinks));
    final List<LinkWithTags> pinned =
        ref.watch(pinnedLinksProvider(kAllLinks)).valueOrNull ??
        const <LinkWithTags>[];
    final LinkSelection selection = ref.watch(linkSelectionProvider);

    return SelectionScope(
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                if (selection.active)
                  SelectionBar(
                    visible: feed.valueOrNull?.items ?? const <LinkWithTags>[],
                  )
                else
                  AppHeader(
                    title: 'Links',
                    actions: <Widget>[
                      AppIconButton(
                        icon: Icons.search_rounded,
                        onPressed: () => context.push(Routes.search),
                        semanticLabel: 'Search links',
                      ),
                      ViewModeButton(
                        mode: mode,
                        onChanged: (LinkViewMode m) =>
                            ref.read(settingsProvider.notifier).setViewMode(m),
                      ),
                      ListOverflowButton(sort: sort),
                    ],
                  ),
                Expanded(
                  // A save re-runs the feed; keeping the last page on screen while
                  // it reloads stops the whole list flashing skeletons.
                  child: switch (feed) {
                    AsyncValue<LinkFeed>(:final LinkFeed value?) =>
                      value.items.isEmpty && pinned.isEmpty
                          ? EmptyState(
                              title: 'Nothing perched yet',
                              message:
                                  'Share a link from any app and it lands here. '
                                  'Or tap ＋ to paste one.',
                              actionLabel: 'Add your first link',
                              onAction: () => context.push(Routes.add),
                            )
                          : LinkList(
                              feed: value,
                              mode: mode,
                              pinned: pinned,
                              countLabel: pinned.isEmpty
                                  ? 'All links · ${grouped(count)}'
                                  : 'Everything else · '
                                        '${grouped(count - pinned.length)}',
                              countTrailing: SortControl(sort: sort),
                              paths: ref.watch(folderPathsProvider),
                              selection: selection,
                              onTapLink: (LinkWithTags item) =>
                                  onLinkTapped(context, ref, item, selection),
                              onLongPressLink: (LinkWithTags item, Offset at) =>
                                  onLinkHeld(context, ref, item, at, selection),
                              onLoadMore: () => ref
                                  .read(linkFeedProvider(kAllLinks).notifier)
                                  .loadMore(),
                            ),
                    AsyncValue<LinkFeed>(:final Object error?) =>
                      ErrorStateView(
                        message: '$error',
                        onRetry: () =>
                            ref.invalidate(linkFeedProvider(kAllLinks)),
                      ),
                    _ => const ListSkeleton(),
                  },
                ),
              ],
            ),
            if (selection.active) const SelectionActionBar(),
          ],
        ),
      ),
    );
  }
}

/// `Newest ↓` — the mono control beside every count row (board 3e).
class SortControl extends ConsumerWidget {
  const SortControl({required this.sort, this.onChanged, super.key});

  final LinkSort sort;

  /// Null writes the app-wide preference; Search passes its own setter.
  final ValueChanged<LinkSort>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    return Semantics(
      button: true,
      label: 'Sort: ${sort.label}',
      child: InkWell(
        onTap: () => showSortSheet(context, ref, sort, onChanged: onChanged),
        borderRadius: Radii.chipR,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: Space.sm,
          ),
          child: Text(
            '${sort.short} ↓',
            style: PerchType.monoLabel.copyWith(
              fontSize: 11.5,
              color: c.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showSortSheet(
  BuildContext context,
  WidgetRef ref,
  LinkSort current, {
  ValueChanged<LinkSort>? onChanged,
}) async {
  final LinkSort? picked = await showOptionSheet<LinkSort>(
    context: context,
    title: 'Sort links',
    selected: current,
    options: <SheetOption<LinkSort>>[
      for (final LinkSort option in LinkSort.values)
        SheetOption<LinkSort>(value: option, label: option.label),
    ],
  );
  if (picked == null) return;
  if (onChanged != null) {
    onChanged(picked);
  } else {
    await ref.read(settingsProvider.notifier).setSort(picked);
  }
}

/// The third header button on Links and Folders.
///
/// Board 3a names the slot but does not spell out its contents; it carries the
/// two behaviours that otherwise have only one entry point — sorting, and the
/// way into multi-select without holding a card.
enum _ListMenu { sort, select }

class ListOverflowButton extends ConsumerWidget {
  const ListOverflowButton({required this.sort, this.extra, super.key});

  final LinkSort sort;

  /// Folder-specific rows, appended above the shared ones.
  final List<Widget>? extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Builder(
      builder: (BuildContext anchor) => AppIconButton(
        icon: Icons.more_vert_rounded,
        semanticLabel: 'More actions',
        onPressed: () async {
          final _ListMenu? picked = await showAppMenu<_ListMenu>(
            context: anchor,
            anchorContext: anchor,
            entries: const <AppMenuEntry<_ListMenu>>[
              AppMenuEntry<_ListMenu>(value: _ListMenu.sort, label: 'Sort…'),
              AppMenuEntry<_ListMenu>(
                value: _ListMenu.select,
                label: 'Select links',
              ),
            ],
          );
          if (picked == null || !context.mounted) return;
          switch (picked) {
            case _ListMenu.sort:
              await showSortSheet(context, ref, sort);
            case _ListMenu.select:
              ref.read(linkSelectionProvider.notifier).enter();
          }
        },
      ),
    );
  }
}
