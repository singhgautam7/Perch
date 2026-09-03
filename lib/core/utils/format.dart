/// "2h", "3d", "5w" — the age shown beside a domain. Deliberately terse; the
/// full date lives on the detail screen.
String shortAge(DateTime when, {DateTime? now}) {
  final Duration d = (now ?? DateTime.now()).difference(when);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  if (d.inDays < 365) return '${d.inDays ~/ 7}w';
  return '${d.inDays ~/ 365}y';
}

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "3 Sep 2026" — used where a real date matters.
String longDate(DateTime when) =>
    '${when.day} ${_months[when.month - 1]} ${when.year}';

/// "1,284" — counts read in a tabular mono, so they get separators.
String grouped(int value) {
  final String s = value.abs().toString();
  final StringBuffer out = StringBuffer(value < 0 ? '-' : '');
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

/// "1 link" / "12 links".
String plural(int count, String singular, [String? pluralForm]) =>
    '$count ${count == 1 ? singular : (pluralForm ?? '${singular}s')}';
