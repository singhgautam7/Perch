import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/link_repository.dart';
import '../../core/db/search_repository.dart';
import '../../core/db/tag_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/tag_chip.dart';
import '../folders/folder_providers.dart';
import '../links/links_screen.dart';
import 'filter_sheet.dart';
import 'search_controller.dart';
import 'search_result_tile.dart';

/// Boards 1g and 3e — a pushed route under the one common header.
///
/// An empty query is every link, newest first; typing narrows it live. The five
/// quick chips sit above the results, because they are the filters people
/// actually reach for.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.tagId, super.key});

  /// Opened from a tag: the screen lands with that tag already applied.
  final int? tagId;

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
    final int? tag = widget.tagId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final SearchNotifier notifier = ref.read(searchProvider.notifier);
      notifier.setFilters(
        tag == null
            ? const SearchFilters()
            : SearchFilters(tagIds: <int>{tag}),
      );
    });
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
    final SearchState state = ref.watch(searchProvider);
    final Map<int, String> paths = ref.watch(folderPathsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            AppHeader(title: 'Search', onBack: () => context.pop()),
            _SearchField(controller: _field),
            const _QuickChips(),
            if (!state.filters.isEmpty)
              _ActiveFilters(state: state, paths: paths),
            SectionHeader(
              label: state.query.isEmpty && state.filters.isEmpty
                  ? 'Recent · ${grouped(state.total)}'
                  : '${grouped(state.total)} results',
              trailing: SortControl(
                sort: state.filters.sort,
                onChanged: (LinkSort s) => ref
                    .read(searchProvider.notifier)
                    .setFilters(state.filters.copyWith(sort: s)),
              ),
            ),
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
                        Space.bottomSafe,
                      ),
                      itemCount: state.results.length + (state.hasMore ? 1 : 0),
                      separatorBuilder: (BuildContext context, int _) =>
                          const SizedBox(height: Space.sm),
                      itemBuilder: (BuildContext context, int index) {
                        if (index >= state.results.length) {
                          return const Padding(
                            padding: EdgeInsets.all(Space.screen),
                            child: Center(child: LoadingMore()),
                          );
                        }
                        final LinkWithTags item = state.results[index];
                        return SearchResultTile(
                          data: item,
                          query: state.query,
                          location: item.link.folderId == null
                              ? 'Unsorted'
                              : paths[item.link.folderId!] ?? 'Unsorted',
                          onTap: () => context.push(Routes.link(item.link.id)),
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

/// The pill with the `Filter` action inside it, exactly as board 3e draws it.
class _SearchField extends ConsumerWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final int active = ref.watch(
      searchProvider.select((SearchState s) => s.filters.activeCount),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.screen,
        0,
        Space.screen,
        Space.md,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: Radii.fullR,
          border: Border.all(color: c.outline),
        ),
        child: Row(
          spacing: 11,
          children: <Widget>[
            Icon(Icons.search_rounded, size: 18, color: c.iconMuted),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: ref.read(searchProvider.notifier).setQuery,
                style: PerchType.body.copyWith(fontSize: 14, color: c.onSurface),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  hintText: 'Search titles, notes, URLs',
                  hintStyle: PerchType.body.copyWith(
                    fontSize: 14,
                    color: c.onSurfaceMuted,
                  ),
                ),
              ),
            ),
            AppButton(
              label: active == 0 ? 'Filter' : 'Filter · $active',
              type: active == 0
                  ? AppButtonType.secondary
                  : AppButtonType.primary,
              compact: true,
              onPressed: () => showFilterSheet(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

/// B5 — Unsorted · Untagged · Unopened · Has note · Favourites, one tap each.
/// They set the same state the sheet does, so the chips below reflect either
/// route.
class _QuickChips extends ConsumerWidget {
  const _QuickChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SearchFilters f = ref.watch(
      searchProvider.select((SearchState s) => s.filters),
    );
    final SearchNotifier notifier = ref.read(searchProvider.notifier);

    final List<(String, bool, SearchFilters)> chips =
        <(String, bool, SearchFilters)>[
          ('Unsorted', f.unsorted, f.copyWith(unsorted: !f.unsorted)),
          ('Untagged', f.untagged, f.copyWith(untagged: !f.untagged)),
          ('Unopened', f.unopened, f.copyWith(unopened: !f.unopened)),
          (
            'Has note',
            f.hasNote == Tri.yes,
            f.copyWith(hasNote: f.hasNote == Tri.yes ? Tri.any : Tri.yes),
          ),
          ('Favourites', f.favorites, f.copyWith(favorites: !f.favorites)),
        ];

    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, 0),
        children: <Widget>[
          for (final (String label, bool on, SearchFilters next) in chips)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: Center(
                child: TagChip(
                  label: label,
                  selected: on,
                  onTap: () => notifier.setFilters(next),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Board 3e — every applied filter becomes a removable chip under the field.
class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters({required this.state, required this.paths});

  final SearchState state;
  final Map<int, String> paths;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final SearchFilters f = state.filters;
    final SearchNotifier notifier = ref.read(searchProvider.notifier);
    final List<TagWithCount> tags =
        ref.watch(allTagsProvider).valueOrNull ?? const <TagWithCount>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.screen,
        0,
        Space.screen,
        Space.md,
      ),
      child: Wrap(
        spacing: 7,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          if (f.folderId != null)
            TagChip(
              label:
                  '${paths[f.folderId!] ?? 'Folder'}'
                  '${f.includeSubfolders ? ' + sub' : ''}',
              selected: true,
              onRemove: () => notifier.setFilters(f.copyWith(clearFolder: true)),
            ),
          for (final TagWithCount t in tags)
            if (f.tagIds.contains(t.tag.id))
              TagChip(
                label: t.tag.name,
                selected: true,
                color: c.tagColor(t.tag.color),
                onRemove: () => notifier.setFilters(
                  f.copyWith(tagIds: <int>{...f.tagIds}..remove(t.tag.id)),
                ),
              ),
          for (final String domain in f.domains)
            TagChip(
              label: domain,
              selected: true,
              onRemove: () => notifier.setFilters(
                f.copyWith(domains: <String>{...f.domains}..remove(domain)),
              ),
            ),
          if (f.hasNote != Tri.any)
            TagChip(
              label: f.hasNote == Tri.yes ? 'Has note' : 'No note',
              selected: true,
              onRemove: () => notifier.setFilters(f.copyWith(hasNote: Tri.any)),
            ),
          if (f.hasPreview != Tri.any)
            TagChip(
              label: f.hasPreview == Tri.yes ? 'Has preview' : 'No preview',
              selected: true,
              onRemove: () =>
                  notifier.setFilters(f.copyWith(hasPreview: Tri.any)),
            ),
          if (f.datePreset != DatePreset.anyTime)
            TagChip(
              label: f.datePreset.label,
              selected: true,
              onRemove: () => notifier.setFilters(
                f.copyWith(datePreset: DatePreset.anyTime, clearRange: true),
              ),
            ),
          if (f.unsorted)
            TagChip(
              label: 'Unsorted',
              selected: true,
              onRemove: () => notifier.setFilters(f.copyWith(unsorted: false)),
            ),
          if (f.untagged)
            TagChip(
              label: 'Untagged',
              selected: true,
              onRemove: () => notifier.setFilters(f.copyWith(untagged: false)),
            ),
          if (f.unopened)
            TagChip(
              label: 'Unopened',
              selected: true,
              onRemove: () => notifier.setFilters(f.copyWith(unopened: false)),
            ),
          if (f.favorites)
            TagChip(
              label: 'Favourites',
              selected: true,
              onRemove: () => notifier.setFilters(f.copyWith(favorites: false)),
            ),
          GestureDetector(
            onTap: notifier.clearFilters,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: Space.md,
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
                    onPressed:
                        ref.read(searchProvider.notifier).searchEverywhere,
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
