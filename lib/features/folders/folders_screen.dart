import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/folder_repository.dart';
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
import '../../shared/widgets/breadcrumb.dart';
import '../../shared/widgets/folder_card.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/view_mode_button.dart';
import '../links/link_feed.dart';
import '../links/link_list.dart';
import 'folder_actions.dart';
import 'folder_providers.dart';
import 'new_folder_row.dart';

/// Board 2c — the structural surface, in the same language as Links: a title,
/// a count, a sort control, and the same search and view controls.
///
/// The root browses like a file explorer: folders first, then the links that
/// sit loose at the root, rather than hiding them behind an Unsorted row.
class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({this.folderId, super.key});

  final int? folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FolderSummary>> children = ref.watch(
      folderChildrenProvider(folderId),
    );
    final AppSettings settings = ref.watch(settingsProvider);

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          _TopBar(folderId: folderId, settings: settings),
          if (folderId != null) _CrumbBar(folderId: folderId),
          Expanded(
            child: switch (children) {
              AsyncValue<List<FolderSummary>>(
                :final List<FolderSummary> value?,
              ) =>
                _Body(
                  folderId: folderId,
                  folders: value,
                  settings: settings,
                ),
              AsyncValue<List<FolderSummary>>(:final Object error?) =>
                ErrorStateView(message: '$error'),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.folderId, required this.settings});

  final int? folderId;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final Folder? folder = folderId == null
        ? null
        : ref
              .watch(allFoldersProvider)
              .valueOrNull
              ?.where((Folder f) => f.id == folderId)
              .firstOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 14, Space.screen, 4),
      child: Row(
        spacing: 9,
        children: <Widget>[
          if (folderId != null)
            AppIconButton(
              icon: Icons.arrow_back_rounded,
              // A breadcrumb jump resets the branch stack, so back has to be
              // able to fall through to the parent folder.
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(
                      folder?.parentId == null
                          ? Routes.folders
                          : Routes.folder(folder!.parentId!),
                    ),
              semanticLabel: 'Back',
              size: 36,
            ),
          Expanded(
            child: Text(
              folder?.name ?? 'Folders',
              style: PerchType.title.copyWith(fontSize: 22, color: c.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppIconButton(
            icon: Icons.search_rounded,
            onPressed: () => context.push(Routes.search),
            semanticLabel: 'Search links',
            size: 40,
          ),
          // At the root the switcher lays out folders; inside a folder it
          // applies to that folder's links, as the board specifies.
          if (folderId == null)
            _FolderViewButton(mode: settings.folderView)
          else
            ViewModeButton(
              mode: settings.viewMode,
              onChanged: (LinkViewMode m) =>
                  ref.read(settingsProvider.notifier).setViewMode(m),
            ),
        ],
      ),
    );
  }
}

class _FolderViewButton extends ConsumerWidget {
  const _FolderViewButton({required this.mode});

  final FolderViewMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final FolderViewMode next = mode == FolderViewMode.list
        ? FolderViewMode.grid
        : FolderViewMode.list;

    return Semantics(
      button: true,
      label: '${mode.label} layout. Switch to ${next.label}',
      child: SizedBox(
        width: IconSpec.tapTarget,
        height: IconSpec.tapTarget,
        child: Center(
          child: Material(
            color: c.surfaceContainerHigh,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () =>
                  ref.read(settingsProvider.notifier).setFolderView(next),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: ViewModeGlyph(
                    mode: mode == FolderViewMode.list
                        ? LinkViewMode.minimal
                        : LinkViewMode.grid,
                    color: c.icon,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CrumbBar extends ConsumerWidget {
  const _CrumbBar({required this.folderId});

  final int? folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Crumb> crumbs =
        ref.watch(breadcrumbProvider(folderId)).valueOrNull ?? const <Crumb>[];
    if (crumbs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.screen,
        0,
        Space.screen,
        Space.sm,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Breadcrumb(
          crumbs: crumbs,
          onTap: (int? id) => id == null
              ? context.go(Routes.folders)
              : context.go(Routes.folder(id)),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.folderId,
    required this.folders,
    required this.settings,
  });

  final int? folderId;
  final List<FolderSummary> folders;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String locationName = folderId == null
        ? 'Root'
        : ref
                  .watch(allFoldersProvider)
                  .valueOrNull
                  ?.where((Folder f) => f.id == folderId)
                  .firstOrNull
                  ?.name ??
              'Root';
    final int totalFolders =
        ref.watch(folderCountProvider).valueOrNull ?? folders.length;

    final Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          label: folderId == null
              ? 'All folders · ${grouped(totalFolders)}'
              : 'Folders · ${grouped(folders.length)}',
          trailing: _FolderSortControl(sort: settings.folderSort),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.screen,
            0,
            Space.screen,
            14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              NewFolderRow(
                locationName: locationName,
                onCreate: (String name) => ref
                    .read(folderRepositoryProvider)
                    .create(name: name, parentId: folderId),
              ),
              if (folders.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                _FolderLayout(folders: folders, settings: settings),
              ],
              if (folders.isNotEmpty) const SizedBox(height: Space.lg),
            ],
          ),
        ),
      ],
    );

    // The links at this location, drawn exactly as they are on the Links tab.
    // The root is no exception: loose links show here, like a file explorer.
    final AsyncValue<LinkFeed> feed = ref.watch(
      linkFeedProvider(folderScope(folderId)),
    );

    // Same as Links: the previous page stays put while the feed reloads.
    final LinkFeed? loaded = feed.valueOrNull;
    if (feed.hasError && loaded == null) {
      return ErrorStateView(message: '${feed.error}');
    }
    if (loaded == null) return SingleChildScrollView(child: header);

    return (LinkFeed data) {
        if (data.items.isEmpty) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: Space.bottomSafe),
            child: Column(
              children: <Widget>[
                header,
                if (folders.isEmpty)
                  EmptyState(
                    title: folderId == null
                        ? 'No folders yet'
                        : 'Nothing in here yet',
                    message: folderId == null
                        ? 'Make a folder above, and file links into it as you '
                              'save them.'
                        : 'Links you save into this folder will show up here.',
                    showMark: false,
                  ),
              ],
            ),
          );
        }
        return LinkList(
          feed: data,
          mode: settings.viewMode,
          showLocation: false,
          paths: ref.watch(folderPathsProvider),
          header: Column(
            children: <Widget>[
              header,
              SectionHeader(label: 'Links · ${grouped(data.items.length)}'),
            ],
          ),
          onLoadMore: () => ref
              .read(linkFeedProvider(folderScope(folderId)).notifier)
              .loadMore(),
        );
      }(loaded);
  }
}

class _FolderLayout extends ConsumerWidget {
  const _FolderLayout({required this.folders, required this.settings});

  final List<FolderSummary> folders;
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open(FolderSummary f) => context.push(Routes.folder(f.folder.id));
    void actions(FolderSummary f) =>
        showFolderActions(context, ref, f.folder);

    if (settings.folderView == FolderViewMode.grid) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: Space.sm,
          crossAxisSpacing: Space.sm,
          childAspectRatio: 1.55,
        ),
        itemCount: folders.length,
        itemBuilder: (BuildContext context, int i) => FolderCard(
          summary: folders[i],
          onTap: () => open(folders[i]),
          onLongPress: () => actions(folders[i]),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < folders.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: Space.sm),
          FolderRow(
            summary: folders[i],
            onTap: () => open(folders[i]),
            onLongPress: () => actions(folders[i]),
          ),
        ],
      ],
    );
  }
}

class _FolderSortControl extends ConsumerWidget {
  const _FolderSortControl({required this.sort});

  final FolderSort sort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    return InkWell(
      onTap: () async {
        final FolderSort? picked = await showOptionSheet<FolderSort>(
          context: context,
          title: 'Sort folders',
          icon: Icons.swap_vert_rounded,
          selected: sort,
          options: <SheetOption<FolderSort>>[
            for (final FolderSort option in FolderSort.values)
              SheetOption<FolderSort>(value: option, label: option.label),
          ],
        );
        if (picked != null) {
          await ref.read(settingsProvider.notifier).setFolderSort(picked);
        }
      },
      borderRadius: Radii.chipR,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.sm,
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
    );
  }
}
