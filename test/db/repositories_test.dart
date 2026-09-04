import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perch/core/db/database.dart';
import 'package:perch/core/db/folder_repository.dart';
import 'package:perch/core/db/link_repository.dart';
import 'package:perch/core/db/search_repository.dart';
import 'package:perch/core/db/tag_repository.dart';

void main() {
  late PerchDatabase db;
  late FolderRepository folders;
  late LinkRepository links;
  late TagRepository tags;
  late SearchRepository search;

  setUp(() async {
    db = PerchDatabase.forTesting(NativeDatabase.memory());
    folders = FolderRepository(db);
    links = LinkRepository(db);
    tags = TagRepository(db);
    search = SearchRepository(db, links);
  });

  tearDown(() => db.close());

  test('folders nest and the breadcrumb walks back to the root', () async {
    final int reading = await folders.create(name: 'Reading');
    final int papers = await folders.create(name: 'AI papers', parentId: reading);
    final int old = await folders.create(name: '2019', parentId: papers);

    expect(
      (await folders.breadcrumb(old)).map((Folder f) => f.name),
      <String>['Reading', 'AI papers', '2019'],
    );
    expect((await folders.descendantIds(reading)).toSet(), <int>{
      reading,
      papers,
      old,
    });
  });

  test('a folder cannot be moved into its own subtree', () async {
    final int a = await folders.create(name: 'A');
    final int b = await folders.create(name: 'B', parentId: a);
    expect(await folders.move(a, b), isFalse);
    expect(await folders.move(b, null), isTrue);
  });

  test('deleting a folder keeps its links, in Unsorted', () async {
    final int f = await folders.create(name: 'Temp');
    final int id = await links.create(url: 'https://a.test', folderId: f);
    await folders.delete(f);
    expect((await links.byId(id))!.folderId, isNull);
  });

  test('tags join many-to-many and are matched case-insensitively', () async {
    final int id = await links.create(url: 'https://a.test');
    await tags.setForLink(id, <String>['Reading', 'reading', 'ml']);
    final List<Tag> t = await tags.forLink(id);
    expect(t.map((Tag e) => e.name).toSet(), <String>{'Reading', 'ml'});

    await tags.setForLink(id, <String>['ml']);
    expect((await tags.forLink(id)).single.name, 'ml');
  });

  test('FTS finds a link by title, note and metadata', () async {
    await links.create(
      url: 'https://arxiv.org/abs/1706.03762',
      title: 'Attention Is All You Need',
      note: 'Re-read section 3.2 before the reading group.',
    );
    await links.create(url: 'https://example.test', title: 'Unrelated');

    expect((await search.search(query: 'atten')).length, 1);
    expect((await search.search(query: 'section')).length, 1);
    expect((await search.search(query: 'nothinghere')), isEmpty);
  });

  test('editing a link keeps the search index in step', () async {
    final int id = await links.create(url: 'https://a.test', title: 'Before');
    expect((await search.search(query: 'Before')).length, 1);

    await links.update(id, const LinksCompanion(title: Value<String>('After')));
    expect((await search.search(query: 'Before')), isEmpty);
    expect((await search.search(query: 'After')).length, 1);

    await links.delete(id);
    expect((await search.search(query: 'After')), isEmpty);
  });

  test('search counts match what search returns', () async {
    for (int i = 0; i < 5; i++) {
      await links.create(url: 'https://a.test/$i', title: 'Item $i');
    }
    expect(await search.count(), 5);
    expect((await search.search(limit: 2)).length, 2);
    expect(await search.count(query: 'Item'), 5);
    expect(await search.count(query: 'Item 3'), 1);
  });

  test('tag AND requires every tag, OR requires one', () async {
    final int both = await links.create(url: 'https://a.test/both');
    final int one = await links.create(url: 'https://a.test/one');
    await tags.setForLink(both, <String>['ml', 'reference']);
    await tags.setForLink(one, <String>['ml']);

    final List<Tag> all = await tags.forLink(both);
    final Set<int> ids = all.map((Tag t) => t.id).toSet();

    expect(
      (await search.search(
        filters: SearchFilters(tagIds: ids, tagMatch: TagMatch.all),
      )).single.link.id,
      both,
    );
    expect(
      (await search.search(
        filters: SearchFilters(tagIds: ids),
      )).length,
      2,
    );
  });

  test('search filters combine', () async {
    final int f = await folders.create(name: 'Reading');
    final int withNote = await links.create(
      url: 'https://a.test/x',
      title: 'One',
      note: 'note body',
      folderId: f,
    );
    await links.create(url: 'https://b.test/y', title: 'Two');
    await tags.setForLink(withNote, <String>['ml']);

    expect(
      (await search.search(
        filters: const SearchFilters(hasNote: Tri.yes),
      )).single.link.id,
      withNote,
    );
    expect(
      (await search.search(
        filters: SearchFilters(folderId: f),
        folderScope: <int>[f],
      )).single.link.id,
      withNote,
    );
    expect(
      (await search.search(filters: const SearchFilters(domains: <String>{'b.test'}))).length,
      1,
    );
  });
}
