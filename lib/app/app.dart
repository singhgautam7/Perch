import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/db/settings_repository.dart';
import '../core/providers.dart';
import '../core/router/router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';

class PerchApp extends ConsumerStatefulWidget {
  const PerchApp({super.key});

  @override
  ConsumerState<PerchApp> createState() => _PerchAppState();
}

class _PerchAppState extends ConsumerState<PerchApp> {
  late final GoRouter _router = buildRouter(
    settings: ref.read(settingsProvider),
  );

  @override
  Widget build(BuildContext context) {
    // Only the fields that decide the theme — a view-mode change must not
    // rebuild the whole app.
    final (String familyId, ThemeMode mode, bool amoled, bool dynamicColor) =
        ref.watch(
          settingsProvider.select(
            (AppSettings s) =>
                (s.familyId, s.themeMode, s.amoled, s.dynamicColor),
          ),
        );
    final AppSettings themeSettings = AppSettings(
      familyId: familyId,
      themeMode: mode,
      amoled: amoled,
      dynamicColor: dynamicColor,
    );

    return MaterialApp.router(
      title: 'Perch',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      themeMode: mode,
      theme: _themeFor(themeSettings, Brightness.light),
      darkTheme: _themeFor(themeSettings, Brightness.dark),
    );
  }

  ThemeData _themeFor(AppSettings s, Brightness brightness) {
    final Tone tone = s.toneFor(brightness);
    return AppTheme.of(s.family, tone);
  }
}
