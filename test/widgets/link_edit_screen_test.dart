import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perch/core/db/database.dart';
import 'package:perch/core/db/folder_repository.dart';
import 'package:perch/core/db/link_repository.dart';
import 'package:perch/core/db/settings_repository.dart';
import 'package:perch/core/db/tag_repository.dart';
import 'package:perch/core/providers.dart';
import 'package:perch/core/theme/app_theme.dart';
import 'package:perch/core/theme/palette.dart';
import 'package:perch/features/add_link/link_edit_screen.dart';

void main() {
  late PerchDatabase db;
  late FolderRepository folderRepo;
  late LinkRepository linkRepo;
  late TagRepository tagRepo;
  late SettingsRepository settingsRepo;

  setUp(() {
    db = PerchDatabase.forTesting(NativeDatabase.memory());
    folderRepo = FolderRepository(db);
    linkRepo = LinkRepository(db);
    tagRepo = TagRepository(db);
    settingsRepo = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget createSubject({int? initialFolderId}) {
    return ProviderScope(
      overrides: <Override>[
        databaseProvider.overrideWithValue(db),
        folderRepositoryProvider.overrideWithValue(folderRepo),
        linkRepositoryProvider.overrideWithValue(linkRepo),
        tagRepositoryProvider.overrideWithValue(tagRepo),
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.of(ThemeFamily.perch, Tone.light),
        home: LinkEditScreen(initialFolderId: initialFolderId),
      ),
    );
  }

  testWidgets('LinkEditScreen defaults to Unsorted when no initialFolderId', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text('Unsorted'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });

  testWidgets('LinkEditScreen pre-selects folder when initialFolderId is provided', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final int folderId = await folderRepo.create(name: 'Research');

    await tester.pumpWidget(createSubject(initialFolderId: folderId));
    await tester.pumpAndSettle();

    expect(find.text('Research'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });
}
