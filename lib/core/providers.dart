import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'db/folder_repository.dart';
import 'db/link_repository.dart';
import 'db/search_repository.dart';
import 'db/settings_repository.dart';
import 'db/tag_repository.dart';

/// Overridden in `main` with the instance opened during bootstrap, so nothing
/// in the tree ever waits on the database to appear.
final Provider<PerchDatabase> databaseProvider = Provider<PerchDatabase>(
  (Ref ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final Provider<FolderRepository> folderRepositoryProvider =
    Provider<FolderRepository>(
      (Ref ref) => FolderRepository(ref.watch(databaseProvider)),
    );

final Provider<LinkRepository> linkRepositoryProvider =
    Provider<LinkRepository>(
      (Ref ref) => LinkRepository(ref.watch(databaseProvider)),
    );

final Provider<TagRepository> tagRepositoryProvider = Provider<TagRepository>(
  (Ref ref) => TagRepository(ref.watch(databaseProvider)),
);

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
      (Ref ref) => SettingsRepository(ref.watch(databaseProvider)),
    );

final Provider<SearchRepository> searchRepositoryProvider =
    Provider<SearchRepository>(
      (Ref ref) => SearchRepository(
        ref.watch(databaseProvider),
        ref.watch(linkRepositoryProvider),
      ),
    );

/// Settings are held in memory and written through, so reading the theme is
/// synchronous and a change repaints exactly the widgets that selected on it.
class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => initial;

  /// Seeded in `main` from the one read done during bootstrap.
  static AppSettings initial = const AppSettings();

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  Future<void> _put(String key, String value, AppSettings next) async {
    state = next;
    await _repo.put(key, value);
  }

  Future<void> setFamily(String id) =>
      _put(SettingsRepository.kFamily, id, state.copyWith(familyId: id));

  Future<void> setThemeMode(ThemeModeSetting mode) => _put(
    SettingsRepository.kMode,
    mode.name,
    state.copyWith(themeMode: mode.value),
  );

  Future<void> setAmoled({required bool value}) => _put(
    SettingsRepository.kAmoled,
    '$value',
    state.copyWith(amoled: value),
  );

  Future<void> setDynamicColor({required bool value}) => _put(
    SettingsRepository.kDynamic,
    '$value',
    state.copyWith(dynamicColor: value),
  );

  Future<void> setBlur({required bool value}) =>
      _put(SettingsRepository.kBlur, '$value', state.copyWith(blur: value));

  Future<void> setViewMode(LinkViewMode mode) => _put(
    SettingsRepository.kViewMode,
    mode.name,
    state.copyWith(viewMode: mode),
  );

  Future<void> setLandingTab(LandingTab tab) => _put(
    SettingsRepository.kLanding,
    tab.name,
    state.copyWith(landingTab: tab),
  );

  Future<void> setSort(LinkSort sort) =>
      _put(SettingsRepository.kSort, sort.name, state.copyWith(sort: sort));

  Future<void> setOnboarded({required bool value}) => _put(
    SettingsRepository.kOnboarded,
    '$value',
    state.copyWith(onboarded: value),
  );

  Future<void> setDevTools({required bool value}) => _put(
    SettingsRepository.kDevTools,
    '$value',
    state.copyWith(devTools: value),
  );
}

/// `ThemeMode` with a stable name to persist.
enum ThemeModeSetting {
  light,
  dark,
  system;

  ThemeMode get value => switch (this) {
    ThemeModeSetting.light => ThemeMode.light,
    ThemeModeSetting.dark => ThemeMode.dark,
    ThemeModeSetting.system => ThemeMode.system,
  };

  static ThemeModeSetting from(ThemeMode mode) => switch (mode) {
    ThemeMode.light => ThemeModeSetting.light,
    ThemeMode.dark => ThemeModeSetting.dark,
    ThemeMode.system => ThemeModeSetting.system,
  };
}

final NotifierProvider<SettingsController, AppSettings> settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
