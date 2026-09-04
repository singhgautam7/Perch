import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/folder_repository.dart';
import '../../core/db/settings_repository.dart';
import '../../core/providers.dart';
import '../../shared/widgets/breadcrumb.dart';

/// Children of a location, with their counts, in the chosen order.
final StreamProviderFamily<List<FolderSummary>, int?> folderChildrenProvider =
    StreamProvider.family<List<FolderSummary>, int?>((Ref ref, int? parentId) {
      final FolderSort sort = ref.watch(
        settingsProvider.select((AppSettings s) => s.folderSort),
      );
      return ref
          .watch(folderRepositoryProvider)
          .watchChildren(parentId, sort: sort);
    });

/// How many folders exist in total — the count in the Folders header.
final StreamProvider<int> folderCountProvider = StreamProvider<int>((Ref ref) {
  final PerchDatabase db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT COUNT(*) AS c FROM folders',
        readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{db.folders},
      )
      .watch()
      .map((List<QueryRow> rows) => rows.first.read<int>('c'));
});

/// How many links sit directly at a location — the count in the header line.
final StreamProviderFamily<int, int?> folderLinkCountProvider =
    StreamProvider.family<int, int?>((Ref ref, int? folderId) {
      final PerchDatabase db = ref.watch(databaseProvider);
      return db
          .customSelect(
            folderId == null
                ? 'SELECT COUNT(*) AS c FROM links WHERE folder_id IS NULL'
                : 'SELECT COUNT(*) AS c FROM links WHERE folder_id = ?1',
            variables: folderId == null
                ? const <Variable<Object>>[]
                : <Variable<Object>>[Variable<int>(folderId)],
            readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{
              db.links,
            },
          )
          .watch()
          .map((List<QueryRow> rows) => rows.first.read<int>('c'));
    });

/// Every folder, flat. Folders are few, so one watch feeds the picker, the
/// path map and the stats screen.
final StreamProvider<List<Folder>> allFoldersProvider =
    StreamProvider<List<Folder>>((Ref ref) {
      return ref.watch(folderRepositoryProvider).watchAll();
    });

/// `id → "Reading › AI papers"`, built once per folder change so a list of 50
/// link cards does not run 50 breadcrumb walks.
final Provider<Map<int, String>> folderPathsProvider = Provider<Map<int, String>>(
  (Ref ref) {
    final List<Folder> folders =
        ref.watch(allFoldersProvider).valueOrNull ?? const <Folder>[];
    final Map<int, Folder> byId = <int, Folder>{
      for (final Folder f in folders) f.id: f,
    };

    final Map<int, String> paths = <int, String>{};
    String pathOf(int id, Set<int> seen) {
      final String? done = paths[id];
      if (done != null) return done;
      final Folder? f = byId[id];
      if (f == null || !seen.add(id)) return '';
      final String parent = f.parentId == null ? '' : pathOf(f.parentId!, seen);
      final String path = parent.isEmpty ? f.name : '$parent › ${f.name}';
      paths[id] = path;
      return path;
    }

    for (final Folder f in folders) {
      pathOf(f.id, <int>{});
    }
    return paths;
  },
);

/// The crumb trail for a location, root included.
final FutureProviderFamily<List<Crumb>, int?> breadcrumbProvider =
    FutureProvider.family<List<Crumb>, int?>((Ref ref, int? folderId) async {
      ref.watch(allFoldersProvider);
      final List<Folder> path = await ref
          .read(folderRepositoryProvider)
          .breadcrumb(folderId);
      return <Crumb>[
        const Crumb('Root', null),
        ...path.map((Folder f) => Crumb(f.name, f.id)),
      ];
    });
