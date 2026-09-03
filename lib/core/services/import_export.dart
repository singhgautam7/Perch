import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../db/tables.dart';
import '../providers.dart';

/// A portable, human-readable backup: folders as a parentId tree, links with
/// their tags and markdown note inline. Round-trips losslessly.
class PerchArchive {
  const PerchArchive({
    required this.folders,
    required this.tags,
    required this.links,
    required this.settings,
    required this.exportedAt,
  });

  /// Bumped only when the shape changes in a way an older import cannot read.
  static const int formatVersion = 1;

  final List<Map<String, Object?>> folders;
  final List<Map<String, Object?>> tags;
  final List<Map<String, Object?>> links;
  final Map<String, String> settings;
  final DateTime exportedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'perch': formatVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'folders': folders,
    'tags': tags,
    'links': links,
    'settings': settings,
  };

  static PerchArchive fromJson(Map<String, Object?> json) {
    final Object? version = json['perch'];
    if (version is! int || version > formatVersion) {
      throw const FormatException('This file is not a Perch export.');
    }
    List<Map<String, Object?>> list(String key) =>
        (json[key] as List<Object?>? ?? const <Object?>[])
            .cast<Map<String, Object?>>();

    return PerchArchive(
      folders: list('folders'),
      tags: list('tags'),
      links: list('links'),
      settings:
          (json['settings'] as Map<String, Object?>? ?? const <String, Object?>{})
              .map((String k, Object? v) => MapEntry<String, String>(k, '$v')),
      exportedAt:
          DateTime.tryParse('${json['exportedAt']}') ?? DateTime.now(),
    );
  }

  int get linkCount => links.length;
}

/// Reads and writes the archive. Encoding and decoding run off the UI isolate —
/// a few thousand links is real work.
class ImportExportService {
  ImportExportService(this._ref);

  final Ref _ref;

  PerchDatabase get _db => _ref.read(databaseProvider);

  Future<PerchArchive> buildArchive() async {
    final List<Folder> folders = await _db.select(_db.folders).get();
    final List<Tag> tags = await _db.select(_db.tags).get();
    final List<Link> links = await _db.select(_db.links).get();
    final List<LinkTag> linkTags = await _db.select(_db.linkTags).get();
    final List<Setting> settings = await _db.select(_db.settings).get();

    final Map<int, String> tagNames = <int, String>{
      for (final Tag t in tags) t.id: t.name,
    };
    final Map<int, List<String>> tagsByLink = <int, List<String>>{};
    for (final LinkTag lt in linkTags) {
      final String? name = tagNames[lt.tagId];
      if (name != null) {
        tagsByLink.putIfAbsent(lt.linkId, () => <String>[]).add(name);
      }
    }

    return PerchArchive(
      exportedAt: DateTime.now(),
      folders: folders
          .map(
            (Folder f) => <String, Object?>{
              'id': f.id,
              'name': f.name,
              'parentId': f.parentId,
              'sortIndex': f.sortIndex,
              'createdAt': f.createdAt.toIso8601String(),
              'updatedAt': f.updatedAt.toIso8601String(),
            },
          )
          .toList(growable: false),
      tags: tags
          .map(
            (Tag t) => <String, Object?>{
              'name': t.name,
              'color': t.color,
              'createdAt': t.createdAt.toIso8601String(),
            },
          )
          .toList(growable: false),
      links: links
          .map(
            (Link l) => <String, Object?>{
              'url': l.url,
              'title': l.title,
              'note': l.note,
              'folderId': l.folderId,
              'createdAt': l.createdAt.toIso8601String(),
              'updatedAt': l.updatedAt.toIso8601String(),
              'openedAt': l.openedAt?.toIso8601String(),
              'openCount': l.openCount,
              'siteName': l.siteName,
              'description': l.description,
              'imageUrl': l.imageUrl,
              'faviconUrl': l.faviconUrl,
              'fetchedAt': l.fetchedAt?.toIso8601String(),
              'fetchStatus': l.fetchStatus.name,
              'tags': tagsByLink[l.id] ?? const <String>[],
            },
          )
          .toList(growable: false),
      settings: <String, String>{for (final Setting s in settings) s.key: s.value},
    );
  }

  /// The export document, pretty-printed so it can be read in a text editor.
  Future<String> exportJson() async {
    final PerchArchive archive = await buildArchive();
    return compute(_encode, archive.toJson());
  }

  /// Replaces everything with the contents of [json].
  ///
  /// Ids in the file are remapped: a folder's parent is resolved through the
  /// map as the tree is written, so nesting survives a round trip even though
  /// the new rows get new ids.
  Future<int> importJson(String json) async {
    final PerchArchive archive = PerchArchive.fromJson(await compute(_decode, json));

    return _db.transaction(() async {
      await _db.delete(_db.linkTags).go();
      await _db.delete(_db.links).go();
      await _db.delete(_db.folders).go();
      await _db.delete(_db.tags).go();

      final Map<int, int> folderIds = <int, int>{};
      // Parents before children, so a parent's new id is always known.
      for (final Map<String, Object?> f in _topologicallySorted(archive.folders)) {
        final int oldId = f['id']! as int;
        final Object? oldParent = f['parentId'];
        folderIds[oldId] = await _db
            .into(_db.folders)
            .insert(
              FoldersCompanion.insert(
                name: '${f['name']}',
                parentId: Value<int?>(
                  oldParent == null ? null : folderIds[oldParent as int],
                ),
                sortIndex: Value<int>((f['sortIndex'] as int?) ?? 0),
                createdAt: _date(f['createdAt']),
                updatedAt: _date(f['updatedAt']),
              ),
            );
      }

      final Map<String, int> tagIds = <String, int>{};
      for (final Map<String, Object?> t in archive.tags) {
        final String name = '${t['name']}';
        tagIds[name] = await _db
            .into(_db.tags)
            .insert(
              TagsCompanion.insert(
                name: name,
                color: Value<int?>(t['color'] as int?),
                createdAt: _date(t['createdAt']),
              ),
            );
      }

      int imported = 0;
      for (final Map<String, Object?> l in archive.links) {
        final Object? oldFolder = l['folderId'];
        final int id = await _db
            .into(_db.links)
            .insert(
              LinksCompanion.insert(
                url: '${l['url']}',
                title: Value<String>('${l['title'] ?? ''}'),
                note: Value<String>('${l['note'] ?? ''}'),
                folderId: Value<int?>(
                  oldFolder == null ? null : folderIds[oldFolder as int],
                ),
                createdAt: _date(l['createdAt']),
                updatedAt: _date(l['updatedAt']),
                openedAt: Value<DateTime?>(
                  l['openedAt'] == null ? null : _date(l['openedAt']),
                ),
                openCount: Value<int>((l['openCount'] as int?) ?? 0),
                siteName: Value<String?>(l['siteName'] as String?),
                description: Value<String?>(l['description'] as String?),
                imageUrl: Value<String?>(l['imageUrl'] as String?),
                faviconUrl: Value<String?>(l['faviconUrl'] as String?),
                fetchedAt: Value<DateTime?>(
                  l['fetchedAt'] == null ? null : _date(l['fetchedAt']),
                ),
                fetchStatus: Value<FetchStatus>(
                  FetchStatus.values.firstWhere(
                    (FetchStatus s) => s.name == l['fetchStatus'],
                    orElse: () => FetchStatus.pending,
                  ),
                ),
              ),
            );

        for (final Object? raw
            in (l['tags'] as List<Object?>? ?? const <Object?>[])) {
          final String name = '$raw';
          // A tag a link references but the tags list omits is still honoured —
          // a hand-edited file should not silently lose tags.
          final int tagId =
              tagIds[name] ??
              (tagIds[name] = await _db
                  .into(_db.tags)
                  .insert(
                    TagsCompanion.insert(
                      name: name,
                      createdAt: DateTime.now(),
                    ),
                  ));
          await _db
              .into(_db.linkTags)
              .insert(
                LinkTagsCompanion.insert(linkId: id, tagId: tagId),
                mode: InsertMode.insertOrIgnore,
              );
        }
        imported++;
      }

      for (final MapEntry<String, String> e in archive.settings.entries) {
        await _db
            .into(_db.settings)
            .insertOnConflictUpdate(
              SettingsCompanion.insert(key: e.key, value: e.value),
            );
      }
      return imported;
    });
  }

  /// Folders ordered so a parent always precedes its children.
  static List<Map<String, Object?>> _topologicallySorted(
    List<Map<String, Object?>> folders,
  ) {
    final Map<int, Map<String, Object?>> byId = <int, Map<String, Object?>>{
      for (final Map<String, Object?> f in folders) f['id']! as int: f,
    };
    final List<Map<String, Object?>> out = <Map<String, Object?>>[];
    final Set<int> placed = <int>{};

    void place(Map<String, Object?> f, Set<int> seen) {
      final int id = f['id']! as int;
      if (placed.contains(id) || !seen.add(id)) return;
      final Object? parent = f['parentId'];
      if (parent != null && byId.containsKey(parent)) {
        place(byId[parent as int]!, seen);
      }
      if (placed.add(id)) out.add(f);
    }

    for (final Map<String, Object?> f in folders) {
      place(f, <int>{});
    }
    return out;
  }

  static DateTime _date(Object? raw) =>
      DateTime.tryParse('$raw') ?? DateTime.now();
}

String _encode(Map<String, Object?> json) =>
    const JsonEncoder.withIndent('  ').convert(json);

Map<String, Object?> _decode(String raw) =>
    jsonDecode(raw) as Map<String, Object?>;

final Provider<ImportExportService> importExportProvider =
    Provider<ImportExportService>(ImportExportService.new);
