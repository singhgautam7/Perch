import 'package:flutter/material.dart';

import '../theme/palette.dart';
import 'database.dart';
import 'link_repository.dart';

/// How the Links tab draws its cards (board 1j).
enum LinkViewMode {
  large,
  minimal,
  grid;

  String get label => switch (this) {
    LinkViewMode.large => 'Large',
    LinkViewMode.minimal => 'Minimal',
    LinkViewMode.grid => 'Grid',
  };

  /// The wording the anchored switcher uses (board 3a).
  String get menuLabel => switch (this) {
    LinkViewMode.large => 'Large list',
    LinkViewMode.minimal => 'Minimal list',
    LinkViewMode.grid => 'Grid',
  };
}

/// Which tab Perch opens on.
enum LandingTab { links, folders }

/// How folders are ordered.
enum FolderSort {
  name,
  newest,
  mostLinks;

  String get label => switch (this) {
    FolderSort.name => 'Name A–Z',
    FolderSort.newest => 'Newest first',
    FolderSort.mostLinks => 'Most links',
  };

  /// The short form the header shows.
  String get short => switch (this) {
    FolderSort.name => 'Name',
    FolderSort.newest => 'Newest',
    FolderSort.mostLinks => 'Most links',
  };
}

/// Everything in the settings table, resolved. Immutable so a `select` on one
/// field rebuilds only what depends on it.
@immutable
class AppSettings {
  const AppSettings({
    this.familyId = 'perch',
    this.themeMode = ThemeMode.system,
    this.amoled = false,
    this.dynamicColor = false,
    this.blur = false,
    this.viewMode = LinkViewMode.large,
    this.folderSort = FolderSort.name,
    this.landingTab = LandingTab.links,
    this.sort = LinkSort.newest,
    this.onboarded = false,
    this.devTools = false,
  });

  final String familyId;
  final ThemeMode themeMode;

  /// True black. Only takes effect while dark is in effect, and only for a
  /// family that ships it.
  final bool amoled;
  final bool dynamicColor;

  /// The one real GPU cost in the app — off on first run.
  final bool blur;
  final LinkViewMode viewMode;
  final FolderSort folderSort;
  final LandingTab landingTab;
  final LinkSort sort;
  final bool onboarded;
  final bool devTools;

  ThemeFamily get family => ThemeFamily.byId(familyId);

  /// The tone to render for a given platform brightness.
  Tone toneFor(Brightness platform) {
    final bool dark = switch (themeMode) {
      ThemeMode.light => false,
      ThemeMode.dark => true,
      ThemeMode.system => platform == Brightness.dark,
    };
    if (!dark) return Tone.light;
    return amoled && family.hasAmoled ? Tone.amoled : Tone.dark;
  }

  AppSettings copyWith({
    String? familyId,
    ThemeMode? themeMode,
    bool? amoled,
    bool? dynamicColor,
    bool? blur,
    LinkViewMode? viewMode,
    FolderSort? folderSort,
    LandingTab? landingTab,
    LinkSort? sort,
    bool? onboarded,
    bool? devTools,
  }) {
    return AppSettings(
      familyId: familyId ?? this.familyId,
      themeMode: themeMode ?? this.themeMode,
      amoled: amoled ?? this.amoled,
      dynamicColor: dynamicColor ?? this.dynamicColor,
      blur: blur ?? this.blur,
      viewMode: viewMode ?? this.viewMode,
      folderSort: folderSort ?? this.folderSort,
      landingTab: landingTab ?? this.landingTab,
      sort: sort ?? this.sort,
      onboarded: onboarded ?? this.onboarded,
      devTools: devTools ?? this.devTools,
    );
  }
}

class SettingsRepository {
  SettingsRepository(this._db);

  final PerchDatabase _db;

  static const String kFamily = 'theme.family';
  static const String kMode = 'theme.mode';
  static const String kAmoled = 'theme.amoled';
  static const String kDynamic = 'theme.dynamic';
  static const String kBlur = 'appearance.blur';
  static const String kViewMode = 'links.view';
  static const String kFolderSort = 'folders.sort';
  static const String kLanding = 'app.landing';
  static const String kSort = 'links.sort';
  static const String kOnboarded = 'app.onboarded';
  static const String kDevTools = 'app.devTools';

  Stream<AppSettings> watch() =>
      _db.select(_db.settings).watch().map(_resolve);

  Future<AppSettings> read() async => _resolve(await _db.select(_db.settings).get());

  AppSettings _resolve(List<Setting> rows) {
    final Map<String, String> m = <String, String>{
      for (final Setting s in rows) s.key: s.value,
    };
    T pick<T extends Enum>(String key, List<T> values, T fallback) {
      final String? raw = m[key];
      return values.firstWhere((T v) => v.name == raw, orElse: () => fallback);
    }

    return AppSettings(
      familyId: m[kFamily] ?? 'perch',
      themeMode: pick(kMode, ThemeMode.values, ThemeMode.system),
      amoled: m[kAmoled] == 'true',
      dynamicColor: m[kDynamic] == 'true',
      blur: m[kBlur] == 'true',
      viewMode: pick(kViewMode, LinkViewMode.values, LinkViewMode.large),
      folderSort: pick(kFolderSort, FolderSort.values, FolderSort.name),
      landingTab: pick(kLanding, LandingTab.values, LandingTab.links),
      sort: pick(kSort, LinkSort.values, LinkSort.newest),
      onboarded: m[kOnboarded] == 'true',
      devTools: m[kDevTools] == 'true',
    );
  }

  Future<void> put(String key, String value) {
    return _db
        .into(_db.settings)
        .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
  }

  Future<void> putBool(String key, {required bool value}) =>
      put(key, value ? 'true' : 'false');

  Future<Map<String, String>> all() async {
    final List<Setting> rows = await _db.select(_db.settings).get();
    return <String, String>{for (final Setting s in rows) s.key: s.value};
  }
}
