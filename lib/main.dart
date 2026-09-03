import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/db/database.dart';
import 'core/db/settings_repository.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open the database and read settings once, before the first frame, so the
  // app starts on the right theme and the right tab with no flash.
  final PerchDatabase db = PerchDatabase();
  final AppSettings settings = await SettingsRepository(db).read();
  SettingsController.initial = settings;

  runApp(
    ProviderScope(
      overrides: <Override>[databaseProvider.overrideWithValue(db)],
      child: const PerchApp(),
    ),
  );
}
