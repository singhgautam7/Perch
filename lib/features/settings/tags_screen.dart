import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/tag_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/labelled_field.dart';
import '../../shared/widgets/section_header.dart';
import '../folders/new_folder_row.dart';
import '../links/link_feed.dart';

/// How the list is ordered. Two choices, so the mono control cycles rather
/// than opening a sheet.
enum _TagSort {
  name,
  count;

  String get short => this == _TagSort.name ? 'A–Z' : 'Most used';
}

/// Board 3c — colour swatch, name, link count. Tapping a tag opens its filtered
/// links; holding one opens the edit sheet.
class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  _TagSort _sort = _TagSort.name;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final List<TagWithCount> all =
        ref.watch(allTagsProvider).valueOrNull ?? const <TagWithCount>[];
    final List<TagWithCount> tags = <TagWithCount>[...all]
      ..sort(
        (TagWithCount a, TagWithCount b) => _sort == _TagSort.name
            ? a.tag.name.toLowerCase().compareTo(b.tag.name.toLowerCase())
            : b.linkCount.compareTo(a.linkCount),
      );
    final int totalLinks = ref.watch(linkCountProvider).valueOrNull ?? 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            AppHeader(title: 'Tags', onBack: () => Navigator.of(context).pop()),
            SectionHeader(
              label:
                  '${plural(all.length, 'tag')} · ${plural(totalLinks, 'link')}',
              trailing: Semantics(
                button: true,
                label: 'Sort: ${_sort.short}',
                child: InkWell(
                  onTap: () => setState(
                    () => _sort = _sort == _TagSort.name
                        ? _TagSort.count
                        : _TagSort.name,
                  ),
                  borderRadius: Radii.chipR,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: Space.sm,
                    ),
                    child: Text(
                      '${_sort.short} ↓',
                      style: PerchType.monoLabel.copyWith(
                        fontSize: 11.5,
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.screen,
                  0,
                  Space.screen,
                  Space.xxl,
                ),
                children: <Widget>[
                  NewFolderRow(
                    label: 'Add tag',
                    onCreate: (String name) =>
                        ref.read(tagRepositoryProvider).create(name),
                  ),
                  if (all.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.xxl),
                      child: Text(
                        'No tags yet. Tags are shared across every link.',
                        textAlign: TextAlign.center,
                        style: PerchType.body.copyWith(
                          color: c.onSurfaceMuted,
                        ),
                      ),
                    ),
                  for (final TagWithCount t in tags) ...<Widget>[
                    const SizedBox(height: Space.sm),
                    _TagRow(
                      data: t,
                      onTap: () => context.push(Routes.tagged(t.tag.id)),
                      onEdit: () => showTagEditor(context, ref, t, all),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.data,
    required this.onTap,
    required this.onEdit,
  });

  final TagWithCount data;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Semantics(
      button: true,
      label: '${data.tag.name}, ${plural(data.linkCount, 'link')}',
      child: Material(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onEdit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.outline),
            ),
            child: Row(
              spacing: Space.md,
              children: <Widget>[
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: c.tagColor(data.tag.color),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    data.tag.name,
                    style: PerchType.titleMedium.copyWith(
                      fontSize: 14.5,
                      color: c.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${data.linkCount}',
                  style: PerchType.monoLabel.copyWith(
                    fontSize: 12,
                    color: c.onSurfaceVariant,
                  ),
                ),
                // Edit is an explicit button as well as a hold, because a hold
                // is not discoverable on a row that already opens something.
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: c.onSurfaceMuted,
                  ),
                  tooltip: 'Edit tag',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Board 3c — rename, recolour, merge, delete.
Future<void> showTagEditor(
  BuildContext context,
  WidgetRef ref,
  TagWithCount data,
  List<TagWithCount> all,
) {
  return showAppBottomSheet<void>(
    context: context,
    title: 'Edit tag',
    builder: (BuildContext sheetContext) =>
        _TagEditor(data: data, all: all),
  );
}

class _TagEditor extends ConsumerStatefulWidget {
  const _TagEditor({required this.data, required this.all});

  final TagWithCount data;
  final List<TagWithCount> all;

  @override
  ConsumerState<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends ConsumerState<_TagEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.data.tag.name,
  );
  late int? _color = widget.data.tag.color;

  Tag get _tag => widget.data.tag;
  TagRepository get _repo => ref.read(tagRepositoryProvider);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _name.text.trim();
    if (name.isNotEmpty && name != _tag.name) {
      await _repo.rename(_tag.id, name);
    }
    if (_color != _tag.color) await _repo.setColor(_tag.id, _color);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _merge() async {
    final List<TagWithCount> others = widget.all
        .where((TagWithCount t) => t.tag.id != _tag.id)
        .toList(growable: false);
    if (others.isEmpty) {
      AppSnackbar.info(context, 'There is no other tag to merge into');
      return;
    }
    final int? target = await showOptionSheet<int>(
      context: context,
      title: 'Merge into',
      description:
          'Every link on “${_tag.name}” moves to the tag you pick, then '
          '“${_tag.name}” is deleted.',
      selected: -1,
      options: <SheetOption<int>>[
        for (final TagWithCount t in others)
          SheetOption<int>(
            value: t.tag.id,
            label: t.tag.name,
            description: plural(t.linkCount, 'link'),
          ),
      ],
    );
    if (target == null) return;
    await _repo.merge(_tag.id, target);
    if (mounted) {
      Navigator.of(context).pop();
      AppSnackbar.success(context, 'Merged into ${_nameOf(target)}');
    }
  }

  String _nameOf(int id) => widget.all
      .firstWhere((TagWithCount t) => t.tag.id == id)
      .tag
      .name;

  Future<void> _delete() async {
    await _repo.delete(_tag.id);
    if (mounted) {
      Navigator.of(context).pop();
      AppSnackbar.info(context, 'Deleted ${_tag.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LabelledField(
          label: 'Name',
          focused: true,
          child: PlainTextField(controller: _name, autofocus: true),
        ),
        const SizedBox(height: Space.md),
        LabelledField(
          label: 'Colour',
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: ColorSwatchRow(
              selected: _color,
              onChanged: (int? i) => setState(() => _color = i),
            ),
          ),
        ),
        const SizedBox(height: Space.md),
        _SheetRow(
          label: 'Merge into another tag',
          value:
              'Moves all ${widget.data.linkCount} links, then deletes '
              '“${_tag.name}”',
          onTap: _merge,
        ),
        const SizedBox(height: Space.sm),
        Semantics(
          button: true,
          label: 'Delete tag',
          child: InkWell(
            onTap: _delete,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: c.dangerContainer,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.danger.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Delete tag',
                      style: PerchType.titleMedium.copyWith(
                        fontSize: 14,
                        color: c.onDangerContainer,
                      ),
                    ),
                  ),
                  Text(
                    'links are kept',
                    style: PerchType.bodySmall.copyWith(
                      color: c.onDangerContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        AppButton(label: 'Save', fullWidth: true, onPressed: _save),
      ],
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.outline),
          ),
          child: Row(
            spacing: Space.md,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: PerchType.titleMedium.copyWith(
                        fontSize: 14,
                        color: c.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: PerchType.bodySmall.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: c.onSurfaceMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
