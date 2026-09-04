import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

/// One link read out of somebody else's export, before it becomes a row.
@immutable
class ImportedLink {
  const ImportedLink({
    required this.url,
    this.title = '',
    this.note = '',
    this.folderPath = const <String>[],
    this.tags = const <String>[],
    this.createdAt,
    this.isFavorite = false,
  });

  final String url;
  final String title;
  final String note;

  /// `['Reading', 'Essays']` — rebuilt as nested folders on import.
  final List<String> folderPath;
  final List<String> tags;
  final DateTime? createdAt;
  final bool isFavorite;
}

/// Where an import came from. Each one maps onto folders and tags where the
/// source has them (board 3g).
enum ImportSource {
  perch,
  bookmarks,
  pocket,
  raindrop;

  String get label => switch (this) {
    ImportSource.perch => 'Perch backup',
    ImportSource.bookmarks => 'Browser bookmarks',
    ImportSource.pocket => 'Pocket',
    ImportSource.raindrop => 'Raindrop',
  };

  String get blurb => switch (this) {
    ImportSource.perch => 'Restore from a Perch JSON file',
    ImportSource.bookmarks => 'Netscape HTML export',
    ImportSource.pocket => 'CSV or HTML export',
    ImportSource.raindrop => 'CSV export, folders preserved',
  };
}

/// Parses one of the three foreign formats. Runs off the UI isolate — a
/// bookmarks file is routinely tens of thousands of nodes.
Future<List<ImportedLink>> parseImport(
  ImportSource source,
  String raw,
) => compute(_parse, (source, raw));

List<ImportedLink> _parse((ImportSource, String) input) {
  final (ImportSource source, String raw) = input;
  return switch (source) {
    ImportSource.perch => const <ImportedLink>[],
    ImportSource.bookmarks => parseNetscapeBookmarks(raw),
    ImportSource.pocket => raw.trimLeft().toLowerCase().startsWith('<')
        ? parseNetscapeBookmarks(raw)
        : parsePocketCsv(raw),
    ImportSource.raindrop => parseRaindropCsv(raw),
  };
}

/// The Netscape bookmark format every browser still exports: `<DL>` nests,
/// `<H3>` names a folder, `<A>` is a bookmark.
///
/// The file is famously unbalanced — `<DT>` and `<p>` are rarely closed — so
/// the folder path is rebuilt from each anchor's ancestors rather than by
/// walking the document as a stack.
List<ImportedLink> parseNetscapeBookmarks(String source) {
  final dom.Document doc = html.parse(source);
  final List<ImportedLink> out = <ImportedLink>[];

  for (final dom.Element a in doc.querySelectorAll('a')) {
    final String? href = a.attributes['href'];
    if (href == null || !href.startsWith(RegExp('https?://'))) continue;

    final List<String> path = <String>[];
    for (dom.Element? node = a.parent; node != null; node = node.parent) {
      if (node.localName?.toLowerCase() != 'dl') continue;
      // The folder's name is the H3 in the DT that opens this DL.
      final dom.Element? h3 = _precedingHeading(node);
      if (h3 != null) path.insert(0, h3.text.trim());
    }

    final String? added = a.attributes['add_date'];
    out.add(
      ImportedLink(
        url: href,
        title: a.text.trim(),
        folderPath: path.where((String s) => s.isNotEmpty).toList(),
        tags: _splitTags(a.attributes['tags']),
        createdAt: added == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (int.tryParse(added) ?? 0) * 1000,
              ),
      ),
    );
  }
  return out;
}

/// The `<H3>` that titles a `<DL>` — it sits in an earlier sibling of the DL,
/// or in the DL's own parent `<DT>`.
dom.Element? _precedingHeading(dom.Element dl) {
  dom.Node? cursor = dl.previousElementSibling;
  while (cursor is dom.Element) {
    if (cursor.localName?.toLowerCase() == 'h3') return cursor;
    final dom.Element? nested = cursor.querySelector('h3');
    if (nested != null) return nested;
    cursor = cursor.previousElementSibling;
  }
  final dom.Element? parent = dl.parent;
  if (parent != null && parent.localName?.toLowerCase() == 'dt') {
    return parent.querySelector('h3');
  }
  return null;
}

/// Pocket's CSV: `title,url,time_added,tags,status`. Archived items keep their
/// status as a tag so nothing is silently dropped.
List<ImportedLink> parsePocketCsv(String source) {
  final List<List<String>> rows = parseCsv(source);
  if (rows.isEmpty) return const <ImportedLink>[];
  final Map<String, int> col = _header(rows.first);
  if (!col.containsKey('url')) return const <ImportedLink>[];

  final List<ImportedLink> out = <ImportedLink>[];
  for (final List<String> row in rows.skip(1)) {
    final String url = _cell(row, col['url']);
    if (url.isEmpty) continue;
    final int? seconds = int.tryParse(_cell(row, col['time_added']));
    final String status = _cell(row, col['status']);
    out.add(
      ImportedLink(
        url: url,
        title: _cell(row, col['title']),
        tags: <String>[
          ..._splitTags(_cell(row, col['tags'])),
          if (status == 'archive') 'archive',
        ],
        createdAt: seconds == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
      ),
    );
  }
  return out;
}

/// Raindrop's CSV: `id,title,note,excerpt,url,folder,tags,created,...`.
/// The folder column is a `/`-separated path, which maps straight onto nesting.
List<ImportedLink> parseRaindropCsv(String source) {
  final List<List<String>> rows = parseCsv(source);
  if (rows.isEmpty) return const <ImportedLink>[];
  final Map<String, int> col = _header(rows.first);
  if (!col.containsKey('url')) return const <ImportedLink>[];

  final List<ImportedLink> out = <ImportedLink>[];
  for (final List<String> row in rows.skip(1)) {
    final String url = _cell(row, col['url']);
    if (url.isEmpty) continue;
    final String folder = _cell(row, col['folder']);
    out.add(
      ImportedLink(
        url: url,
        title: _cell(row, col['title']),
        note: _cell(row, col['note']),
        folderPath: folder
            .split('/')
            .map((String s) => s.trim())
            .where((String s) => s.isNotEmpty && s != 'Unsorted')
            .toList(growable: false),
        tags: _splitTags(_cell(row, col['tags'])),
        createdAt: DateTime.tryParse(_cell(row, col['created'])),
        isFavorite: _cell(row, col['favorite']).toLowerCase() == 'true',
      ),
    );
  }
  return out;
}

Map<String, int> _header(List<String> row) => <String, int>{
  for (int i = 0; i < row.length; i++) row[i].trim().toLowerCase(): i,
};

String _cell(List<String> row, int? index) =>
    index == null || index >= row.length ? '' : row[index].trim();

List<String> _splitTags(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const <String>[];
  return raw
      .split(RegExp('[,|]'))
      .map((String s) => s.trim())
      .where((String s) => s.isNotEmpty)
      .toList(growable: false);
}

/// A small RFC 4180 reader — quoted fields, doubled quotes, embedded newlines.
/// Not worth a dependency, and a CSV export is the only place we meet one.
List<List<String>> parseCsv(String source) {
  final List<List<String>> rows = <List<String>>[];
  List<String> row = <String>[];
  final StringBuffer field = StringBuffer();
  bool quoted = false;

  for (int i = 0; i < source.length; i++) {
    final String ch = source[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < source.length && source[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(ch);
      }
      continue;
    }
    switch (ch) {
      case '"':
        quoted = true;
      case ',':
        row.add(field.toString());
        field.clear();
      case '\r':
        break;
      case '\n':
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
      default:
        field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows.where((List<String> r) => r.any((String c) => c.isNotEmpty))
      .toList(growable: false);
}
