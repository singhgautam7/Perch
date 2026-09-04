import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/folder_repository.dart';
import '../../core/db/link_repository.dart';
import '../../core/db/settings_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/folder_card.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/view_mode_button.dart';
import '../links/link_feed.dart';
import '../links/link_list.dart';
import '../links/link_selection.dart';
import '../links/links_screen.dart';
import '../links/selection_bar.dart';
import 'folder_actions.dart';
import 'folder_providers.dart';
import 'new_folder_row.dart';

/// Boards 2c, 3a and 3f — the structural surface, in exactly the language of
/// Links: the same header, the same cards, the same 8dp rhythm. New folder
/// first, then subfolders, then the links here.
class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({this.folderId, super.key});

  final int? folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final AsyncValue<List<FolderSummary>> children = ref.watch(
      folderChildrenProvider(folderId),
    );
    final AppSettings settings = ref.watch(settingsProvider);
    final LinkSelection selection = ref.watch(linkSelectionProvider);
    final Folder? folder = folderId == null
        ? null
        : ref
              .watch(allFoldersProvider)
              .valueOrNull
              ?.where((Folder f) => f.id == folderId)
              .firstOrNull;
    // Nesting inherits the nearest coloured ancestor (board 3f).
    final FolderTint tint = c.folderTint(
      folder == null ? null : _inheritedColor(ref, folder),
    );
    final bool tinted = folder != null && _inheritedColor(ref, folder) != null;
    final AsyncValue<LinkFeed> feed = ref.watch(
      linkFeedProvider(folderScope(folderId)),
    );

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
                    title: folder?.name ?? 'Folders',
                    foreground: tinted ? tint.onContainer : null,
                    background: tinted ? tint.headerTint : null,
                    onBack: folderId == null
                        ? null
                        // A breadcrumb jump resets the branch stack, so back has
                        // to be able to fall through to the parent folder.
                        : () => context.canPop()
                              ? context.pop()
                              : context.go(
                                  folder?.parentId == null
                                      ? Routes.folders
                                      : Routes.folder(folder!.parentId!),
                                ),
                    actions: <Widget>[
                      AppIconButton(
                        icon: Icons.search_rounded,
                        onPressed: () => context.push(Routes.search),
                        semanticLabel: 'Search links',
                        tint: tinted ? tint.onContainer : null,
                      ),
                      ViewModeButton(
                        mode: settings.viewMode,
                        onChanged: (LinkViewMode m) =>
                            ref.read(settingsProvider.notifier).setViewMode(m),
                      ),
                      if (folder == null)
                        ListOverflowButton(sort: settings.sort)
                      else
                        _FolderOverflowButton(folder: folder),
                    ],
                  ),
                _LocationLine(folderId: folderId, tint: tinted ? tint : null),
                Expanded(
                  child: switch (children) {
                    AsyncValue<List<FolderSummary>>(
                      :final List<FolderSummary> value?,
                    ) =>
                      _Body(
                        folderId: folderId,
                        folders: value,
                        settings: settings,
                        tint: tint,
                        selection: selection,
                      ),
                    AsyncValue<List<FolderSummary>>(:final Object error?) =>
                      ErrorStateView(message: '$error'),
                    _ => const SizedBox.shrink(),
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

  /// This folder's colour, or the nearest coloured ancestor's.
  static int? _inheritedColor(WidgetRef ref, Folder folder) {
    final List<Folder> all =
        ref.watch(allFoldersProvider).valueOrNull ?? const <Folder>[];
    final Map<int, Folder> byId = <int, Folder>{
      for (final Folder f in all) f.id: f,
    };
    Folder? cursor = folder;
    final Set<int> seen = <int>{};
    while (cursor != null && seen.add(cursor.id)) {
      if (cursor.color != null) return cursor.color;
      cursor = cursor.parentId == null ? null : byId[cursor.parentId!];
    }
    return null;
  }
}

/// `Home`, or `Home › Recipes · 19 links` inside a folder (board 3f).
class _LocationLine extends ConsumerWidget {
  const _LocationLine({required this.folderId, required this.tint});

  final int? folderId;
  final FolderTint? tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final Map<int, String> paths = ref.watch(folderPathsProvider);
    final int count =
        ref.watch(folderLinkCountProvider(folderId)).valueOrNull ?? 0;
    final String path = folderId == null
        ? 'Home'
        : 'Home › ${paths[folderId!] ?? ''} · ${plural(count, 'link')}';

    return ColoredBox(
      color: tint?.headerTint ?? Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.screen,
          0,
          Space.screen,
          Space.row,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: folderId == null ? null : () => context.go(Routes.folders),
            behavior: HitTestBehavior.opaque,
            child: Text(
              path,
              style: PerchType.monoLabel.copyWith(
                fontSize: 11.5,
                color: tint?.onContainer ?? c.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class _FolderOverflowButton extends ConsumerWidget {
  const _FolderOverflowButton({required this.folder});

  final Folder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Builder(
      builder: (BuildContext anchor) => AppIconButton(
        icon: Icons.more_vert_rounded,
        semanticLabel: 'Folder actions',
        onPressed: () =>
            showFolderMenu(context, ref, folder, anchorContext: anchor),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.folderId,
    required this.folders,
    required this.settings,
    required this.tint,
    required this.selection,
  });

  final int? folderId;
  final List<FolderSummary> folders;
  final AppSettings settings;
  final FolderTint tint;
  final LinkSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget header = Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          NewFolderRow(
            tint: tint,
            onCreate: (String name) => ref
                .read(folderRepositoryProvider)
                .create(name: name, parentId: folderId),
          ),
          for (final FolderSummary f in folders) ...<Widget>[
            const SizedBox(height: Space.sm),
            FolderRow(
              summary: f,
              onTap: () => context.push(Routes.folder(f.folder.id)),
              onLongPress: (Offset at) =>
                  showFolderMenu(context, ref, f.folder, at: at),
            ),
          ],
        ],
      ),
    );

    // The links at this location, drawn exactly as they are on the Links tab.
    // The root is no exception: loose links show here, like a file explorer.
    final AsyncValue<LinkFeed> feed = ref.watch(
      linkFeedProvider(folderScope(folderId)),
    );
    final List<LinkWithTags> pinned =
        ref.watch(pinnedLinksProvider(folderScope(folderId))).valueOrNull ??
        const <LinkWithTags>[];

    final LinkFeed? loaded = feed.valueOrNull;
    if (feed.hasError && loaded == null) {
      return ErrorStateView(message: '${feed.error}');
    }
    if (loaded == null) {
      return SingleChildScrollView(child: header);
    }

    if (loaded.items.isEmpty && pinned.isEmpty) {
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
      feed: loaded,
      mode: settings.viewMode,
      pinned: pinned,
      showLocation: false,
      countLabel: pinned.isEmpty
          ? 'Links here · ${grouped(loaded.items.length)}'
          : 'Everything else · ${grouped(loaded.items.length)}',
      countTrailing: SortControl(sort: settings.sort),
      paths: ref.watch(folderPathsProvider),
      header: header,
      selection: selection,
      onTapLink: (LinkWithTags item) =>
          onLinkTapped(context, ref, item, selection),
      onLongPressLink: (LinkWithTags item, Offset at) =>
          onLinkHeld(context, ref, item, at, selection),
      onLoadMore: () =>
          ref.read(linkFeedProvider(folderScope(folderId)).notifier).loadMore(),
    );
  }
}
