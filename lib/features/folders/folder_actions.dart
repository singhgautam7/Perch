import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'folder_picker.dart';

/// Long-press on a folder: rename, move, delete.
Future<void> showFolderActions(
  BuildContext context,
  WidgetRef ref,
  Folder folder,
) {
  return showAppBottomSheet<void>(
    context: context,
    title: folder.name,
    builder: (BuildContext sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Action(
          icon: Icons.edit_outlined,
          label: 'Rename',
          onTap: () async {
            Navigator.of(sheetContext).pop();
            await _rename(context, ref, folder);
          },
        ),
        _Action(
          icon: Icons.drive_file_move_outline,
          label: 'Move',
          onTap: () async {
            Navigator.of(sheetContext).pop();
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
              AppSnackbar.error(
                context,
                'A folder cannot be moved inside itself',
              );
            }
          },
        ),
        _Action(
          icon: Icons.delete_outline_rounded,
          label: 'Delete',
          danger: true,
          onTap: () async {
            Navigator.of(sheetContext).pop();
            await _confirmDelete(context, ref, folder);
          },
        ),
      ],
    ),
  );
}

Future<void> _rename(
  BuildContext context,
  WidgetRef ref,
  Folder folder,
) async {
  final TextEditingController controller = TextEditingController(
    text: folder.name,
  );
  final String? name = await showAppBottomSheet<String>(
    context: context,
    title: 'Rename folder',
    builder: (BuildContext sheetContext) => TextField(
      controller: controller,
      autofocus: true,
      textInputAction: TextInputAction.done,
      onSubmitted: (String v) => Navigator.of(sheetContext).pop(v),
      style: PerchType.body.copyWith(color: sheetContext.colors.onSurface),
      decoration: const InputDecoration(hintText: 'Folder name'),
    ),
  );
  controller.dispose();

  final String trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty || trimmed == folder.name) return;
  await ref.read(folderRepositoryProvider).rename(folder.id, trimmed);
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  Folder folder,
) async {
  final bool? confirmed = await showAppBottomSheet<bool>(
    context: context,
    title: 'Delete ${folder.name}?',
    builder: (BuildContext sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'The folder and anything nested inside it go. Links stay — they move '
          'to Unsorted.',
          style: PerchType.body.copyWith(
            color: sheetContext.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Space.xl),
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
  if (context.mounted) {
    AppSnackbar.info(context, 'Deleted ${folder.name}');
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final Color fg = danger ? c.danger : c.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.thumbR,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          spacing: 13,
          children: <Widget>[
            Icon(icon, size: 20, color: fg),
            Text(label, style: PerchType.titleMedium.copyWith(color: fg)),
          ],
        ),
      ),
    );
  }
}
