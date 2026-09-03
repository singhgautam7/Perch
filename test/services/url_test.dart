import 'package:flutter_test/flutter_test.dart';
import 'package:perch/core/utils/format.dart';
import 'package:perch/core/utils/url.dart';

void main() {
  group('extractUrl', () {
    test('pulls a URL out of the sentence a share sheet hands over', () {
      expect(
        extractUrl('Check this out https://craigmod.com/essays/plain-text/ !'),
        'https://craigmod.com/essays/plain-text/',
      );
    });

    test('handles a bare URL', () {
      expect(extractUrl('https://a.test/x'), 'https://a.test/x');
    });

    test('adds a scheme to a www. link', () {
      expect(extractUrl('see www.example.com/page'), 'https://www.example.com/page');
    });

    test('drops trailing punctuation that belongs to the sentence', () {
      expect(extractUrl('read https://a.test/x.'), 'https://a.test/x');
      expect(extractUrl('(https://a.test/x)'), 'https://a.test/x');
    });

    test('returns null when there is no link', () {
      expect(extractUrl('just some shared text'), isNull);
    });

    test('takes the first URL when several are shared', () {
      expect(
        extractUrl('https://a.test/1 and https://b.test/2'),
        'https://a.test/1',
      );
    });
  });

  group('looksLikeUrl', () {
    test('accepts something typed without a scheme', () {
      expect(looksLikeUrl('example.com'), isTrue);
      expect(looksLikeUrl('https://example.com/a'), isTrue);
    });

    test('rejects prose and half-typed hosts', () {
      expect(looksLikeUrl('hello world'), isFalse);
      expect(looksLikeUrl('example'), isFalse);
      expect(looksLikeUrl(''), isFalse);
    });
  });

  group('hostOf', () {
    test('drops the www. prefix', () {
      expect(hostOf('https://www.arxiv.org/abs/1'), 'arxiv.org');
      expect(hostOf('https://arxiv.org/abs/1'), 'arxiv.org');
    });

    test('is empty rather than throwing for junk', () {
      expect(hostOf('not a url'), '');
    });
  });

  group('middleTruncate', () {
    test('keeps the host and the last segment', () {
      expect(
        middleTruncate(
          'https://fasterthanli.me/articles/a/very/long/path/ownership',
        ),
        'fasterthanli.me/…/ownership',
      );
    });

    test('leaves a short URL alone', () {
      expect(middleTruncate('https://a.test/x'), 'https://a.test/x');
    });
  });

  group('formatting', () {
    test('short ages read as the boards show them', () {
      final DateTime now = DateTime(2026, 9, 3, 12);
      expect(shortAge(now.subtract(const Duration(minutes: 30)), now: now), '30m');
      expect(shortAge(now.subtract(const Duration(hours: 2)), now: now), '2h');
      expect(shortAge(now.subtract(const Duration(days: 3)), now: now), '3d');
      expect(shortAge(now.subtract(const Duration(days: 21)), now: now), '3w');
    });

    test('counts group in thousands', () {
      expect(grouped(1284), '1,284');
      expect(grouped(128), '128');
      expect(grouped(1000000), '1,000,000');
    });

    test('plurals agree', () {
      expect(plural(1, 'link'), '1 link');
      expect(plural(0, 'link'), '0 links');
      expect(plural(3, 'folder'), '3 folders');
    });
  });
}
