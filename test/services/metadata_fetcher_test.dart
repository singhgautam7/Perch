import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:perch/core/services/metadata_fetcher.dart';

MetadataFetcher fetcherServing(String body, {int status = 200, String? type}) {
  return MetadataFetcher(
    client: MockClient((http.Request request) async {
      return http.Response(
        body,
        status,
        headers: <String, String>{
          'content-type': type ?? 'text/html; charset=utf-8',
        },
      );
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reads Open Graph tags and resolves a relative image', () async {
    final MetadataResult result = await fetcherServing('''
<html><head>
  <title>Fallback title</title>
  <meta property="og:title" content="Rust ownership, explained visually">
  <meta property="og:site_name" content="fasterthanli.me">
  <meta property="og:description" content="A visual walk through ownership.">
  <meta property="og:image" content="/img/hero.png">
  <link rel="icon" href="/favicon.png">
</head><body></body></html>
''').fetch('https://fasterthanli.me/articles/ownership');

    expect(result.outcome, MetadataOutcome.ok);
    expect(result.metadata.title, 'Rust ownership, explained visually');
    expect(result.metadata.siteName, 'fasterthanli.me');
    expect(result.metadata.description, 'A visual walk through ownership.');
    expect(result.metadata.imageUrl, 'https://fasterthanli.me/img/hero.png');
    expect(result.metadata.faviconUrl, 'https://fasterthanli.me/favicon.png');
  });

  test('falls back to <title> and the conventional favicon path', () async {
    final MetadataResult result = await fetcherServing(
      '<html><head><title>  Plain page  </title></head><body></body></html>',
    ).fetch('https://notes.local/2026/perch-brief');

    // A page with no image is not an error — it is the no-preview rung.
    expect(result.outcome, MetadataOutcome.noPreview);
    expect(result.metadata.title, 'Plain page');
    expect(result.metadata.imageUrl, isNull);
    expect(result.metadata.faviconUrl, 'https://notes.local/favicon.ico');
  });

  test('a 404 fails softly, still offering a favicon to try', () async {
    final MetadataResult result = await fetcherServing(
      'nope',
      status: 404,
    ).fetch('https://a.test/missing');

    expect(result.outcome, MetadataOutcome.failed);
    expect(result.metadata.title, isNull);
    expect(result.metadata.faviconUrl, 'https://a.test/favicon.ico');
  });

  test('a network error never throws at the caller', () async {
    final MetadataFetcher fetcher = MetadataFetcher(
      client: MockClient((http.Request _) async => throw const SocketFailure()),
    );
    final MetadataResult result = await fetcher.fetch('https://a.test/x');
    expect(result.outcome, MetadataOutcome.failed);
  });

  test('a non-HTML response is not parsed', () async {
    final MetadataResult result = await fetcherServing(
      base64.encode(<int>[1, 2, 3]),
      type: 'image/png',
    ).fetch('https://a.test/image.png');
    expect(result.outcome, MetadataOutcome.failed);
  });

  test('junk in the URL field is rejected before any request', () async {
    final MetadataResult result = await MetadataFetcher(
      client: MockClient((http.Request _) async => throw StateError('no call')),
    ).fetch('not a url');
    expect(result.outcome, MetadataOutcome.failed);
  });
}

class SocketFailure implements Exception {
  const SocketFailure();
}
