import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/tag_repository.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'app_bottom_sheet.dart';
import 'app_button.dart';
import 'labelled_field.dart';
import 'tag_chip.dart';

/// Board 3c — the one tag picker. Add/Edit, Link detail and the bulk Tag action
/// all open this; it always shows what already exists first, because the old
/// "Add tags" field never revealed the vocabulary you had built.
///
/// Returns the chosen tag ids, or null if the sheet was dismissed.
Future<List<int>?> showTagPicker(
  BuildContext context, {
  List<int> selected = const <int>[],
}) {
  return showAppBottomSheet<List<int>>(
    context: context,
    title: 'Tags',
    builder: (BuildContext context) => _TagPicker(initial: selected),
  );
}

class _TagPicker extends ConsumerStatefulWidget {
  const _TagPicker({required this.initial});

  final List<int> initial;

  @override
  ConsumerState<_TagPicker> createState() => _TagPickerState();
}

class _TagPickerState extends ConsumerState<_TagPicker> {
  final TextEditingController _query = TextEditingController();
  late final List<int> _selected = <int>[...widget.initial];
  int? _newColor = 0;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _create(String name) async {
    final int id = await ref
        .read(tagRepositoryProvider)
        .create(name, colorIndex: _newColor);
    if (!mounted) return;
    setState(() {
      _selected.add(id);
      _query.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final String query = _query.text.trim();
    final List<TagWithCount> all =
        ref.watch(allTagsProvider).valueOrNull ?? const <TagWithCount>[];

    final List<TagWithCount> selectedTags = all
        .where((TagWithCount t) => _selected.contains(t.tag.id))
        .toList(growable: false);
    final List<TagWithCount> rest = all
        .where(
          (TagWithCount t) =>
              !_selected.contains(t.tag.id) &&
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
        LabelledField(
          label: 'Find or create',
          focused: true,
          child: PlainTextField(
            controller: _query,
            autofocus: true,
            hint: 'Type a tag name',
            onChanged: (_) => setState(() {}),
            onSubmitted: (String v) {
              if (canCreate) _create(v.trim());
            },
          ),
        ),
        if (canCreate) ...<Widget>[
          const SizedBox(height: Space.md),
          _CreateRow(
            name: query,
            color: _newColor,
            onColor: (int? i) => setState(() => _newColor = i),
            onCreate: () => _create(query),
          ),
        ],
        if (all.isEmpty && !canCreate)
          const _EmptyTags()
        else ...<Widget>[
          if (selectedTags.isNotEmpty) ...<Widget>[
            const _GroupLabel('Selected'),
            Wrap(
              spacing: 7,
              runSpacing: 2,
              children: <Widget>[
                for (final TagWithCount t in selectedTags)
                  TagChip(
                    label: t.tag.name,
                    selected: true,
                    color: c.tagColor(t.tag.color),
                    onRemove: () =>
                        setState(() => _selected.remove(t.tag.id)),
                  ),
              ],
            ),
          ],
          if (rest.isNotEmpty) ...<Widget>[
            _GroupLabel('All tags · ${all.length}'),
            // A long tag list scrolls rather than pushing the field off screen.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 210),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 7,
                  runSpacing: 2,
                  children: <Widget>[
                    for (final TagWithCount t in rest)
                      TagChip(
                        label: t.tag.name,
                        dot: true,
                        color: c.tagColor(t.tag.color),
                        onTap: () => setState(() => _selected.add(t.tag.id)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: Space.lg),
        AppButton(
          label: 'Done',
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(_selected),
        ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, Space.lg, 0, 6),
    child: Text(
      text.toUpperCase(),
      style: PerchType.sectionHeader.copyWith(
        fontSize: 10,
        letterSpacing: 0.9,
        color: context.colors.onSurfaceVariant,
      ),
    ),
  );
}

/// The inline create row: the name being typed, plus the colour it will take.
class _CreateRow extends StatelessWidget {
  const _CreateRow({
    required this.name,
    required this.color,
    required this.onColor,
    required this.onCreate,
  });

  final String name;
  final int? color;
  final ValueChanged<int?> onColor;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 11),
      decoration: BoxDecoration(
        color: c.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            button: true,
            label: 'Create tag $name',
            child: InkWell(
              onTap: onCreate,
              child: Row(
                spacing: 11,
                children: <Widget>[
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: c.tagColor(color),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: c.onPrimary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Create “$name”',
                      style: PerchType.label
                          .copyWith(fontSize: 13, color: c.onPrimaryContainer)
                          .weight(600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          ColorSwatchRow(
            selected: color,
            onChanged: onColor,
            size: 20,
            allowNone: false,
          ),
        ],
      ),
    );
  }
}

class _EmptyTags extends StatelessWidget {
  const _EmptyTags();

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 34, 30, 10),
      child: Column(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: c.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.sell_outlined, size: 22, color: c.iconMuted),
          ),
          const SizedBox(height: 14),
          Text(
            'No tags yet',
            style: PerchType.titleMedium.copyWith(fontSize: 14, color: c.onSurface),
          ),
          const SizedBox(height: 5),
          Text(
            'Type a name above to create your first one. Tags are shared '
            'across every link.',
            textAlign: TextAlign.center,
            style: PerchType.bodySmall.copyWith(
              fontSize: 12.5,
              height: 1.5,
              color: c.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
