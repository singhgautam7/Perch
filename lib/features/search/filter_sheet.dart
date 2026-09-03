import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/search_repository.dart';
import '../../core/db/tag_repository.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/tag_chip.dart';
import '../add_link/tag_field.dart';
import '../folders/folder_picker.dart';
import '../folders/folder_providers.dart';
import 'search_controller.dart';

/// Board 1g — six groups, and a live count on Apply so the effect of a filter
/// is known before it is applied.
Future<void> showFilterSheet(BuildContext context, WidgetRef ref) {
  return showAppBottomSheet<void>(
    context: context,
    title: 'Filter',
    builder: (BuildContext sheetContext) => const _FilterSheet(),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late SearchFilters _draft = ref.read(searchProvider).filters;
  bool _allTagsShown = false;
  int? _count;

  @override
  void initState() {
    super.initState();
    _recount();
  }

  /// The count is for the draft, not the applied filters — that is the point.
  Future<void> _recount() async {
    final List<int>? scope = _draft.folderId == null
        ? null
        : (_draft.includeSubfolders
              ? await ref
                    .read(folderRepositoryProvider)
                    .descendantIds(_draft.folderId!)
              : <int>[_draft.folderId!]);
    final int count = await ref
        .read(searchRepositoryProvider)
        .count(
          query: ref.read(searchProvider).query,
          filters: _draft,
          folderScope: scope,
        );
    if (mounted) setState(() => _count = count);
  }

  void _update(SearchFilters next) {
    setState(() => _draft = next);
    _recount();
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final Map<int, String> paths = ref.watch(folderPathsProvider);
    final List<TagWithCount> tags =
        ref.watch(allTagsProvider).valueOrNull ?? const <TagWithCount>[];
    final List<TagWithCount> shownTags = _allTagsShown
        ? tags
        : tags.take(6).toList(growable: false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Group(
          label: 'Folder',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                spacing: Space.sm,
                children: <Widget>[
                  Expanded(
                    child: AppButton(
                      label: _draft.folderId == null
                          ? 'Any folder'
                          : paths[_draft.folderId!] ?? 'Folder',
                      type: AppButtonType.secondary,
                      compact: true,
                      onPressed: () async {
                        final FolderChoice? choice = await showFolderPicker(
                          context,
                          title: 'Filter by folder',
                        );
                        if (choice != null) {
                          _update(
                            choice.folderId == null
                                ? _draft.copyWith(clearFolder: true)
                                : _draft.copyWith(folderId: choice.folderId),
                          );
                        }
                      },
                    ),
                  ),
                  if (_draft.folderId != null)
                    AppButton(
                      label: 'Clear',
                      type: AppButtonType.muted,
                      compact: true,
                      onPressed: () =>
                          _update(_draft.copyWith(clearFolder: true)),
                    ),
                ],
              ),
              if (_draft.folderId != null)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _draft.includeSubfolders,
                  onChanged: (bool v) =>
                      _update(_draft.copyWith(includeSubfolders: v)),
                  title: Text(
                    'Include subfolders',
                    style: PerchType.body.copyWith(color: c.onSurface),
                  ),
                ),
            ],
          ),
        ),
        _Group(
          label: 'Tags',
          trailing: _MatchToggle(
            match: _draft.tagMatch,
            onChanged: (TagMatch m) => _update(_draft.copyWith(tagMatch: m)),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final TagWithCount t in shownTags)
                TagChip(
                  label: t.tag.name,
                  style: _draft.tagIds.contains(t.tag.id)
                      ? ChipStyle.selected
                      : ChipStyle.plain,
                  onTap: () {
                    final Set<int> next = <int>{..._draft.tagIds};
                    if (!next.remove(t.tag.id)) next.add(t.tag.id);
                    _update(_draft.copyWith(tagIds: next));
                  },
                ),
              if (tags.length > shownTags.length)
                TagChip(
                  label: '+${tags.length - shownTags.length} more',
                  onTap: () => setState(() => _allTagsShown = true),
                ),
              if (tags.isEmpty)
                Text(
                  'No tags yet.',
                  style: PerchType.bodySmall.copyWith(color: c.onSurfaceMuted),
                ),
            ],
          ),
        ),
        _Group(
          label: 'Has note',
          child: _YesAny(
            value: _draft.hasNote,
            onChanged: (bool v) => _update(_draft.copyWith(hasNote: v)),
          ),
        ),
        _Group(
          label: 'Has preview',
          child: _YesAny(
            value: _draft.hasImage,
            onChanged: (bool v) => _update(_draft.copyWith(hasImage: v)),
          ),
        ),
        _Group(
          label: 'Domain',
          child: _DomainPicker(
            selected: _draft.domain,
            onChanged: (String? d) => _update(
              d == null
                  ? _draft.copyWith(clearDomain: true)
                  : _draft.copyWith(domain: d),
            ),
          ),
        ),
        _Group(
          label: 'Date saved',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final DatePreset preset in DatePreset.values)
                if (preset != DatePreset.custom)
                  TagChip(
                    label: preset.label,
                    style: _draft.datePreset == preset
                        ? ChipStyle.selected
                        : ChipStyle.plain,
                    onTap: () => _update(_draft.copyWith(datePreset: preset)),
                  ),
              TagChip(
                label: _draft.datePreset == DatePreset.custom &&
                        _draft.from != null
                    ? '${longDate(_draft.from!)} →'
                    : 'Custom range',
                style: _draft.datePreset == DatePreset.custom
                    ? ChipStyle.selected
                    : ChipStyle.plain,
                onTap: () async {
                  final DateTimeRange? range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (range == null) return;
                  _update(
                    _draft.copyWith(
                      datePreset: DatePreset.custom,
                      from: range.start,
                      to: range.end,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        Row(
          spacing: Space.sm,
          children: <Widget>[
            AppButton(
              label: 'Reset',
              type: AppButtonType.outlined,
              onPressed: () => _update(SearchFilters(sort: _draft.sort)),
            ),
            Expanded(
              child: AppButton(
                label: _count == null
                    ? 'Apply'
                    : 'Apply · ${plural(_count!, 'link')}',
                fullWidth: true,
                onPressed: () {
                  ref.read(searchProvider.notifier).setFilters(_draft);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.child, this.trailing});

  final String label;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: PerchType.sectionHeader.copyWith(
                    fontSize: 10.5,
                    color: c.onSurfaceVariant,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: Space.row),
          child,
        ],
      ),
    );
  }
}

/// AND / OR for the tag group.
class _MatchToggle extends StatelessWidget {
  const _MatchToggle({required this.match, required this.onChanged});

  final TagMatch match;
  final ValueChanged<TagMatch> onChanged;

  @override
  Widget build(BuildContext context) {
    return TagChip(
      label: match == TagMatch.all ? 'AND' : 'OR',
      style: ChipStyle.active,
      onTap: () =>
          onChanged(match == TagMatch.all ? TagMatch.any : TagMatch.all),
    );
  }
}

class _YesAny extends StatelessWidget {
  const _YesAny({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: 6,
      children: <Widget>[
        TagChip(
          label: 'Yes',
          style: value ? ChipStyle.selected : ChipStyle.plain,
          onTap: () => onChanged(true),
        ),
        TagChip(
          label: 'Any',
          style: value ? ChipStyle.plain : ChipStyle.selected,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _DomainPicker extends ConsumerWidget {
  const _DomainPicker({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> domains =
        ref.watch(searchDomainsProvider).valueOrNull ?? const <String>[];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        TagChip(
          label: 'Any domain',
          style: selected == null ? ChipStyle.selected : ChipStyle.plain,
          onTap: () => onChanged(null),
        ),
        for (final String domain in domains.take(8))
          TagChip(
            label: domain,
            style: selected == domain ? ChipStyle.selected : ChipStyle.plain,
            onTap: () => onChanged(domain),
          ),
      ],
    );
  }
}

/// Distinct hosts across saved links, most-used first.
final FutureProvider<List<String>> searchDomainsProvider =
    FutureProvider<List<String>>((Ref ref) {
      return ref.watch(searchRepositoryProvider).domains();
    });
