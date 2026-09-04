import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/link_repository.dart';
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
import '../folders/folder_picker.dart';
import '../folders/folder_providers.dart';
import 'search_controller.dart';

/// Board 3e — a full-height sheet with a sticky header and a sticky footer.
///
/// One rule for every section: mono label, 10dp gap, controls flush left, 18dp
/// between sections. Close discards, Reset clears but leaves the sheet open,
/// Apply carries the result count so you know before you commit.
Future<void> showFilterSheet(BuildContext context, WidgetRef ref) {
  // The draft starts from what is applied, every time the sheet opens.
  ref.invalidate(_draftProvider);
  return showAppBottomSheet<void>(
    context: context,
    title: 'Filter',
    titleSize: 24,
    expand: true,
    headerAction: const FilterResetPill(),
    actions: const FilterFooter(),
    builder: (BuildContext sheetContext) => const _FilterSheet(),
  );
}

/// The sheet body needs to reach the header's Reset and the footer's Apply, so
/// the draft lives in a provider scoped to the sheet's lifetime rather than in
/// three separate `StatefulWidget`s.
final NotifierProvider<_DraftNotifier, SearchFilters> _draftProvider =
    NotifierProvider<_DraftNotifier, SearchFilters>(_DraftNotifier.new);

class _DraftNotifier extends Notifier<SearchFilters> {
  @override
  SearchFilters build() => ref.read(searchProvider).filters;

  void set(SearchFilters next) => state = next;

  void reset() => state = SearchFilters(sort: state.sort);
}

/// The live count for the *draft*, not the applied filters — that is the point.
final FutureProvider<int> _draftCountProvider = FutureProvider<int>((
  Ref ref,
) async {
  final SearchFilters draft = ref.watch(_draftProvider);
  final List<int>? scope = draft.folderId == null
      ? null
      : (draft.includeSubfolders
            ? await ref.read(folderRepositoryProvider).descendantIds(
                draft.folderId!,
              )
            : <int>[draft.folderId!]);
  return ref
      .read(searchRepositoryProvider)
      .count(
        query: ref.read(searchProvider).query,
        filters: draft,
        folderScope: scope,
      );
});

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SearchFilters draft = ref.watch(_draftProvider);
    final Map<int, String> paths = ref.watch(folderPathsProvider);
    final PerchColors c = context.colors;

    void update(SearchFilters next) => ref.read(_draftProvider.notifier).set(next);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Group(
          label: 'Folder',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Row(
                label: draft.folderId == null
                    ? 'Any folder'
                    : paths[draft.folderId!] ?? 'Folder',
                actionLabel: draft.folderId == null ? 'Choose' : 'Change',
                onTap: () async {
                  final FolderChoice? choice = await showFolderPicker(
                    context,
                    title: 'Filter by folder',
                  );
                  if (choice == null) return;
                  update(
                    choice.folderId == null
                        ? draft.copyWith(clearFolder: true)
                        : draft.copyWith(folderId: choice.folderId),
                  );
                },
              ),
              if (draft.folderId != null) ...<Widget>[
                const SizedBox(height: Space.sm),
                _SwitchRow(
                  label: 'Include subfolders',
                  value: draft.includeSubfolders,
                  onChanged: (bool v) =>
                      update(draft.copyWith(includeSubfolders: v)),
                ),
              ],
            ],
          ),
        ),
        _Group(
          label: 'Tags',
          child: _TagGroup(draft: draft, onChanged: update),
        ),
        _Group(
          label: 'Has note',
          child: _Segments<Tri>(
            values: Tri.values,
            selected: draft.hasNote,
            labelOf: (Tri t) => t.label,
            onChanged: (Tri t) => update(draft.copyWith(hasNote: t)),
          ),
        ),
        _Group(
          label: 'Has preview',
          child: _Segments<Tri>(
            values: Tri.values,
            selected: draft.hasPreview,
            labelOf: (Tri t) => t.label,
            onChanged: (Tri t) => update(draft.copyWith(hasPreview: t)),
          ),
        ),
        _Group(
          label: 'Domain',
          child: _DomainGroup(draft: draft, onChanged: update),
        ),
        _Group(
          label: 'Date saved',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: 7,
                runSpacing: 2,
                children: <Widget>[
                  for (final DatePreset p in <DatePreset>[
                    DatePreset.today,
                    DatePreset.thisWeek,
                    DatePreset.thisMonth,
                    DatePreset.anyTime,
                  ])
                    TagChip(
                      label: p.label,
                      selected: draft.datePreset == p,
                      onTap: () => update(
                        draft.copyWith(datePreset: p, clearRange: true),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              _Row(
                label: 'Custom range',
                value:
                    draft.datePreset == DatePreset.custom && draft.from != null
                    ? '${longDate(draft.from!)} – '
                          '${longDate(draft.to ?? DateTime.now())}'
                    : null,
                onTap: () async {
                  final DateTimeRange? range = await showDateRangePicker(
                    context: context,
                    useRootNavigator: true,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (range == null) return;
                  update(
                    draft.copyWith(
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
        _Group(
          label: 'Sort',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final LinkSort sort in LinkSort.values)
                _RadioRow(
                  label: sort.label,
                  selected: draft.sort == sort,
                  onTap: () => update(draft.copyWith(sort: sort)),
                ),
            ],
          ),
        ),
        // The footer is pinned by the sheet; this is the scrolled tail.
        Text(
          'Close discards. Reset clears every section.',
          style: PerchType.bodySmall.copyWith(color: c.onSurfaceMuted),
        ),
        const SizedBox(height: Space.sm),
      ],
    );
  }
}

/// The sticky footer: Reset, then Apply with the count it will produce.
class FilterFooter extends ConsumerWidget {
  const FilterFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? count = ref.watch(_draftCountProvider).valueOrNull;
    return Row(
      spacing: Space.row,
      children: <Widget>[
        AppButton(
          label: 'Reset',
          type: AppButtonType.outlined,
          onPressed: ref.read(_draftProvider.notifier).reset,
        ),
        Expanded(
          child: AppButton(
            label: count == null ? 'Apply' : 'Apply · ${plural(count, 'link')}',
            fullWidth: true,
            onPressed: () {
              ref
                  .read(searchProvider.notifier)
                  .setFilters(ref.read(_draftProvider));
              Navigator.of(context).pop();
            },
          ),
        ),
      ],
    );
  }
}

/// Reset also sits in the header, where the board puts it.
class FilterResetPill extends ConsumerWidget {
  const FilterResetPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(right: Space.sm),
      child: AppButton(
        label: 'Reset',
        type: AppButtonType.secondary,
        compact: true,
        onPressed: ref.read(_draftProvider.notifier).reset,
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: Space.row),
            child: Text(
              label.toUpperCase(),
              style: PerchType.sectionHeader.copyWith(
                fontSize: 10,
                letterSpacing: 0.9,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// The shared row: a name, an optional value under it, an action or a chevron.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.onTap,
    this.value,
    this.actionLabel,
  });

  final String label;
  final String? value;
  final String? actionLabel;
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (value != null) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        value!,
                        style: PerchType.bodySmall.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (actionLabel != null)
                Text(
                  actionLabel!,
                  style: PerchType.label
                      .copyWith(fontSize: 12, color: c.accent)
                      .weight(600),
                )
              else
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

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: PerchType.label.copyWith(
                fontSize: 13.5,
                color: c.onSurface,
              ),
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// The pill-segmented control — AND/OR and Any/Yes/No are the same thing.
class _Segments<T> extends StatelessWidget {
  const _Segments({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.expand = true,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    Widget segment(T value) {
      final bool on = value == selected;
      return Semantics(
        button: true,
        selected: on,
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: Radii.fullR,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: on ? c.primary : Colors.transparent,
              borderRadius: Radii.fullR,
            ),
            child: Text(
              labelOf(value),
              style: PerchType.label
                  .copyWith(
                    fontSize: 12,
                    color: on ? c.onPrimary : c.onSurfaceVariant,
                  )
                  .weight(600),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: Radii.fullR,
        border: Border.all(color: c.outline),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        spacing: 2,
        children: <Widget>[
          for (final T v in values)
            if (expand) Expanded(child: segment(v)) else segment(v),
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.chipR,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            spacing: 11,
            children: <Widget>[
              Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? c.primary : c.outline,
                    width: 1.8,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: c.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              Text(
                label,
                style: PerchType.label
                    .copyWith(fontSize: 13.5, color: c.onSurface)
                    .weight(selected ? 600 : 500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagGroup extends ConsumerWidget {
  const _TagGroup({required this.draft, required this.onChanged});

  final SearchFilters draft;
  final ValueChanged<SearchFilters> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final List<TagWithCount> tags =
        ref.watch(allTagsProvider).valueOrNull ?? const <TagWithCount>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          spacing: Space.row,
          children: <Widget>[
            Text(
              'Match',
              style: PerchType.bodySmall.copyWith(color: c.onSurfaceVariant),
            ),
            _Segments<TagMatch>(
              values: TagMatch.values,
              selected: draft.tagMatch,
              expand: false,
              labelOf: (TagMatch m) => m == TagMatch.all ? 'AND' : 'OR',
              onChanged: (TagMatch m) =>
                  onChanged(draft.copyWith(tagMatch: m)),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        if (tags.isEmpty)
          Text(
            'No tags yet.',
            style: PerchType.bodySmall.copyWith(color: c.onSurfaceMuted),
          )
        else
          Wrap(
            spacing: 7,
            runSpacing: 2,
            children: <Widget>[
              for (final TagWithCount t in tags)
                TagChip(
                  label: t.tag.name,
                  selected: draft.tagIds.contains(t.tag.id),
                  dot: true,
                  color: c.tagColor(t.tag.color),
                  onRemove: draft.tagIds.contains(t.tag.id)
                      ? () => onChanged(
                          draft.copyWith(
                            tagIds: <int>{...draft.tagIds}..remove(t.tag.id),
                          ),
                        )
                      : null,
                  onTap: () {
                    final Set<int> next = <int>{...draft.tagIds};
                    if (!next.remove(t.tag.id)) next.add(t.tag.id);
                    onChanged(draft.copyWith(tagIds: next));
                  },
                ),
            ],
          ),
      ],
    );
  }
}

/// Board 3e — a searchable, wrapping multiselect over the hosts actually saved.
class _DomainGroup extends ConsumerStatefulWidget {
  const _DomainGroup({required this.draft, required this.onChanged});

  final SearchFilters draft;
  final ValueChanged<SearchFilters> onChanged;

  @override
  ConsumerState<_DomainGroup> createState() => _DomainGroupState();
}

class _DomainGroupState extends ConsumerState<_DomainGroup> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final String q = _query.text.trim().toLowerCase();
    final List<String> all =
        ref.watch(searchDomainsProvider).valueOrNull ?? const <String>[];
    final List<String> shown = all
        .where((String d) => d.toLowerCase().contains(q))
        .take(24)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: Radii.fullR,
            border: Border.all(color: c.outline),
          ),
          child: Row(
            spacing: Space.row,
            children: <Widget>[
              Icon(Icons.search_rounded, size: 17, color: c.iconMuted),
              Expanded(
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  style: PerchType.bodySmall.copyWith(
                    fontSize: 13,
                    color: c.onSurface,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Search domains',
                    hintStyle: PerchType.bodySmall.copyWith(
                      fontSize: 13,
                      color: c.onSurfaceMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.row),
        Wrap(
          spacing: 7,
          runSpacing: 2,
          children: <Widget>[
            for (final String domain in shown)
              TagChip(
                label: domain,
                selected: widget.draft.domains.contains(domain),
                onTap: () {
                  final Set<String> next = <String>{...widget.draft.domains};
                  if (!next.remove(domain)) next.add(domain);
                  widget.onChanged(widget.draft.copyWith(domains: next));
                },
              ),
          ],
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
