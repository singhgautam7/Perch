import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_menu.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/labelled_field.dart';
import 'folder_picker.dart';

/// Board 3i — the folder menu: rename, recolour, move, delete.
enum FolderAction { rename, color, move, stats, delete }

Future<void> showFolderMenu(
  BuildContext context,
  WidgetRef ref,
  Folder folder, {
  Offset? at,
  BuildContext? anchorContext,
}) async {
  final FolderAction? action = await showAppMenu<FolderAction>(
    context: context,
    globalPosition: at,
    anchorContext: anchorContext,
    minWidth: 214,
    entries: const <AppMenuEntry<FolderAction>>[
      AppMenuEntry<FolderAction>(value: FolderAction.rename, label: 'Rename'),
      AppMenuEntry<FolderAction>(
        value: FolderAction.color,
        label: 'Change colour',
      ),
      AppMenuEntry<FolderAction>(value: FolderAction.move, label: 'Move'),
      AppMenuEntry<FolderAction>(value: FolderAction.stats, label: 'Stats'),
      AppMenuEntry<FolderAction>.divider(),
      AppMenuEntry<FolderAction>(
        value: FolderAction.delete,
        label: 'Delete folder',
        danger: true,
      ),
    ],
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case FolderAction.rename:
      await _rename(context, ref, folder);
    case FolderAction.color:
      await _recolor(context, ref, folder);
    case FolderAction.move:
      await _move(context, ref, folder);
    case FolderAction.stats:
      await context.push(Routes.stats);
    case FolderAction.delete:
      await _confirmDelete(context, ref, folder);
  }
}

Future<void> _rename(
  BuildContext context,
  WidgetRef ref,
  Folder folder,
) async {
  final String? name = await showAppBottomSheet<String>(
    context: context,
    title: 'Rename folder',
    builder: (BuildContext sheetContext) =>
        _RenameFolderSheet(initialName: folder.name),
  );

  final String trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty || trimmed == folder.name) return;
  await ref.read(folderRepositoryProvider).rename(folder.id, trimmed);
}

class _RenameFolderSheet extends StatefulWidget {
  const _RenameFolderSheet({required this.initialName});

  final String initialName;

  @override
  State<_RenameFolderSheet> createState() => _RenameFolderSheetState();
}

class _RenameFolderSheetState extends State<_RenameFolderSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LabelledField(
          label: 'Name',
          focused: true,
          child: PlainTextField(
            controller: _controller,
            autofocus: true,
            hint: 'Folder name',
            onSubmitted: (String v) => Navigator.of(context).pop(v.trim()),
          ),
        ),
        const SizedBox(height: Space.lg),
        AppButton(
          label: 'Save',
          fullWidth: true,
          onPressed: () =>
              Navigator.of(context).pop(_controller.text.trim()),
        ),
      ],
    );
  }
}

Future<void> _recolor(
  BuildContext context,
  WidgetRef ref,
  Folder folder,
) async {
  await showAppBottomSheet<void>(
    context: context,
    title: 'Folder colour',
    description: 'Perch tints the header, the nav and the ＋ button while you '
        'are inside this folder.',
    builder: (BuildContext sheetContext) => StatefulBuilder(
      builder: (BuildContext context, void Function(void Function()) setState) {
        return Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: ColorSwatchRow(
            selected: folder.color,
            onChanged: (int? index) {
              ref.read(folderRepositoryProvider).setColor(folder.id, index);
              Navigator.of(sheetContext).pop();
            },
            size: 34,
          ),
        );
      },
    ),
  );
}

Future<void> _move(BuildContext context, WidgetRef ref, Folder folder) async {
  final FolderChoice? choice = await showFolderPicker(
    context,
    excludeSubtreeOf: folder.id,
  );
  if (choice == null || !context.mounted) return;
  final bool ok = await ref
      .read(folderRepositoryProvider)
      .move(folder.id, choice.folderId);
  if (!context.mounted) return;
  if (ok) {
    AppSnackbar.success(context, 'Moved to ${choice.name}');
  } else {
    AppSnackbar.error(context, 'A folder cannot be moved inside itself');
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  Folder folder,
) async {
  final bool? confirmed = await showAppBottomSheet<bool>(
    context: context,
    title: 'Delete ${folder.name}?',
    description:
        'The folder and anything nested inside it go. Links stay — they move '
        'to Unsorted.',
    builder: (BuildContext sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppButton(
          label: 'Delete folder',
          type: AppButtonType.danger,
          fullWidth: true,
          onPressed: () => Navigator.of(sheetContext).pop(true),
        ),
        const SizedBox(height: Space.sm),
        AppButton(
          label: 'Keep it',
          type: AppButtonType.outlined,
          fullWidth: true,
          onPressed: () => Navigator.of(sheetContext).pop(false),
        ),
      ],
    ),
  );

  if (confirmed != true) return;
  await ref.read(folderRepositoryProvider).delete(folder.id);
  if (context.mounted) AppSnackbar.info(context, 'Deleted ${folder.name}');
}
