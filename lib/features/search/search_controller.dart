import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/link_repository.dart';
import '../../core/db/search_repository.dart';
import '../../core/providers.dart';

@immutable
class SearchState {
  const SearchState({
    this.query = '',
    this.filters = const SearchFilters(),
    this.results = const <LinkWithTags>[],
    this.total = 0,
    this.hasMore = false,
    this.loading = false,

    /// Matches that the current filters are hiding — the way out of a dead end.
    this.matchesOutsideFilters = 0,
  });

  final String query;
  final SearchFilters filters;
  final List<LinkWithTags> results;
  final int total;
  final bool hasMore;
  final bool loading;
  final int matchesOutsideFilters;

  SearchState copyWith({
    String? query,
    SearchFilters? filters,
    List<LinkWithTags>? results,
    int? total,
    bool? hasMore,
    bool? loading,
    int? matchesOutsideFilters,
  }) => SearchState(
    query: query ?? this.query,
    filters: filters ?? this.filters,
    results: results ?? this.results,
    total: total ?? this.total,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    matchesOutsideFilters:
        matchesOutsideFilters ?? this.matchesOutsideFilters,
  );
}

/// Search runs on every keystroke, debounced, and pages as the list is scrolled.
class SearchNotifier extends Notifier<SearchState> {
  static const int _pageSize = 30;
  static const Duration _debounce = Duration(milliseconds: 250);

  Timer? _timer;
  int _generation = 0;

  @override
  SearchState build() {
    ref.onDispose(() => _timer?.cancel());
    // An empty query is not an empty screen — it is every link, newest first.
    scheduleMicrotask(_run);
    return const SearchState(loading: true);
  }

  SearchRepository get _repo => ref.read(searchRepositoryProvider);

  void setQuery(String query) {
    state = state.copyWith(query: query, loading: true);
    _timer?.cancel();
    _timer = Timer(_debounce, _run);
  }

  void setFilters(SearchFilters filters) {
    state = state.copyWith(filters: filters, loading: true);
    _timer?.cancel();
    unawaited(_run());
  }

  void clearFilters() => setFilters(SearchFilters(sort: state.filters.sort));

  /// Drops the filters but keeps what was typed — "Search everywhere".
  void searchEverywhere() => clearFilters();

  Future<List<int>?> _scope() async {
    final int? folderId = state.filters.folderId;
    if (folderId == null) return null;
    if (!state.filters.includeSubfolders) return <int>[folderId];
    return ref.read(folderRepositoryProvider).descendantIds(folderId);
  }

  Future<void> _run() async {
    final int generation = ++_generation;
    final List<int>? scope = await _scope();

    final List<LinkWithTags> results = await _repo.search(
      query: state.query,
      filters: state.filters,
      folderScope: scope,
      limit: _pageSize + 1,
    );
    final int total = await _repo.count(
      query: state.query,
      filters: state.filters,
      folderScope: scope,
    );

    // A query answered while a newer one was typed is thrown away.
    if (generation != _generation) return;

    final bool hasMore = results.length > _pageSize;
    int outside = 0;
    if (results.isEmpty && !state.filters.isEmpty) {
      outside = await _repo.count(query: state.query);
      if (generation != _generation) return;
    }

    state = state.copyWith(
      results: hasMore ? results.sublist(0, _pageSize) : results,
      total: total,
      hasMore: hasMore,
      loading: false,
      matchesOutsideFilters: outside,
    );
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loading) return;
    final int generation = _generation;
    final List<LinkWithTags> next = await _repo.search(
      query: state.query,
      filters: state.filters,
      folderScope: await _scope(),
      limit: _pageSize + 1,
      offset: state.results.length,
    );
    if (generation != _generation) return;

    final bool hasMore = next.length > _pageSize;
    state = state.copyWith(
      results: <LinkWithTags>[
        ...state.results,
        ...hasMore ? next.sublist(0, _pageSize) : next,
      ],
      hasMore: hasMore,
    );
  }
}

final NotifierProvider<SearchNotifier, SearchState> searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
