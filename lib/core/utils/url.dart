/// The host of [url] without a `www.` prefix — what every card's label row and
/// the domain filter show.
String hostOf(String url) {
  final Uri? uri = Uri.tryParse(url.trim());
  final String host = uri?.host ?? '';
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// A URL shortened for a single line: the host survives, and so does the last
/// path segment — the middle is what goes (board 1j, LONG URL).
String middleTruncate(String url, {int max = 44}) {
  if (url.length <= max) return url;
  final Uri? uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) {
    return '${url.substring(0, max - 3)}…';
  }
  final List<String> segments = uri.pathSegments
      .where((String s) => s.isNotEmpty)
      .toList();
  if (segments.isEmpty) return uri.host;
  return '${uri.host}/…/${segments.last}';
}

/// Pulls the first URL out of shared text. Share sheets hand over anything from
/// a bare URL to a sentence with one buried in it.
String? extractUrl(String text) {
  final RegExpMatch? match = RegExp(
    r'(https?://|www\.)[^\s<>"' r"'" r']+',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return null;
  final String raw = match.group(0)!.replaceAll(RegExp(r'[.,;:)\]]+$'), '');
  return raw.startsWith('www.') ? 'https://$raw' : raw;
}

/// True when [text] is, on its own, something we can save.
bool looksLikeUrl(String text) {
  final String t = text.trim();
  if (t.isEmpty || t.contains(RegExp(r'\s'))) return false;
  final Uri? uri = Uri.tryParse(t.contains('://') ? t : 'https://$t');
  return uri != null && uri.host.contains('.');
}

/// Adds a scheme to something the user typed bare.
String normalizeUrl(String input) {
  final String t = input.trim();
  return t.contains('://') ? t : 'https://$t';
}
