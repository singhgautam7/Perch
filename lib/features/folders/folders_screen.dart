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
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/breadcrumb.dart';
import '../../shared/widgets/folder_card.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/view_mode_button.dart';
import '../links/link_feed.dart';
import '../links/link_list.dart';
import 'folder_actions.dart';
import 'folder_providers.dart';
import 'new_folder_row.dart';

/// Board 2c — the structural surface.
///
/// Root shows the create row and the folder list; links at root are rare and
/// live on the Links tab. Inside a folder: breadcrumb, subfolders, then that
/// folder's links, with the view-mode switcher applying to the links only.
class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({this.folderId, super.key});

  final int? folderId;

  bool get _isRoot => folderId == null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FolderSummary>> children = ref.watch(
      folderChildrenProvider(folderId),
    );
    final LinkViewMode mode = ref.watch(
      settingsProvider.select((AppSettings s) => s.viewMode),
    );

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          _TopBar(folderId: folderId, mode: mode),
          if (!_isRoot) _CrumbBar(folderId: folderId),
          Expanded(
            child: children.when(
              loading: () => const SizedBox.shrink(),
              error: (Object e, StackTrace _) => ErrorStateView(message: '$e'),
              data: (List<FolderSummary> folders) => _Body(
                folderId: folderId,
                folders: folders,
                mode: mode,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.folderId, required this.mode});

  final int? folderId;
  final LinkViewMode mode;

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
          if (folderId != null)
            ViewModeButton(
              mode: mode,
              onChanged: (LinkViewMode m) =>
                  ref.read(settingsProvider.notifier).setViewMode(m),
            ),
          AppIconButton(
            icon: Icons.search_rounded,
            onPressed: () => context.push(Routes.search),
            semanticLabel: 'Search links',
            size: 40,
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.md),
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
    required this.mode,
  });

  final int? folderId;
  final List<FolderSummary> folders;
  final LinkViewMode mode;

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

    final Widget header = Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          NewFolderRow(
            locationName: locationName,
            onCreate: (String name) => ref
                .read(folderRepositoryProvider)
                .create(name: name, parentId: folderId),
          ),
          if (folders.isNotEmpty) const SizedBox(height: 14),
          for (int i = 0; i < folders.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: Space.sm),
            FolderRow(
              summary: folders[i],
              onTap: () => context.push(Routes.folder(folders[i].folder.id)),
              onLongPress: () =>
                  showFolderActions(context, ref, folders[i].folder),
            ),
          ],
          if (folderId == null) ...<Widget>[
            const SizedBox(height: Space.sm),
            const _UnsortedRow(),
          ],
        ],
      ),
    );

    // Root has no link list — its links belong to the Links tab.
    if (folderId == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Space.bottomSafe),
        child: Column(
          children: <Widget>[
            header,
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Space.screen),
              child: _RootHint(),
            ),
          ],
        ),
      );
    }

    final AsyncValue<LinkFeed> feed = ref.watch(
      linkFeedProvider(folderScope(folderId)),
    );
    return feed.when(
      loading: () => const ListSkeleton(rows: 3),
      error: (Object e, StackTrace _) => ErrorStateView(message: '$e'),
      data: (LinkFeed data) {
        if (data.items.isEmpty && folders.isEmpty) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: Space.bottomSafe),
            child: Column(
              children: <Widget>[
                header,
                const EmptyState(
                  title: 'Nothing in here yet',
                  message: 'Links you save into this folder will show up here.',
                  showMark: false,
                ),
              ],
            ),
          );
        }
        return LinkList(
          feed: data,
          mode: mode,
          paths: ref.watch(folderPathsProvider),
          header: header,
          onLoadMore: () => ref
              .read(linkFeedProvider(folderScope(folderId)).notifier)
              .loadMore(),
        );
      },
    );
  }
}

/// Root's link bucket. Tapping it goes to the Links tab, filtered to unsorted.
class _UnsortedRow extends ConsumerWidget {
  const _UnsortedRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final int count =
        ref.watch(linkFeedProvider(folderScope(null))).valueOrNull?.items.length ??
        0;
    if (count == 0) return const SizedBox.shrink();

    return Material(
      color: c.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(Routes.links),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.outline),
          ),
          child: Row(
            spacing: 13,
            children: <Widget>[
              FolderGlyph(color: c.onSurfaceMuted, width: 26),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Unsorted',
                      style: PerchType.titleMedium.copyWith(color: c.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plural(count, 'link'),
                      style: PerchType.monoLabel.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: c.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RootHint extends StatelessWidget {
  const _RootHint();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.lg),
    child: Text(
      'Long-press a folder to rename, move or delete it.',
      textAlign: TextAlign.center,
      style: PerchType.bodySmall.copyWith(color: context.colors.onSurfaceMuted),
    ),
  );
}
