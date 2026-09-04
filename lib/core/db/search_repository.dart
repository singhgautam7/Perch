import 'package:drift/drift.dart';

import 'database.dart';
import 'link_repository.dart';

/// How multiple selected tags combine.
enum TagMatch { any, all }

/// Board 3e — the Any / Yes / No segments.
enum Tri {
  any,
  yes,
  no;

  String get label => switch (this) {
    Tri.any => 'Any',
    Tri.yes => 'Yes',
    Tri.no => 'No',
  };
}

enum DatePreset {
  anyTime,
  today,
  thisWeek,
  thisMonth,
  custom;

  String get label => switch (this) {
    DatePreset.anyTime => 'Any time',
    DatePreset.today => 'Today',
    DatePreset.thisWeek => 'This week',
    DatePreset.thisMonth => 'This month',
    DatePreset.custom => 'Custom range',
  };
}

/// Everything the filter sheet can set. Immutable so the active-chip row can be
/// derived from it directly.
class SearchFilters {
  const SearchFilters({
    this.folderId,
    this.includeSubfolders = true,
    this.tagIds = const <int>{},
    this.tagMatch = TagMatch.any,
    this.hasNote = Tri.any,
    this.hasPreview = Tri.any,
    this.domains = const <String>{},
    this.datePreset = DatePreset.anyTime,
    this.from,
    this.to,
    this.sort = LinkSort.newest,
    this.unsorted = false,
    this.untagged = false,
    this.unopened = false,
    this.favorites = false,
  });

  final int? folderId;
  final bool includeSubfolders;
  final Set<int> tagIds;
  final TagMatch tagMatch;
  final Tri hasNote;
  final Tri hasPreview;
  final Set<String> domains;
  final DatePreset datePreset;
  final DateTime? from;
  final DateTime? to;
  final LinkSort sort;

  // B5 — the five quick chips. They set the same state the sheet does.
  final bool unsorted;
  final bool untagged;
  final bool unopened;
  final bool favorites;

  bool get isEmpty =>
      folderId == null &&
      tagIds.isEmpty &&
      hasNote == Tri.any &&
      hasPreview == Tri.any &&
      domains.isEmpty &&
      datePreset == DatePreset.anyTime &&
      !unsorted &&
      !untagged &&
      !unopened &&
      !favorites;

  /// How many groups are narrowing the result — the count on the Filter pill.
  int get activeCount {
    int n = 0;
    if (folderId != null) n++;
    if (tagIds.isNotEmpty) n++;
    if (hasNote != Tri.any) n++;
    if (hasPreview != Tri.any) n++;
    if (domains.isNotEmpty) n++;
    if (datePreset != DatePreset.anyTime) n++;
    if (unsorted) n++;
    if (untagged) n++;
    if (unopened) n++;
    if (favorites) n++;
    return n;
  }

  SearchFilters copyWith({
    int? folderId,
    bool clearFolder = false,
    bool? includeSubfolders,
    Set<int>? tagIds,
    TagMatch? tagMatch,
    Tri? hasNote,
    Tri? hasPreview,
    Set<String>? domains,
    DatePreset? datePreset,
    DateTime? from,
    DateTime? to,
    bool clearRange = false,
    LinkSort? sort,
    bool? unsorted,
    bool? untagged,
    bool? unopened,
    bool? favorites,
  }) {
    return SearchFilters(
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      includeSubfolders: includeSubfolders ?? this.includeSubfolders,
      tagIds: tagIds ?? this.tagIds,
      tagMatch: tagMatch ?? this.tagMatch,
      hasNote: hasNote ?? this.hasNote,
      hasPreview: hasPreview ?? this.hasPreview,
      domains: domains ?? this.domains,
      datePreset: datePreset ?? this.datePreset,
      from: clearRange ? null : (from ?? this.from),
      to: clearRange ? null : (to ?? this.to),
      sort: sort ?? this.sort,
      unsorted: unsorted ?? this.unsorted,
      untagged: untagged ?? this.untagged,
      unopened: unopened ?? this.unopened,
      favorites: favorites ?? this.favorites,
    );
  }
}

/// Search runs as one SQL statement: FTS5 for the text, plain predicates for the
/// filters, LIMIT/OFFSET for the paging. Never loads the whole table.
class SearchRepository {
  SearchRepository(this._db, this._links);

  final PerchDatabase _db;
  final LinkRepository _links;

  Future<List<LinkWithTags>> search({
    String query = '',
    SearchFilters filters = const SearchFilters(),
    int limit = 30,
    int offset = 0,
    List<int>? folderScope,
  }) async {
    final _Predicate p = _predicate(query, filters, folderScope);
    final String sql =
        'SELECT l.* FROM ${p.from}${p.whereSql}'
        ' ORDER BY ${_orderSql(filters.sort)} LIMIT ? OFFSET ?';

    final List<QueryRow> rows = await _db
        .customSelect(
          sql,
          variables: <Variable<Object>>[
            ...p.variables,
            Variable<int>(limit),
            Variable<int>(offset),
          ],
          readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{
            _db.links,
            _db.linkTags,
          },
        )
        .get();

    return _links.withTags(
      rows.map((QueryRow r) => _db.links.map(r.data)).toList(growable: false),
    );
  }

  /// How many links match — the live number on the filter sheet's Apply button.
  /// Counts in SQL rather than paging rows in to be counted.
  Future<int> count({
    String query = '',
    SearchFilters filters = const SearchFilters(),
    List<int>? folderScope,
  }) async {
    final _Predicate p = _predicate(query, filters, folderScope);
    final QueryRow row = await _db
        .customSelect(
          'SELECT COUNT(*) AS c FROM ${p.from}${p.whereSql}',
          variables: p.variables,
          readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{
            _db.links,
            _db.linkTags,
          },
        )
        .getSingle();
    return row.read<int>('c');
  }

  /// The FROM and WHERE that both the page query and the count query share.
  _Predicate _predicate(
    String query,
    SearchFilters filters,
    List<int>? folderScope,
  ) {
    final List<String> where = <String>[];
    final List<Variable<Object>> vars = <Variable<Object>>[];
    final bool hasQuery = query.trim().isNotEmpty;
    final String from = hasQuery
        ? 'links l JOIN links_fts f ON f.rowid = l.id'
        : 'links l';

    if (hasQuery) {
      where.add('links_fts MATCH ?');
      vars.add(Variable<String>(_toMatchQuery(query)));
    }

    if (filters.folderId != null) {
      final List<int> ids = folderScope ?? <int>[filters.folderId!];
      where.add(
        'l.folder_id IN (${List<String>.filled(ids.length, '?').join(',')})',
      );
      vars.addAll(ids.map((int id) => Variable<int>(id)));
    }
    switch (filters.hasNote) {
      case Tri.any:
        break;
      case Tri.yes:
        where.add("trim(l.note) != ''");
      case Tri.no:
        where.add("trim(l.note) = ''");
    }
    switch (filters.hasPreview) {
      case Tri.any:
        break;
      case Tri.yes:
        where.add('l.image_url IS NOT NULL');
      case Tri.no:
        where.add('l.image_url IS NULL');
    }
    if (filters.domains.isNotEmpty) {
      where.add(
        '(${List<String>.filled(filters.domains.length, 'l.url LIKE ?').join(' OR ')})',
      );
      vars.addAll(
        filters.domains.map((String d) => Variable<String>('%$d%')),
      );
    }

    // B5 — the quick chips, as plain predicates.
    if (filters.unsorted) where.add('l.folder_id IS NULL');
    if (filters.untagged) {
      where.add('l.id NOT IN (SELECT link_id FROM link_tags)');
    }
    if (filters.unopened) where.add('l.opened_at IS NULL');
    if (filters.favorites) where.add('l.is_favorite = 1');

    final (DateTime?, DateTime?) range = _range(filters);
    if (range.$1 != null) {
      where.add('l.created_at >= ?');
      vars.add(Variable<DateTime>(range.$1!));
    }
    if (range.$2 != null) {
      where.add('l.created_at <= ?');
      vars.add(Variable<DateTime>(range.$2!));
    }

    if (filters.tagIds.isNotEmpty) {
      final String placeholders =
          List<String>.filled(filters.tagIds.length, '?').join(',');
      where.add(
        filters.tagMatch == TagMatch.all
            ? 'l.id IN (SELECT link_id FROM link_tags WHERE tag_id IN '
                  '($placeholders) GROUP BY link_id '
                  'HAVING COUNT(DISTINCT tag_id) = ${filters.tagIds.length})'
            : 'l.id IN (SELECT link_id FROM link_tags WHERE tag_id IN '
                  '($placeholders))',
      );
      vars.addAll(filters.tagIds.map((int id) => Variable<int>(id)));
    }

    return _Predicate(
      from: from,
      whereSql: where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}',
      variables: vars,
    );
  }

  static String _orderSql(LinkSort sort) => switch (sort) {
    LinkSort.newest => 'l.created_at DESC',
    LinkSort.oldest => 'l.created_at ASC',
    LinkSort.titleAsc => 'lower(l.title) ASC',
    LinkSort.domain => 'lower(l.url) ASC',
    LinkSort.recentlyOpened => 'l.opened_at DESC',
    LinkSort.mostOpened => 'l.open_count DESC',
  };

  static (DateTime?, DateTime?) _range(SearchFilters f) {
    final DateTime now = DateTime.now();
    final DateTime midnight = DateTime(now.year, now.month, now.day);
    return switch (f.datePreset) {
      DatePreset.anyTime => (null, null),
      DatePreset.today => (midnight, null),
      // The week and month so far, not a rolling window — "this week" is a
      // calendar claim.
      DatePreset.thisWeek => (
        midnight.subtract(Duration(days: now.weekday - 1)),
        null,
      ),
      DatePreset.thisMonth => (DateTime(now.year, now.month), null),
      DatePreset.custom => (f.from, f.to),
    };
  }

  /// Turns typed text into an FTS5 prefix query, dropping the operators a user
  /// would only hit by accident.
  static String _toMatchQuery(String raw) {
    final Iterable<String> terms = raw
        .replaceAll(RegExp(r'["*():^-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((String t) => t.isNotEmpty)
        .map((String t) => '"$t"*');
    return terms.join(' AND ');
  }

  /// Distinct hosts across saved links, most-used first — the domain filter list.
  Future<List<String>> domains({int limit = 40}) async {
    final List<Link> links = await _db.select(_db.links).get();
    final Map<String, int> counts = <String, int>{};
    for (final Link l in links) {
      final String? host = Uri.tryParse(l.url)?.host;
      if (host == null || host.isEmpty) continue;
      counts[host] = (counts[host] ?? 0) + 1;
    }
    final List<String> sorted = counts.keys.toList()
      ..sort((String a, String b) => counts[b]!.compareTo(counts[a]!));
    return sorted.take(limit).toList(growable: false);
  }
}

class _Predicate {
  const _Predicate({
    required this.from,
    required this.whereSql,
    required this.variables,
  });

  final String from;

  /// Already carries its leading ` WHERE `, or is empty.
  final String whereSql;
  final List<Variable<Object>> variables;
}
