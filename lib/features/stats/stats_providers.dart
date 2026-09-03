import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';

@immutable
class PerchStats {
  const PerchStats({
    required this.links,
    required this.folders,
    required this.tags,
    required this.unsorted,
    required this.perWeek,
    required this.topDomains,
    required this.oldestUnopened,
  });

  final int links;
  final int folders;
  final int tags;
  final int unsorted;

  /// Twelve buckets, oldest first — the last twelve weeks.
  final List<int> perWeek;
  final List<({String domain, int count})> topDomains;
  final Link? oldestUnopened;

  int get thisWeek => perWeek.isEmpty ? 0 : perWeek.last;
}

/// Stats is a reading surface, not a dashboard: three counts, one chart, one
/// ranked list, two prompts that lead somewhere.
final FutureProvider<PerchStats> statsProvider = FutureProvider<PerchStats>((
  Ref ref,
) async {
  final PerchDatabase db = ref.watch(databaseProvider);
  // Recomputed whenever links change; folders and tags move with them.
  ref.watch(statsSignalProvider);

  Future<int> countOf(String sql) async {
    final QueryRow row = await db.customSelect(sql).getSingle();
    return row.read<int>('c');
  }

  final List<Link> links = await db.select(db.links).get();
  final DateTime now = DateTime.now();
  final DateTime weekStart = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));

  final List<int> perWeek = List<int>.filled(12, 0);
  final Map<String, int> domains = <String, int>{};
  for (final Link l in links) {
    final int weeksAgo = weekStart.difference(l.createdAt).inDays ~/ 7;
    // Anything saved this week lands in the last bucket.
    final int bucket = 11 - (weeksAgo < 0 ? 0 : weeksAgo);
    if (bucket >= 0) perWeek[bucket]++;

    final String host = Uri.tryParse(l.url)?.host ?? '';
    if (host.isNotEmpty) domains[host] = (domains[host] ?? 0) + 1;
  }

  final List<String> ranked = domains.keys.toList()
    ..sort((String a, String b) => domains[b]!.compareTo(domains[a]!));

  final List<Link> unopened =
      links.where((Link l) => l.openCount == 0).toList()
        ..sort((Link a, Link b) => a.createdAt.compareTo(b.createdAt));

  return PerchStats(
    links: links.length,
    folders: await countOf('SELECT COUNT(*) AS c FROM folders'),
    tags: await countOf('SELECT COUNT(*) AS c FROM tags'),
    unsorted: links.where((Link l) => l.folderId == null).length,
    perWeek: perWeek,
    topDomains: ranked
        .take(5)
        .map(
          (String d) => (domain: d, count: domains[d]!),
        )
        .toList(growable: false),
    oldestUnopened: unopened.firstOrNull,
  );
});

/// Fires on any change to the three tables the stats are drawn from.
final StreamProvider<int> statsSignalProvider = StreamProvider<int>((Ref ref) {
  final PerchDatabase db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT (SELECT COUNT(*) FROM links) AS l, '
        '(SELECT COUNT(*) FROM folders) AS f, '
        '(SELECT COUNT(*) FROM tags) AS t',
        readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{
          db.links,
          db.folders,
          db.tags,
        },
      )
      .watch()
      .map(
        (List<QueryRow> rows) => Object.hash(
          rows.first.read<int>('l'),
          rows.first.read<int>('f'),
          rows.first.read<int>('t'),
        ),
      );
});
