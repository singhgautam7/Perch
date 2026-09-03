import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'settings_widgets.dart';

/// A read-only look at what is actually stored. Reachable only after seven taps
/// on the version line.
class DevToolsScreen extends ConsumerStatefulWidget {
  const DevToolsScreen({super.key});

  @override
  ConsumerState<DevToolsScreen> createState() => _DevToolsScreenState();
}

class _DevToolsScreenState extends ConsumerState<DevToolsScreen> {
  static const List<String> _tables = <String>[
    'links',
    'folders',
    'tags',
    'link_tags',
    'settings',
    'links_fts',
  ];

  String _table = 'links';

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final PerchDatabase db = ref.watch(databaseProvider);

    return SettingsScaffold(
      title: 'Database explorer',
      children: <Widget>[
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final String t in _tables)
              ChoiceChip(
                label: Text(t, style: PerchType.monoSmall),
                selected: t == _table,
                showCheckmark: false,
                onSelected: (_) => setState(() => _table = t),
              ),
          ],
        ),
        const SizedBox(height: Space.lg),
        FutureBuilder<List<drift.QueryRow>>(
          // Read-only, and capped — this is a peek, not a query console.
          future: db.customSelect('SELECT * FROM $_table LIMIT 50').get(),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<drift.QueryRow>> snapshot,
              ) {
                if (snapshot.hasError) {
                  return Text(
                    '${snapshot.error}',
                    style: PerchType.monoSmall.copyWith(color: c.danger),
                  );
                }
                final List<drift.QueryRow> rows =
                    snapshot.data ?? const <drift.QueryRow>[];
                if (rows.isEmpty) {
                  return Text(
                    'No rows.',
                    style: PerchType.monoSmall.copyWith(
                      color: c.onSurfaceMuted,
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      '${rows.length} ROW(S), FIRST 50',
                      style: PerchType.monoSmall.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Space.sm),
                    for (final drift.QueryRow row in rows)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(Space.row),
                        decoration: BoxDecoration(
                          color: c.surfaceContainer,
                          borderRadius: Radii.chipR,
                          border: Border.all(color: c.outline),
                        ),
                        child: SelectableText(
                          row.data.entries
                              .map(
                                (MapEntry<String, Object?> e) =>
                                    '${e.key}: ${e.value}',
                              )
                              .join('\n'),
                          style: PerchType.monoSmall.copyWith(
                            color: c.onSurface,
                          ),
                        ),
                      ),
                  ],
                );
              },
        ),
      ],
    );
  }
}
