import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perch/core/db/database.dart';
import 'package:perch/core/db/folder_repository.dart';
import 'package:perch/core/db/link_repository.dart';
import 'package:perch/core/db/settings_repository.dart';
import 'package:perch/core/db/tag_repository.dart';
import 'package:perch/core/providers.dart';
import 'package:perch/core/services/import_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PerchDatabase db;
  late ProviderContainer container;
  late ImportExportService service;
  late FolderRepository folders;
  late LinkRepository links;
  late TagRepository tags;

  setUp(() {
    db = PerchDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: <Override>[databaseProvider.overrideWithValue(db)],
    );
    service = container.read(importExportProvider);
    folders = FolderRepository(db);
    links = LinkRepository(db);
    tags = TagRepository(db);
  });

  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<void> seed() async {
    final int reading = await folders.create(name: 'Reading');
    final int papers = await folders.create(name: 'AI papers', parentId: reading);
    final int deep = await folders.create(name: '2019', parentId: papers);

    final int a = await links.create(
      url: 'https://arxiv.org/abs/1706.03762',
      title: 'Attention Is All You Need',
      note: '## Why\n- [x] read\n- [ ] re-read 3.2',
      folderId: deep,
    );
    await links.create(url: 'https://a.test/loose');
    await tags.setForLink(a, <String>['ml', 'reference']);
    await links.update(
      a,
      const LinksCompanion(siteName: Value<String>('arXiv')),
    );
    await SettingsRepository(db).put('theme.family', 'ember');
  }

  test('export then import restores the tree, tags, notes and settings', () async {
    await seed();
    final String json = await service.exportJson();

    // Wipe by importing into a database that has drifted since.
    await links.create(url: 'https://should.be/gone');
    await folders.create(name: 'Stray');

    final int imported = await service.importJson(json);
    expect(imported, 2);

    final List<Folder> all = await db.select(db.folders).get();
    expect(all.map((Folder f) => f.name).toSet(), <String>{
      'Reading',
      'AI papers',
      '2019',
    });

    // Nesting survived the id remap.
    final Folder deep = all.firstWhere((Folder f) => f.name == '2019');
    expect(
      (await folders.breadcrumb(deep.id)).map((Folder f) => f.name),
      <String>['Reading', 'AI papers', '2019'],
    );

    final Link paper = (await db.select(db.links).get()).firstWhere(
      (Link l) => l.title == 'Attention Is All You Need',
    );
    expect(paper.folderId, deep.id);
    expect(paper.note, '## Why\n- [x] read\n- [ ] re-read 3.2');
    expect(paper.siteName, 'arXiv');
    expect(
      (await tags.forLink(paper.id)).map((Tag t) => t.name).toSet(),
      <String>{'ml', 'reference'},
    );

    expect((await SettingsRepository(db).read()).familyId, 'ember');
    expect(
      (await db.select(db.links).get()).any(
        (Link l) => l.url == 'https://should.be/gone',
      ),
      isFalse,
    );
  });

  test('a second round trip preserves content and structure', () async {
    await seed();
    final String first = await service.exportJson();
    await service.importJson(first);
    final String second = await service.exportJson();

    // Row ids are reassigned on import by design, so the comparison is on what
    // the ids mean — a link's folder path — not on the numbers themselves.
    List<Map<String, Object?>> normalise(String raw) {
      final Map<String, Object?> doc = jsonDecode(raw) as Map<String, Object?>;
      final List<Map<String, Object?>> folderRows =
          (doc['folders']! as List<Object?>).cast<Map<String, Object?>>();
      final Map<int, Map<String, Object?>> byId = <int, Map<String, Object?>>{
        for (final Map<String, Object?> f in folderRows) f['id']! as int: f,
      };
      String path(Object? id) {
        if (id == null) return '';
        final Map<String, Object?> f = byId[id as int]!;
        final String parent = path(f['parentId']);
        return parent.isEmpty ? '${f['name']}' : '$parent/${f['name']}';
      }

      final List<Map<String, Object?>> rows =
          ((doc['links']! as List<Object?>).cast<Map<String, Object?>>())
              .map(
                (Map<String, Object?> l) => <String, Object?>{
                  ...l,
                  'folderId': path(l['folderId']),
                },
              )
              .toList();
      rows.sort(
        (Map<String, Object?> a, Map<String, Object?> b) =>
            '${a['url']}'.compareTo('${b['url']}'),
      );
      return rows;
    }

    expect(normalise(second), normalise(first));
  });

  test('the search index is rebuilt for imported links', () async {
    await seed();
    final String json = await service.exportJson();
    await service.importJson(json);

    final SearchCheck check = SearchCheck(db);
    expect(await check.matches('Attention'), 1);
    expect(await check.matches('re-read'), 1);
  });

  test('a file that is not a Perch export is refused', () async {
    expect(
      () => service.importJson('{"something":"else"}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('a link referencing a tag the file omits still gets it', () async {
    const String json = '''
{"perch":1,"folders":[],"tags":[],"settings":{},
 "links":[{"url":"https://a.test/x","title":"X","note":"","tags":["orphan"],
           "createdAt":"2026-01-01T00:00:00.000","updatedAt":"2026-01-01T00:00:00.000"}]}
''';
    await service.importJson(json);
    final Link link = (await db.select(db.links).get()).single;
    expect((await tags.forLink(link.id)).single.name, 'orphan');
  });
}

/// Reads the FTS index directly — importing must leave it usable.
class SearchCheck {
  const SearchCheck(this.db);

  final PerchDatabase db;

  Future<int> matches(String term) async {
    final List<QueryRow> rows = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM links_fts WHERE links_fts MATCH ?',
          variables: <Variable<Object>>[Variable<String>('"$term"*')],
        )
        .get();
    return rows.first.read<int>('c');
  }
}
