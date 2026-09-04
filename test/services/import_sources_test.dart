import 'package:flutter_test/flutter_test.dart';
import 'package:perch/core/services/import_sources.dart';

void main() {
  group('parseCsv', () {
    test('handles quotes, doubled quotes and embedded newlines', () {
      final List<List<String>> rows = parseCsv(
        'a,b,c\n'
        '1,"two, with comma","he said ""hi"""\n'
        '2,"line\nbreak",z\n',
      );
      expect(rows.length, 3);
      expect(rows[1], <String>['1', 'two, with comma', 'he said "hi"']);
      expect(rows[2][1], 'line\nbreak');
    });
  });

  group('parseNetscapeBookmarks', () {
    // The real thing never closes <DT> or <p>; the parser must not rely on it.
    const String file = '''
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<DL><p>
    <DT><H3>Reading</H3>
    <DL><p>
        <DT><A HREF="https://craigmod.com/essays/plain_text" ADD_DATE="1700000000">Plain text</A>
        <DT><H3>AI papers</H3>
        <DL><p>
            <DT><A HREF="https://arxiv.org/abs/1706.03762">Attention Is All You Need</A>
    </DL><p>
    </DL><p>
    <DT><A HREF="https://example.test/loose">Loose one</A>
</DL><p>
''';

    test('rebuilds the folder path from the nesting', () {
      final List<ImportedLink> links = parseNetscapeBookmarks(file);
      expect(links.length, 3);

      final ImportedLink nested = links.firstWhere(
        (ImportedLink l) => l.url.contains('arxiv'),
      );
      expect(nested.folderPath, <String>['Reading', 'AI papers']);
      expect(nested.title, 'Attention Is All You Need');

      final ImportedLink loose = links.firstWhere(
        (ImportedLink l) => l.url.contains('example.test'),
      );
      expect(loose.folderPath, isEmpty);
    });

    test('reads ADD_DATE as seconds', () {
      final ImportedLink first = parseNetscapeBookmarks(file).first;
      expect(first.createdAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    });

    test('ignores anchors that are not links', () {
      expect(parseNetscapeBookmarks('<a href="#top">Top</a>'), isEmpty);
    });
  });

  test('parsePocketCsv maps tags and keeps archived status as a tag', () {
    final List<ImportedLink> links = parsePocketCsv(
      'title,url,time_added,tags,status\n'
      'Plain text,https://craigmod.com/essays/plain_text,1700000000,"reading|essays",unread\n'
      'Old one,https://example.test/old,1600000000,,archive\n',
    );
    expect(links.first.tags, <String>['reading', 'essays']);
    expect(links.last.tags, <String>['archive']);
  });

  test('parseRaindropCsv splits the folder path and reads favourite', () {
    final List<ImportedLink> links = parseRaindropCsv(
      'title,note,url,folder,tags,created,favorite\n'
      'Leeks,Braise them,https://bonappetit.test/leeks,Recipes/Weeknight,'
      '"recipes",2026-09-01T10:00:00Z,true\n'
      'Loose,,https://example.test/x,Unsorted,,2026-09-02T10:00:00Z,false\n',
    );
    expect(links.first.folderPath, <String>['Recipes', 'Weeknight']);
    expect(links.first.note, 'Braise them');
    expect(links.first.isFavorite, isTrue);
    // "Unsorted" is Raindrop's root, not a folder anybody made.
    expect(links.last.folderPath, isEmpty);
  });

  test('a file with no url column yields nothing rather than throwing', () {
    expect(parseRaindropCsv('a,b\n1,2\n'), isEmpty);
  });
}
