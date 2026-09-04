import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/db/settings_repository.dart';
import '../core/providers.dart';
import '../core/router/router.dart';
import '../core/services/share_intake.dart';
import '../core/services/wallpaper_seed.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../shared/widgets/app_snackbar.dart';

class PerchApp extends ConsumerStatefulWidget {
  const PerchApp({super.key});

  @override
  ConsumerState<PerchApp> createState() => _PerchAppState();
}

class _PerchAppState extends ConsumerState<PerchApp> {
  late final GoRouter _router = buildRouter(
    settings: ref.read(settingsProvider),
  );
  StreamSubscription<ShareResult>? _savedFromShare;

  @override
  void initState() {
    super.initState();
    // A share saves straight into Unsorted and confirms; it never opens a form.
    // Started after the first frame: a share that cold-starts the app can
    // otherwise finish saving before there is anything on screen to confirm on.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ShareHandler handler = ref.read(shareHandlerProvider);
      _savedFromShare = handler.saved.stream.listen(_confirmShareSave);
      unawaited(handler.start());
    });
  }

  @override
  void dispose() {
    unawaited(_savedFromShare?.cancel());
    super.dispose();
  }

  void _confirmShareSave(ShareResult result) {
    final BuildContext? context = _router
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (context == null || !context.mounted) return;
    AppSnackbar.show(
      context,
      SnackMessage(
        text: result.duplicate
            ? 'You already saved this'
            : 'Saved to Unsorted',
        variant: result.duplicate
            ? SnackVariant.warning
            : SnackVariant.success,
        actionLabel: 'Open',
        onAction: () => _router.push(Routes.link(result.id)),
      ),
    );
  }

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

  /// Dynamic color takes the seed from the OS; every other role is derived
  /// exactly as a bundled family's would be, so the two never diverge.
  ThemeData _themeFor(AppSettings s, Brightness brightness) {
    final Tone tone = s.toneFor(brightness);
    final Color? seed = s.dynamicColor
        ? ref.watch(wallpaperSeedProvider).valueOrNull
        : null;
    return seed == null
        ? AppTheme.of(s.family, tone)
        : AppTheme.fromSeed(seed, tone);
  }
}
