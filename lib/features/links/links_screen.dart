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
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/view_mode_button.dart';
import '../folders/folder_providers.dart';
import 'link_feed.dart';
import 'link_list.dart';

/// Board 2b — the simple surface. One header, one count, one sort control, then
/// links. No folder cards, no breadcrumb, no filter row: that work belongs to
/// Folders and Search.
class LinksScreen extends ConsumerWidget {
  const LinksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final LinkViewMode mode = ref.watch(
      settingsProvider.select((AppSettings s) => s.viewMode),
    );
    final LinkSort sort = ref.watch(
      settingsProvider.select((AppSettings s) => s.sort),
    );
    final int count = ref.watch(linkCountProvider).valueOrNull ?? 0;
    final AsyncValue<LinkFeed> feed = ref.watch(linkFeedProvider(kAllLinks));

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.screen, 14, Space.screen, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Links',
                    style: PerchType.title.copyWith(
                      fontSize: 22,
                      color: c.onSurface,
                    ),
                  ),
                ),
                AppIconButton(
                  icon: Icons.search_rounded,
                  onPressed: () => context.push(Routes.search),
                  semanticLabel: 'Search links',
                  size: 40,
                ),
                ViewModeButton(
                  mode: mode,
                  onChanged: (LinkViewMode m) =>
                      ref.read(settingsProvider.notifier).setViewMode(m),
                ),
              ],
            ),
          ),
          if (count > 0)
            SectionHeader(
              label: 'All links · ${grouped(count)}',
              trailing: _SortControl(sort: sort),
            ),
          Expanded(
            // A save re-runs the feed; keeping the last page on screen while it
            // reloads stops the whole list flashing skeletons on every write.
            child: switch (feed) {
              AsyncValue<LinkFeed>(:final LinkFeed value?) =>
                value.items.isEmpty
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
                        paths: ref.watch(folderPathsProvider),
                        onLoadMore: () => ref
                            .read(linkFeedProvider(kAllLinks).notifier)
                            .loadMore(),
                      ),
              AsyncValue<LinkFeed>(:final Object error?) => ErrorStateView(
                message: '$error',
                onRetry: () => ref.invalidate(linkFeedProvider(kAllLinks)),
              ),
              _ => const ListSkeleton(),
            },
          ),
        ],
      ),
    );
  }
}

/// `Newest ↓` — opens the sort sheet.
class _SortControl extends ConsumerWidget {
  const _SortControl({required this.sort});

  final LinkSort sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    return InkWell(
      onTap: () => showSortSheet(context, ref, sort),
      borderRadius: Radii.chipR,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.sm,
          vertical: Space.sm,
        ),
        child: Text(
          '${sort.label.split(' ').first} ↓',
          style: PerchType.monoLabel.copyWith(
            fontSize: 11.5,
            color: c.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

Future<void> showSortSheet(
  BuildContext context,
  WidgetRef ref,
  LinkSort current,
) async {
  final LinkSort? picked = await showOptionSheet<LinkSort>(
    context: context,
    title: 'Sort links',
    icon: Icons.swap_vert_rounded,
    selected: current,
    options: <SheetOption<LinkSort>>[
      for (final LinkSort option in LinkSort.values)
        SheetOption<LinkSort>(value: option, label: option.label),
    ],
  );
  if (picked != null) await ref.read(settingsProvider.notifier).setSort(picked);
}
