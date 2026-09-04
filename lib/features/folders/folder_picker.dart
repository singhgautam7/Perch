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
import '../../shared/widgets/folder_card.dart';
import 'folder_providers.dart';
import 'new_folder_row.dart';

/// The result of picking a destination. `null` folderId means Unsorted.
typedef FolderChoice = ({int? folderId, String name});

/// Board 3b — a sub-sheet over whatever raised it: the same nested tree and the
/// same New folder row as the Folders tab, then one confirming button.
///
/// [excludeSubtreeOf] removes a folder and its descendants from the list, which
/// is what stops a folder being moved into itself.
Future<FolderChoice?> showFolderPicker(
  BuildContext context, {
  int? excludeSubtreeOf,
  String title = 'Choose folder',
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
  int? _selected;

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

  /// Parents before children, each with the depth its indent needs.
  List<({Folder folder, int depth})> _tree(List<Folder> folders) {
    final Map<int?, List<Folder>> byParent = <int?, List<Folder>>{};
    for (final Folder f in folders) {
      if (_excluded.contains(f.id)) continue;
      byParent.putIfAbsent(f.parentId, () => <Folder>[]).add(f);
    }
    for (final List<Folder> siblings in byParent.values) {
      siblings.sort(
        (Folder a, Folder b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }

    final List<({Folder folder, int depth})> out =
        <({Folder folder, int depth})>[];
    void walk(int? parent, int depth) {
      for (final Folder f in byParent[parent] ?? const <Folder>[]) {
        out.add((folder: f, depth: depth));
        walk(f.id, depth + 1);
      }
    }

    walk(null, 1);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final List<Folder> folders =
        ref.watch(allFoldersProvider).valueOrNull ?? const <Folder>[];
    final List<({Folder folder, int depth})> tree = _tree(folders);
    final String name = _selected == null
        ? 'Home'
        : folders
                  .where((Folder f) => f.id == _selected)
                  .firstOrNull
                  ?.name ??
              'Home';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        NewFolderRow(
          label: 'New folder here',
          onCreate: (String value) async {
            final int id = await ref
                .read(folderRepositoryProvider)
                .create(name: value, parentId: _selected);
            if (mounted) setState(() => _selected = id);
          },
        ),
        const SizedBox(height: Space.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Row(
                  label: 'Home',
                  depth: 0,
                  selected: _selected == null,
                  onTap: () => setState(() => _selected = null),
                ),
                for (final ({Folder folder, int depth}) node in tree)
                  _Row(
                    label: node.folder.name,
                    depth: node.depth,
                    selected: _selected == node.folder.id,
                    onTap: () => setState(() => _selected = node.folder.id),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        AppButton(
          label: 'Choose $name',
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop((
            folderId: _selected,
            name: _selected == null ? 'Unsorted' : name,
          )),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.depth,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int depth;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final Color fg = selected ? c.onPrimaryContainer : c.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.fromLTRB(12.0 + depth * 20, 11, 12, 11),
          decoration: BoxDecoration(
            color: selected ? c.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            spacing: Space.row,
            children: <Widget>[
              FolderGlyph(color: fg, width: 19, filled: false),
              Expanded(
                child: Text(
                  label,
                  style: PerchType.label
                      .copyWith(
                        fontSize: 13.5,
                        color: selected ? c.onPrimaryContainer : c.onSurface,
                      )
                      .weight(selected ? 600 : 500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 15, color: c.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}
