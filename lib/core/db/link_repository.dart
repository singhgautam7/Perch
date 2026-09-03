import 'package:drift/drift.dart';

import 'database.dart';
import 'tables.dart';

/// A link with the tags a card needs to draw. Fetched in one pass so a list of
/// 50 links is two queries, not 51.
class LinkWithTags {
  const LinkWithTags(this.link, this.tags);

  final Link link;
  final List<Tag> tags;
}

/// How the Links tab and search order results.
enum LinkSort {
  newest,
  oldest,
  titleAsc,
  recentlyOpened;

  String get label => switch (this) {
    LinkSort.newest => 'Newest first',
    LinkSort.oldest => 'Oldest first',
    LinkSort.titleAsc => 'Title A–Z',
    LinkSort.recentlyOpened => 'Recently opened',
  };
}

class LinkRepository {
  LinkRepository(this._db);

  final PerchDatabase _db;

  /// One page of links. [folderId] filters to a folder; pass
  /// [unsortedOnly] to get the links that sit at the root.
  Future<List<LinkWithTags>> page({
    int limit = 40,
    int offset = 0,
    int? folderId,
    bool unsortedOnly = false,
    LinkSort sort = LinkSort.newest,
  }) async {
    final SimpleSelectStatement<$LinksTable, Link> q = _db.select(_db.links);
    if (unsortedOnly) {
      q.where(($LinksTable t) => t.folderId.isNull());
    } else if (folderId != null) {
      q.where(($LinksTable t) => t.folderId.equals(folderId));
    }
    q.orderBy(<OrderingTerm Function($LinksTable)>[_ordering(sort)]);
    q.limit(limit, offset: offset);
    return withTags(await q.get());
  }

  OrderingTerm Function($LinksTable) _ordering(LinkSort sort) {
    return switch (sort) {
      LinkSort.newest => ($LinksTable t) =>
        OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      LinkSort.oldest => ($LinksTable t) =>
        OrderingTerm(expression: t.createdAt),
      LinkSort.titleAsc => ($LinksTable t) =>
        OrderingTerm(expression: t.title.lower()),
      LinkSort.recentlyOpened => ($LinksTable t) =>
        OrderingTerm(expression: t.openedAt, mode: OrderingMode.desc),
    };
  }

  /// Attaches tags to an already-fetched page of links in a single query.
  Future<List<LinkWithTags>> withTags(List<Link> links) async {
    if (links.isEmpty) return const <LinkWithTags>[];
    final List<int> ids = links.map((Link l) => l.id).toList(growable: false);

    final List<TypedResult> rows =
        await (_db.select(_db.linkTags).join(<Join<HasResultSet, dynamic>>[
              innerJoin(_db.tags, _db.tags.id.equalsExp(_db.linkTags.tagId)),
            ])..where(_db.linkTags.linkId.isIn(ids)))
            .get();

    final Map<int, List<Tag>> byLink = <int, List<Tag>>{};
    for (final TypedResult row in rows) {
      byLink
          .putIfAbsent(row.readTable(_db.linkTags).linkId, () => <Tag>[])
          .add(row.readTable(_db.tags));
    }
    return links
        .map((Link l) => LinkWithTags(l, byLink[l.id] ?? const <Tag>[]))
        .toList(growable: false);
  }

  /// Emits whenever anything a link list depends on changes. The list itself is
  /// paginated — this is the invalidation signal, not the data.
  Stream<void> watchChanges() =>
      _db.select(_db.links).watch().map((List<Link> _) {});

  Future<Link?> byId(int id) =>
      (_db.select(_db.links)..where(($LinksTable t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<Link?> byUrl(String url) =>
      (_db.select(_db.links)..where(($LinksTable t) => t.url.equals(url)))
          .getSingleOrNull();

  Future<int> count({int? folderId}) async {
    final Expression<int> c = _db.links.id.count();
    final JoinedSelectStatement<HasResultSet, dynamic> q = _db.selectOnly(
      _db.links,
    )..addColumns(<Expression<Object>>[c]);
    if (folderId != null) q.where(_db.links.folderId.equals(folderId));
    return (await q.getSingle()).read(c) ?? 0;
  }

  Future<int> create({
    required String url,
    String title = '',
    String note = '',
    int? folderId,
    FetchStatus fetchStatus = FetchStatus.pending,
  }) {
    final DateTime now = DateTime.now();
    return _db
        .into(_db.links)
        .insert(
          LinksCompanion.insert(
            url: url,
            title: Value<String>(title),
            note: Value<String>(note),
            folderId: Value<int?>(folderId),
            createdAt: now,
            updatedAt: now,
            fetchStatus: Value<FetchStatus>(fetchStatus),
          ),
        );
  }

  Future<void> update(int id, LinksCompanion changes) {
    return (_db.update(_db.links)..where(($LinksTable t) => t.id.equals(id)))
        .write(
          changes.copyWith(updatedAt: Value<DateTime>(DateTime.now())),
        );
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.links)..where(($LinksTable t) => t.id.equals(id))).go();

  /// Records an open so "Recently opened" can sort on it.
  Future<void> markOpened(int id) {
    return _db.customStatement(
      'UPDATE links SET opened_at = ?, open_count = open_count + 1 WHERE id = ?',
      <Object>[DateTime.now().millisecondsSinceEpoch ~/ 1000, id],
    );
  }

  Future<void> moveToFolder(int id, int? folderId) =>
      update(id, LinksCompanion(folderId: Value<int?>(folderId)));
}
