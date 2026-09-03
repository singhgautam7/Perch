import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/folder_card.dart';
import 'folder_providers.dart';
import 'new_folder_row.dart';

/// The result of picking a destination. `null` folderId means Unsorted.
typedef FolderChoice = ({int? folderId, String name});

/// Choose a folder, with `＋ New folder` inline so a destination that does not
/// exist yet is one step away rather than a detour.
///
/// [excludeSubtreeOf] removes a folder and its descendants from the list, which
/// is what stops a folder being moved into itself.
Future<FolderChoice?> showFolderPicker(
  BuildContext context, {
  int? excludeSubtreeOf,
  String title = 'Move to',
}) {
  return showAppBottomSheet<FolderChoice>(
    context: context,
    title: title,
    builder: (BuildContext context) =>
        _FolderPicker(excludeSubtreeOf: excludeSubtreeOf),
  );
}

class _FolderPicker extends ConsumerStatefulWidget {
  const _FolderPicker({this.excludeSubtreeOf});

  final int? excludeSubtreeOf;

  @override
  ConsumerState<_FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends ConsumerState<_FolderPicker> {
  Set<int> _excluded = const <int>{};

  @override
  void initState() {
    super.initState();
    final int? root = widget.excludeSubtreeOf;
    if (root != null) {
      ref.read(folderRepositoryProvider).descendantIds(root).then((
        List<int> ids,
      ) {
        if (mounted) setState(() => _excluded = ids.toSet());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final List<Folder> folders =
        ref.watch(allFoldersProvider).valueOrNull ?? const <Folder>[];
    final Map<int, String> paths = ref.watch(folderPathsProvider);
    final List<Folder> options = folders
        .where((Folder f) => !_excluded.contains(f.id))
        .toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        NewFolderRow(
          locationName: 'Root',
          onCreate: (String name) async {
            final int id = await ref
                .read(folderRepositoryProvider)
                .create(name: name);
            if (context.mounted) {
              Navigator.of(context).pop((folderId: id, name: name));
            }
          },
        ),
        const SizedBox(height: Space.md),
        _Option(
          label: 'Unsorted',
          sublabel: 'No folder',
          color: c.onSurfaceMuted,
          onTap: () =>
              Navigator.of(context).pop((folderId: null, name: 'Unsorted')),
        ),
        for (final Folder f in options)
          _Option(
            label: f.name,
            sublabel: paths[f.id] ?? f.name,
            color: c.primary,
            onTap: () =>
                Navigator.of(context).pop((folderId: f.id, name: f.name)),
          ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: Radii.thumbR,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          spacing: Space.md,
          children: <Widget>[
            FolderGlyph(color: color, width: 22),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: PerchType.titleMedium.copyWith(color: c.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sublabel != label)
                    Text(
                      sublabel,
                      style: PerchType.monoSmall.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
