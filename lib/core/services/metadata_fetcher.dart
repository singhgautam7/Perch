import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

/// What a page told us about itself. Every field is optional — a page that
/// offers nothing still produces a result, never an error.
@immutable
class LinkMetadata {
  const LinkMetadata({
    this.title,
    this.siteName,
    this.description,
    this.imageUrl,
    this.faviconUrl,
  });

  final String? title;
  final String? siteName;
  final String? description;
  final String? imageUrl;
  final String? faviconUrl;

  bool get isEmpty =>
      title == null &&
      siteName == null &&
      description == null &&
      imageUrl == null;
}

enum MetadataOutcome {
  /// Usable metadata, image included.
  ok,

  /// The page was read but offers no preview image.
  noPreview,

  /// The page could not be read at all.
  failed,
}

@immutable
class MetadataResult {
  const MetadataResult(this.outcome, this.metadata);

  final MetadataOutcome outcome;
  final LinkMetadata metadata;
}

/// Fetches link metadata directly from the site, on device. Nothing is proxied
/// and nothing is logged — this is the only network call Perch makes.
class MetadataFetcher {
  MetadataFetcher({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Enough of a page to reach the `<head>`; the rest is not worth the bytes.
  static const int _maxBytes = 512 * 1024;
  static const Duration _timeout = Duration(seconds: 12);

  /// A real UA, because a fair number of sites serve nothing useful without one.
  static const Map<String, String> _headers = <String, String>{
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/122.0 Mobile Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml',
    'Accept-Language': 'en',
  };

  Future<MetadataResult> fetch(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return const MetadataResult(MetadataOutcome.failed, LinkMetadata());
    }

    String? body;
    try {
      body = await _readHead(uri);
    } on Object {
      // A metadata fetch never takes the save down with it.
      body = null;
    }

    if (body == null) {
      return MetadataResult(
        MetadataOutcome.failed,
        LinkMetadata(faviconUrl: _defaultFavicon(uri)),
      );
    }

    // HTML parsing is the expensive half — it does not run on the UI isolate.
    final LinkMetadata meta = await compute(
      _parse,
      (html: body, baseUrl: uri.toString()),
    );

    return MetadataResult(
      meta.imageUrl == null ? MetadataOutcome.noPreview : MetadataOutcome.ok,
      meta,
    );
  }

  Future<String?> _readHead(Uri uri) async {
    final http.Request request = http.Request('GET', uri)
      ..headers.addAll(_headers)
      ..followRedirects = true
      ..maxRedirects = 5;

    final http.StreamedResponse response = await _client
        .send(request)
        .timeout(_timeout);
    if (response.statusCode >= 400) return null;

    final String? type = response.headers['content-type'];
    if (type != null && !type.contains('html') && !type.contains('xml')) {
      return null;
    }

    final List<int> bytes = <int>[];
    await for (final List<int> chunk in response.stream) {
      bytes.addAll(chunk);
      if (bytes.length >= _maxBytes) break;
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static String _defaultFavicon(Uri uri) => _conventionalFavicon(uri);

  void dispose() => _client.close();
}

/// `https://host/favicon.ico`. Built from the parts rather than by replacing
/// the path, which would leave the query's `?` behind.
String _conventionalFavicon(Uri uri) => Uri(
  scheme: uri.scheme,
  host: uri.host,
  port: uri.hasPort ? uri.port : null,
  path: '/favicon.ico',
).toString();

/// Runs on a background isolate — must stay top-level and take one argument.
LinkMetadata _parse(({String html, String baseUrl}) input) {
  final Document doc = html_parser.parse(input.html);
  final Uri base = Uri.parse(input.baseUrl);

  String? meta(List<String> keys) {
    for (final String key in keys) {
      final Element? el =
          doc.querySelector('meta[property="$key"]') ??
          doc.querySelector('meta[name="$key"]');
      final String? content = el?.attributes['content']?.trim();
      if (content != null && content.isNotEmpty) return content;
    }
    return null;
  }

  String? absolute(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final Uri? parsed = Uri.tryParse(raw);
    if (parsed == null) return null;
    return base.resolveUri(parsed).toString();
  }

  final String? title =
      meta(<String>['og:title', 'twitter:title']) ??
      doc.querySelector('title')?.text.trim();

  String? favicon;
  for (final String selector in <String>[
    'link[rel="icon"]',
    'link[rel="shortcut icon"]',
    'link[rel="apple-touch-icon"]',
  ]) {
    final String? href = doc.querySelector(selector)?.attributes['href'];
    favicon = absolute(href);
    if (favicon != null) break;
  }
  // Every site is entitled to the conventional path even if it says nothing.
  favicon ??= _conventionalFavicon(base);

  return LinkMetadata(
    title: title == null || title.isEmpty ? null : title,
    siteName: meta(<String>['og:site_name']),
    description: meta(<String>[
      'og:description',
      'twitter:description',
      'description',
    ]),
    imageUrl: absolute(meta(<String>['og:image', 'twitter:image'])),
    faviconUrl: favicon,
  );
}
