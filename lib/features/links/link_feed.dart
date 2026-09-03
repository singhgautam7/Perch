import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/link_repository.dart';
import '../../core/db/settings_repository.dart';
import '../../core/providers.dart';

/// Which links a feed shows. A record so it can key a provider family directly.
typedef FeedScope = ({int? folderId, bool allLinks});

const FeedScope kAllLinks = (folderId: null, allLinks: true);

FeedScope folderScope(int? id) => (folderId: id, allLinks: false);

@immutable
class LinkFeed {
  const LinkFeed({
    required this.items,
    required this.hasMore,
    required this.loadingMore,
  });

  final List<LinkWithTags> items;
  final bool hasMore;
  final bool loadingMore;

  LinkFeed copyWith({
    List<LinkWithTags>? items,
    bool? hasMore,
    bool? loadingMore,
  }) => LinkFeed(
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// A page at a time — the list never holds the whole table.
///
/// The feed re-reads exactly the rows it already has whenever the links table
/// changes, so an edit elsewhere shows up without dropping the scroll position.
class LinkFeedNotifier extends FamilyAsyncNotifier<LinkFeed, FeedScope> {
  static const int _pageSize = 30;

  @override
  Future<LinkFeed> build(FeedScope arg) async {
    // Any write to `links` re-runs this; the reload keeps everything already
    // paged in.
    ref.watch(linkChangeSignalProvider);
    final LinkSort sort = ref.watch(
      settingsProvider.select((AppSettings s) => s.sort),
    );
    final int keep = state.valueOrNull?.items.length ?? 0;
    return _fetch(limit: keep > _pageSize ? keep : _pageSize, sort: sort);
  }

  Future<LinkFeed> _fetch({required int limit, required LinkSort sort}) async {
    final List<LinkWithTags> items = await ref
        .read(linkRepositoryProvider)
        .page(
          limit: limit + 1,
          folderId: arg.allLinks ? null : arg.folderId,
          unsortedOnly: !arg.allLinks && arg.folderId == null,
          sort: sort,
        );
    final bool hasMore = items.length > limit;
    return LinkFeed(
      items: hasMore ? items.sublist(0, limit) : items,
      hasMore: hasMore,
      loadingMore: false,
    );
  }

  Future<void> loadMore() async {
    final LinkFeed? current = state.valueOrNull;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData<LinkFeed>(current.copyWith(loadingMore: true));

    final LinkSort sort = ref.read(settingsProvider).sort;
    final List<LinkWithTags> next = await ref
        .read(linkRepositoryProvider)
        .page(
          limit: _pageSize + 1,
          offset: current.items.length,
          folderId: arg.allLinks ? null : arg.folderId,
          unsortedOnly: !arg.allLinks && arg.folderId == null,
          sort: sort,
        );
    final bool hasMore = next.length > _pageSize;
    state = AsyncData<LinkFeed>(
      LinkFeed(
        items: <LinkWithTags>[
          ...current.items,
          ...hasMore ? next.sublist(0, _pageSize) : next,
        ],
        hasMore: hasMore,
        loadingMore: false,
      ),
    );
  }
}

final AsyncNotifierProviderFamily<LinkFeedNotifier, LinkFeed, FeedScope>
linkFeedProvider =
    AsyncNotifierProvider.family<LinkFeedNotifier, LinkFeed, FeedScope>(
      LinkFeedNotifier.new,
    );

/// Fires whenever anything in `links` changes. Cheap: it reads two aggregates,
/// not the rows.
final StreamProvider<int> linkChangeSignalProvider = StreamProvider<int>((
  Ref ref,
) {
  final PerchDatabase db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT COUNT(*) AS c, COALESCE(MAX(updated_at), 0) AS u FROM links',
        readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{db.links},
      )
      .watch()
      .map((List<QueryRow> rows) => Object.hash(
            rows.first.read<int>('c'),
            rows.first.read<int>('u'),
          ));
});

/// Total number of saved links — the count in the Links header.
final StreamProvider<int> linkCountProvider = StreamProvider<int>((Ref ref) {
  final PerchDatabase db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT COUNT(*) AS c FROM links',
        readsFrom: <ResultSetImplementation<HasResultSet, dynamic>>{db.links},
      )
      .watch()
      .map((List<QueryRow> rows) => rows.first.read<int>('c'));
});
