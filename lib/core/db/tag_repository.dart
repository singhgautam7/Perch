import 'package:drift/drift.dart';

import 'database.dart';

class TagWithCount {
  const TagWithCount(this.tag, this.linkCount);

  final Tag tag;
  final int linkCount;
}

class TagRepository {
  TagRepository(this._db);

  final PerchDatabase _db;

  Stream<List<TagWithCount>> watchAll() {
    final Expression<int> count = _db.linkTags.linkId.count();
    final JoinedSelectStatement<HasResultSet, dynamic> q =
        _db.select(_db.tags).join(<Join<HasResultSet, dynamic>>[
          leftOuterJoin(
            _db.linkTags,
            _db.linkTags.tagId.equalsExp(_db.tags.id),
            useColumns: false,
          ),
        ])
          ..addColumns(<Expression<Object>>[count])
          ..groupBy(<Expression<Object>>[_db.tags.id])
          ..orderBy(<OrderingTerm>[
            OrderingTerm(expression: count, mode: OrderingMode.desc),
            OrderingTerm(expression: _db.tags.name),
          ]);

    return q.watch().map(
      (List<TypedResult> rows) => rows
          .map(
            (TypedResult r) =>
                TagWithCount(r.readTable(_db.tags), r.read(count) ?? 0),
          )
          .toList(growable: false),
    );
  }

  Future<List<Tag>> forLink(int linkId) async {
    final List<TypedResult> rows =
        await (_db.select(_db.tags).join(<Join<HasResultSet, dynamic>>[
              innerJoin(
                _db.linkTags,
                _db.linkTags.tagId.equalsExp(_db.tags.id),
              ),
            ])..where(_db.linkTags.linkId.equals(linkId)))
            .get();
    return rows
        .map((TypedResult r) => r.readTable(_db.tags))
        .toList(growable: false);
  }

  /// Finds a tag by name or creates it. Names are matched case-insensitively so
  /// "Reading" and "reading" never become two tags.
  Future<int> ensure(String name) async {
    final String trimmed = name.trim();
    final Tag? existing =
        await (_db.select(_db.tags)
              ..where(($TagsTable t) => t.name.lower().equals(trimmed.toLowerCase()))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) return existing.id;
    return _db
        .into(_db.tags)
        .insert(
          TagsCompanion.insert(name: trimmed, createdAt: DateTime.now()),
        );
  }

  /// Replaces a link's tags with exactly [names].
  Future<void> setForLink(int linkId, List<String> names) async {
    await _db.transaction(() async {
      final List<int> ids = <int>[];
      for (final String n in names) {
        if (n.trim().isEmpty) continue;
        ids.add(await ensure(n));
      }
      await (_db.delete(_db.linkTags)
            ..where(($LinkTagsTable t) => t.linkId.equals(linkId)))
          .go();
      await _db.batch((Batch b) {
        b.insertAll(
          _db.linkTags,
          ids
              .toSet()
              .map(
                (int id) =>
                    LinkTagsCompanion.insert(linkId: linkId, tagId: id),
              )
              .toList(growable: false),
          mode: InsertMode.insertOrIgnore,
        );
      });
    });
  }

  Future<void> rename(int id, String name) =>
      (_db.update(_db.tags)..where(($TagsTable t) => t.id.equals(id)))
          .write(TagsCompanion(name: Value<String>(name.trim())));

  Future<void> setColor(int id, int? color) =>
      (_db.update(_db.tags)..where(($TagsTable t) => t.id.equals(id)))
          .write(TagsCompanion(color: Value<int?>(color)));

  Future<void> delete(int id) =>
      (_db.delete(_db.tags)..where(($TagsTable t) => t.id.equals(id))).go();

  /// Removes every tag that no link references any more.
  Future<int> deleteUnused() => _db.customUpdate(
    'DELETE FROM tags WHERE id NOT IN (SELECT tag_id FROM link_tags)',
    updates: <TableInfo<Table, dynamic>>{_db.tags},
  );
}
