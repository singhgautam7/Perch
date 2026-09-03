import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/link_repository.dart';
import '../../core/db/tag_repository.dart';
import '../../core/db/search_repository.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/tag_chip.dart';
import '../add_link/tag_field.dart';
import '../folders/folder_providers.dart';
import '../links/links_screen.dart';
import 'filter_sheet.dart';
import 'search_controller.dart';
import 'search_result_tile.dart';

/// Board 1g — a pushed route, not a tab.
///
/// An empty query is every link, newest first; typing narrows it live. Each
/// result carries the folder it lives in.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _field = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _field.dispose();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 600) {
      ref.read(searchProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final SearchState state = ref.watch(searchProvider);
    final Map<int, String> paths = ref.watch(folderPathsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _SearchBar(controller: _field),
            _ControlRow(state: state),
            if (!state.filters.isEmpty)
              _ActiveFilters(state: state, paths: paths),
            Expanded(
              child: state.results.isEmpty
                  ? (state.loading
                        ? const ListSkeleton(rows: 4)
                        : _NoResults(state: state, paths: paths))
                  : ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(
                        Space.screen,
                        0,
                        Space.screen,
                        Space.xl,
                      ),
                      itemCount: state.results.length + (state.hasMore ? 1 : 0),
                      separatorBuilder: (BuildContext context, int _) =>
                          const SizedBox(height: Space.sm),
                      itemBuilder: (BuildContext context, int index) {
                        if (index >= state.results.length) {
                          return Padding(
                            padding: const EdgeInsets.all(Space.screen),
                            child: Center(
                              child: Text(
                                'Loading more…',
                                style: PerchType.monoLabel.copyWith(
                                  color: c.onSurfaceVariant,
                                ),
                              ),
                            ),
                          );
                        }
                        final LinkWithTags item = state.results[index];
                        return SearchResultTile(
                          data: item,
                          query: state.query,
                          location: item.link.folderId == null
                              ? 'Unsorted'
                              : paths[item.link.folderId!] ?? 'Unsorted',
                          onTap: () =>
                              context.push(Routes.link(item.link.id)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends ConsumerWidget {
  const _SearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.row),
      child: Row(
        spacing: Space.sm,
        children: <Widget>[
          AppIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => context.pop(),
            semanticLabel: 'Back',
            size: 40,
          ),
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: Space.lg),
              decoration: BoxDecoration(
                color: c.surfaceContainer,
                borderRadius: Radii.fullR,
                border: Border.all(color: c.outline),
              ),
              child: Row(
                spacing: Space.row,
                children: <Widget>[
                  Icon(Icons.search_rounded, size: 20, color: c.iconMuted),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: (String v) =>
                          ref.read(searchProvider.notifier).setQuery(v),
                      style: PerchType.body.copyWith(color: c.onSurface),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Search all links',
                        hintStyle: PerchType.body.copyWith(
                          color: c.onSurfaceMuted,
                        ),
                      ),
                    ),
                  ),
                  if (controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        controller.clear();
                        ref.read(searchProvider.notifier).setQuery('');
                      },
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: c.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `Filter · N` and the sort control on the left, the result count on the right.
class _ControlRow extends ConsumerWidget {
  const _ControlRow({required this.state});

  final SearchState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final int active = _activeCount(state.filters);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 2, Space.screen, Space.md),
      child: Row(
        spacing: Space.sm,
        children: <Widget>[
          AppButton(
            label: active == 0 ? 'Filter' : 'Filter · $active',
            type: active == 0 ? AppButtonType.secondary : AppButtonType.primary,
            compact: true,
            icon: Icons.tune_rounded,
            onPressed: () => showFilterSheet(context, ref),
          ),
          AppButton(
            label: '${state.filters.sort.label.split(' ').first} ↓',
            type: AppButtonType.secondary,
            compact: true,
            onPressed: () async {
              await showSortSheet(context, ref, state.filters.sort);
              if (!context.mounted) return;
              ref
                  .read(searchProvider.notifier)
                  .setFilters(
                    state.filters.copyWith(
                      sort: ref.read(searchProvider).filters.sort,
                    ),
                  );
            },
          ),
          const Spacer(),
          Text(
            plural(state.total, 'link'),
            style: PerchType.monoLabel.copyWith(color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

int _activeCount(SearchFilters f) {
  int n = 0;
  if (f.folderId != null) n++;
  if (f.tagIds.isNotEmpty) n++;
  if (f.hasNote) n++;
  if (f.hasImage) n++;
  if (f.domain != null) n++;
  if (f.datePreset != DatePreset.anyTime) n++;
  return n;
}

/// Every active filter as a removable chip, plus Clear all.
class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters({required this.state, required this.paths});

  final SearchState state;
  final Map<int, String> paths;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final SearchFilters f = state.filters;
    final SearchNotifier notifier = ref.read(searchProvider.notifier);
    final List<String> tagNames = _tagNames(ref, f);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.md),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          if (f.folderId != null)
            TagChip(
              label:
                  '${paths[f.folderId!] ?? 'Folder'}'
                  '${f.includeSubfolders ? ' + sub' : ''}',
              style: ChipStyle.active,
              onRemove: () => notifier.setFilters(f.copyWith(clearFolder: true)),
            ),
          if (tagNames.isNotEmpty)
            TagChip(
              label: tagNames.join(
                f.tagMatch == TagMatch.all ? ' AND ' : ' OR ',
              ),
              style: ChipStyle.active,
              onRemove: () =>
                  notifier.setFilters(f.copyWith(tagIds: const <int>{})),
            ),
          if (f.hasNote)
            TagChip(
              label: 'Has note',
              style: ChipStyle.active,
              onRemove: () => notifier.setFilters(f.copyWith(hasNote: false)),
            ),
          if (f.hasImage)
            TagChip(
              label: 'Has preview',
              style: ChipStyle.active,
              onRemove: () => notifier.setFilters(f.copyWith(hasImage: false)),
            ),
          if (f.domain != null)
            TagChip(
              label: f.domain!,
              style: ChipStyle.active,
              onRemove: () => notifier.setFilters(f.copyWith(clearDomain: true)),
            ),
          if (f.datePreset != DatePreset.anyTime)
            TagChip(
              label: f.datePreset.label,
              style: ChipStyle.active,
              onRemove: () => notifier.setFilters(
                f.copyWith(datePreset: DatePreset.anyTime),
              ),
            ),
          GestureDetector(
            onTap: notifier.clearFilters,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: Space.sm,
              ),
              child: Text(
                'Clear all',
                style: PerchType.labelStrong.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _tagNames(WidgetRef ref, SearchFilters f) {
    final List<TagWithCount> tags =
        ref.watch(allTagsProvider).valueOrNull ?? const <TagWithCount>[];
    return tags
        .where((TagWithCount t) => f.tagIds.contains(t.tag.id))
        .map((TagWithCount t) => t.tag.name)
        .toList(growable: false);
  }
}

/// No results offers the way out, not a dead end.
class _NoResults extends ConsumerWidget {
  const _NoResults({required this.state, required this.paths});

  final SearchState state;
  final Map<int, String> paths;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final String? folder = state.filters.folderId == null
        ? null
        : paths[state.filters.folderId!];
    final int outside = state.matchesOutsideFilters;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.search_rounded, size: 40, color: c.onSurfaceMuted),
            const SizedBox(height: Space.lg),
            Text(
              folder == null ? 'No matches' : 'No matches in $folder',
              textAlign: TextAlign.center,
              style: PerchType.display.copyWith(
                fontSize: 26,
                height: 1.2,
                color: c.onSurface,
              ),
            ),
            const SizedBox(height: Space.row),
            Text.rich(
              TextSpan(
                text: state.query.isEmpty
                    ? 'Nothing here yet.'
                    : 'Nothing here matches “${state.query}”.',
                style: PerchType.body.copyWith(
                  fontSize: 14.5,
                  height: 1.6,
                  color: c.onSurfaceVariant,
                ),
                children: <InlineSpan>[
                  if (outside > 0) ...<InlineSpan>[
                    const TextSpan(text: ' There are '),
                    TextSpan(
                      text: plural(outside, 'match', 'matches'),
                      style: TextStyle(color: c.accent),
                    ),
                    const TextSpan(text: ' outside your filters.'),
                  ],
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.xl),
            if (!state.filters.isEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: Space.sm,
                children: <Widget>[
                  AppButton(
                    label: 'Search everywhere',
                    onPressed: ref.read(searchProvider.notifier).searchEverywhere,
                  ),
                  AppButton(
                    label: 'Clear filters',
                    type: AppButtonType.outlined,
                    onPressed: ref.read(searchProvider.notifier).clearFilters,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
