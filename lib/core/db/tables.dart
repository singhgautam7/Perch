import 'package:drift/drift.dart';

/// Arbitrary nesting via an adjacency list: `parentId == null` is the root.
@DataClassName('Folder')
class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();

  /// Null → this folder sits at the root.
  IntColumn get parentId =>
      integer().nullable().references(Folders, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();

  /// Board 3f — an index into `PerchColors.tagHues`, or null for the theme
  /// accent. Stored as an index rather than an ARGB value so a folder stays
  /// legible when the theme changes.
  IntColumn get color => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// How the last metadata fetch for a link ended.
enum FetchStatus {
  /// Never attempted — a share-sheet save starts here.
  pending,

  /// In flight.
  fetching,

  /// Metadata cached and usable.
  ok,

  /// Fetched fine, but the page offers no preview image.
  noPreview,

  /// The page could not be read. Never blocks the save.
  failed,
}

@DataClassName('Link')
class Links extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get url => text()();

  /// User-set, or the suggested title accepted at save time.
  TextColumn get title => text().withDefault(const Constant(''))();

  /// The note, stored as raw markdown.
  TextColumn get note => text().withDefault(const Constant(''))();

  /// Null → Unsorted (the root).
  IntColumn get folderId =>
      integer().nullable().references(Folders, #id, onDelete: KeyAction.setNull)();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get openedAt => dateTime().nullable()();
  IntColumn get openCount => integer().withDefault(const Constant(0))();

  /// Board 3f — pinned links gather into their own section above the count row.
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  /// Manual ordering. Unused by the current sorts, but written on every save so
  /// a future drag-to-reorder has a stable field to work with.
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();

  // Cached metadata — so "Show metadata" works offline and a refetch is rare.
  TextColumn get siteName => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get faviconUrl => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime().nullable()();
  IntColumn get fetchStatus =>
      intEnum<FetchStatus>().withDefault(const Constant(0))();
}

@DataClassName('Tag')
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();

  /// An index into `PerchColors.tagHues`; null takes the theme accent.
  IntColumn get color => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => <Set<Column<Object>>>[
    <Column<Object>>{name},
  ];
}

@DataClassName('LinkTag')
class LinkTags extends Table {
  IntColumn get linkId =>
      integer().references(Links, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{linkId, tagId};
}

/// Key/value app settings. Kept in the DB rather than SharedPreferences so an
/// export is one file and covers everything.
@DataClassName('Setting')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}
