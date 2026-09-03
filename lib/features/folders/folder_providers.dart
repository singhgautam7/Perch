import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/folder_repository.dart';
import '../../core/providers.dart';
import '../../shared/widgets/breadcrumb.dart';

/// Children of a location, with their counts.
final StreamProviderFamily<List<FolderSummary>, int?> folderChildrenProvider =
    StreamProvider.family<List<FolderSummary>, int?>((Ref ref, int? parentId) {
      return ref.watch(folderRepositoryProvider).watchChildren(parentId);
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
