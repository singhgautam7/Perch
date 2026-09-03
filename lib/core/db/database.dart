import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'database.g.dart';

/// One SQLite file on the device. No account, no backend, no sync.
@DriftDatabase(
  tables: <Type>[Folders, Links, Tags, LinkTags, Settings],
  include: <String>{'search.drift'},
)
class PerchDatabase extends _$PerchDatabase {
  PerchDatabase() : super(driftDatabase(name: 'perch'));

  /// Test constructor — an in-memory database with the same schema.
  PerchDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      // Tables (the FTS5 virtual table included) before triggers — a trigger
      // cannot be compiled until the table it fires on exists.
      for (final DatabaseSchemaEntity e in allSchemaEntities) {
        if (e is! Trigger) await m.create(e);
      }
      for (final Trigger t in allSchemaEntities.whereType<Trigger>()) {
        await m.create(t);
      }
    },
    beforeOpen: (OpeningDetails details) async {
      // Cascades in `tables.dart` only bite when this is on.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
