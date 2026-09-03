import 'package:drift/drift.dart';

import 'database.dart';
import 'link_repository.dart';

/// How multiple selected tags combine.
enum TagMatch { any, all }

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
    this.hasNote = false,
    this.hasImage = false,
    this.domain,
    this.datePreset = DatePreset.anyTime,
    this.from,
    this.to,
    this.sort = LinkSort.newest,
  });

  final int? folderId;
  final bool includeSubfolders;
  final Set<int> tagIds;
  final TagMatch tagMatch;
  final bool hasNote;
  final bool hasImage;
  final String? domain;
  final DatePreset datePreset;
  final DateTime? from;
  final DateTime? to;
  final LinkSort sort;

  bool get isEmpty =>
      folderId == null &&
      tagIds.isEmpty &&
      !hasNote &&
      !hasImage &&
      domain == null &&
      datePreset == DatePreset.anyTime;

  SearchFilters copyWith({
    int? folderId,
    bool clearFolder = false,
    bool? includeSubfolders,
    Set<int>? tagIds,
    TagMatch? tagMatch,
    bool? hasNote,
    bool? hasImage,
    String? domain,
    bool clearDomain = false,
    DatePreset? datePreset,
    DateTime? from,
    DateTime? to,
    LinkSort? sort,
  }) {
    return SearchFilters(
      folderId: clearFolder ? null : (folderId ?? this.folderId),
      includeSubfolders: includeSubfolders ?? this.includeSubfolders,
      tagIds: tagIds ?? this.tagIds,
      tagMatch: tagMatch ?? this.tagMatch,
      hasNote: hasNote ?? this.hasNote,
      hasImage: hasImage ?? this.hasImage,
      domain: clearDomain ? null : (domain ?? this.domain),
      datePreset: datePreset ?? this.datePreset,
      from: from ?? this.from,
      to: to ?? this.to,
      sort: sort ?? this.sort,
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
    if (filters.hasNote) where.add("trim(l.note) != ''");
    if (filters.hasImage) where.add('l.image_url IS NOT NULL');
    if (filters.domain != null) {
      where.add('l.url LIKE ?');
      vars.add(Variable<String>('%${filters.domain}%'));
    }

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
    LinkSort.recentlyOpened => 'l.opened_at DESC',
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
