import 'package:drift/drift.dart';

import 'database.dart';

/// A folder plus the two counts its card shows.
class FolderSummary {
  const FolderSummary({
    required this.folder,
    required this.subfolderCount,
    required this.linkCount,
  });

  final Folder folder;
  final int subfolderCount;
  final int linkCount;
}

/// All folder reads and writes. Nesting is an adjacency list; anything that
/// needs the whole subtree uses a recursive CTE rather than N queries.
class FolderRepository {
  FolderRepository(this._db);

  final PerchDatabase _db;

  /// Children of [parentId], or the root folders when null.
  Stream<List<FolderSummary>> watchChildren(int? parentId) {
    final $FoldersTable f = _db.folders;
    final $FoldersTable sub = _db.alias(_db.folders, 'sub');
    final $LinksTable l = _db.alias(_db.links, 'l');

    final JoinedSelectStatement<HasResultSet, dynamic> q =
        _db.select<$FoldersTable, Folder>(f).join(<Join<HasResultSet, dynamic>>[
          leftOuterJoin(sub, sub.parentId.equalsExp(f.id), useColumns: false),
          leftOuterJoin(l, l.folderId.equalsExp(f.id), useColumns: false),
        ]);
    q.where(
      parentId == null ? f.parentId.isNull() : f.parentId.equals(parentId),
    );
    q.groupBy(<Expression<Object>>[f.id]);
    q.orderBy(<OrderingTerm>[
      OrderingTerm(expression: f.sortIndex),
      OrderingTerm(expression: f.name),
    ]);

    final Expression<int> subCount = sub.id.count(distinct: true);
    final Expression<int> linkCount = l.id.count(distinct: true);
    q.addColumns(<Expression<Object>>[subCount, linkCount]);

    return q.watch().map(
      (List<TypedResult> rows) => rows
          .map(
            (TypedResult r) => FolderSummary(
              folder: r.readTable(f),
              subfolderCount: r.read(subCount) ?? 0,
              linkCount: r.read(linkCount) ?? 0,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<Folder?> byId(int id) =>
      (_db.select(_db.folders)..where(($FoldersTable t) => t.id.equals(id)))
          .getSingleOrNull();

  /// Root → … → [folderId]. Empty for the root itself.
  Future<List<Folder>> breadcrumb(int? folderId) async {
    final List<Folder> path = <Folder>[];
    int? cursor = folderId;
    // Depth is bounded by the folder tree, and a cycle can only exist if the
    // DB was tampered with — the guard keeps it from hanging either way.
    final Set<int> seen = <int>{};
    while (cursor != null && seen.add(cursor)) {
      final Folder? f = await byId(cursor);
      if (f == null) break;
      path.insert(0, f);
      cursor = f.parentId;
    }
    return path;
  }

  /// [rootId] and every folder beneath it.
  Future<List<int>> descendantIds(int rootId) async {
    final List<QueryRow> rows = await _db
        .customSelect(
          '''
WITH RECURSIVE tree(id) AS (
  SELECT id FROM folders WHERE id = ?1
  UNION ALL
  SELECT f.id FROM folders f JOIN tree ON f.parent_id = tree.id
)
SELECT id FROM tree
''',
          variables: <Variable<Object>>[Variable<int>(rootId)],
          readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{
            _db.folders,
          },
        )
        .get();
    return rows.map((QueryRow r) => r.read<int>('id')).toList(growable: false);
  }

  /// Every folder, ordered so a parent always precedes its children — the shape
  /// the folder picker and the export tree both want.
  Stream<List<Folder>> watchAll() {
    return (_db.select(_db.folders)..orderBy(<OrderingTerm Function(
      $FoldersTable,
    )>[
      ($FoldersTable t) => OrderingTerm(expression: t.name),
    ])).watch();
  }

  Future<int> create({required String name, int? parentId}) {
    final DateTime now = DateTime.now();
    return _db
        .into(_db.folders)
        .insert(
          FoldersCompanion.insert(
            name: name.trim(),
            parentId: Value<int?>(parentId),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> rename(int id, String name) {
    return (_db.update(_db.folders)..where(($FoldersTable t) => t.id.equals(id)))
        .write(
          FoldersCompanion(
            name: Value<String>(name.trim()),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
  }

  /// Moves [id] under [newParentId]. Refuses to move a folder into its own
  /// subtree, which would orphan the branch.
  Future<bool> move(int id, int? newParentId) async {
    if (id == newParentId) return false;
    if (newParentId != null &&
        (await descendantIds(id)).contains(newParentId)) {
      return false;
    }
    await (_db.update(_db.folders)..where(($FoldersTable t) => t.id.equals(id)))
        .write(
          FoldersCompanion(
            parentId: Value<int?>(newParentId),
            updatedAt: Value<DateTime>(DateTime.now()),
          ),
        );
    return true;
  }

  /// Deletes the folder and its subtree. Links inside fall back to Unsorted
  /// rather than being deleted with it.
  Future<void> delete(int id) async {
    final List<int> ids = await descendantIds(id);
    await _db.transaction(() async {
      await (_db.update(_db.links)..where(($LinksTable t) => t.folderId.isIn(ids)))
          .write(const LinksCompanion(folderId: Value<int?>(null)));
      await (_db.delete(_db.folders)..where(($FoldersTable t) => t.id.isIn(ids)))
          .go();
    });
  }
}
