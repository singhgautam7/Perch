import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/tag_repository.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/tag_chip.dart';

/// The tag row: the chosen tags, then `＋ Add tag`.
///
/// Adding opens a searchable sheet of existing tags — typing a name that does
/// not exist yet offers to create it, so a tag is never a dead end.
class TagField extends ConsumerWidget {
  const TagField({required this.tags, required this.onChanged, super.key});

  final List<String> tags;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (final String tag in tags)
          TagChip(
            label: tag,
            style: ChipStyle.active,
            onRemove: () => onChanged(
              tags.where((String t) => t != tag).toList(growable: false),
            ),
          ),
        TagChip(
          label: 'Add tag',
          style: ChipStyle.add,
          onTap: () async {
            final String? picked = await showTagPicker(context, exclude: tags);
            if (picked != null && !tags.contains(picked)) {
              onChanged(<String>[...tags, picked]);
            }
          },
        ),
      ],
    );
  }
}

/// Pick an existing tag, or create one by typing a new name.
Future<String?> showTagPicker(
  BuildContext context, {
  List<String> exclude = const <String>[],
}) {
  return showAppBottomSheet<String>(
    context: context,
    title: 'Tags',
    builder: (BuildContext context) => _TagPicker(exclude: exclude),
  );
}

class _TagPicker extends ConsumerStatefulWidget {
  const _TagPicker({required this.exclude});

  final List<String> exclude;

  @override
  ConsumerState<_TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends ConsumerState<_TagPicker> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final String query = _query.text.trim();
    final List<TagWithCount> all =
        ref.watch(allTagsProvider).valueOrNull ?? const <TagWithCount>[];
    final List<TagWithCount> matches = all
        .where(
          (TagWithCount t) =>
              !widget.exclude.contains(t.tag.name) &&
              t.tag.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList(growable: false);
    final bool canCreate =
        query.isNotEmpty &&
        !all.any(
          (TagWithCount t) => t.tag.name.toLowerCase() == query.toLowerCase(),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.surfaceContainerHigh,
            borderRadius: Radii.fullR,
          ),
          child: TextField(
            controller: _query,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: (String v) {
              if (v.trim().isNotEmpty) Navigator.of(context).pop(v.trim());
            },
            style: PerchType.body.copyWith(color: c.onSurface),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: 'Find or create a tag',
              hintStyle: PerchType.body.copyWith(color: c.onSurfaceMuted),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        if (canCreate)
          TagChip(
            label: 'Create "$query"',
            style: ChipStyle.selected,
            onTap: () => Navigator.of(context).pop(query),
          ),
        if (canCreate) const SizedBox(height: Space.md),
        // Three rows of chips, then the rest scroll — a huge tag list must not
        // push the field off screen.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final TagWithCount t in matches)
                  TagChip(
                    label: '${t.tag.name} · ${t.linkCount}',
                    onTap: () => Navigator.of(context).pop(t.tag.name),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final StreamProvider<List<TagWithCount>> allTagsProvider =
    StreamProvider<List<TagWithCount>>((Ref ref) {
      return ref.watch(tagRepositoryProvider).watchAll();
    });
