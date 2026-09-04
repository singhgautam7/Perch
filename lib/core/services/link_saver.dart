import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database.dart';
import '../db/link_repository.dart';
import '../db/tables.dart';
import '../providers.dart';
import 'metadata_fetcher.dart';

/// Saves a link and then fills in its metadata.
///
/// The save writes immediately and the fetch happens after, so a share-sheet
/// save never waits on the network and a failed fetch never loses the link.
class LinkSaver {
  LinkSaver(this._ref);

  final Ref _ref;

  LinkRepository get _links => _ref.read(linkRepositoryProvider);

  Future<int> save({
    required String url,
    String title = '',
    String note = '',
    int? folderId,
    List<int> tagIds = const <int>[],
    LinkMetadata? metadata,
  }) async {
    final int id = await _links.create(
      url: url,
      title: title,
      note: note,
      folderId: folderId,
      fetchStatus: metadata == null ? FetchStatus.pending : FetchStatus.ok,
    );
    if (tagIds.isNotEmpty) {
      await _ref.read(tagRepositoryProvider).setForLinkByIds(id, tagIds);
    }

    if (metadata != null) {
      // The Add screen already fetched — reuse it rather than hitting the site
      // a second time.
      await _apply(id, MetadataResult(MetadataOutcome.ok, metadata), title);
    } else {
      unawaited(refresh(id));
    }
    return id;
  }

  /// Fetches (or re-fetches) metadata for a saved link.
  Future<void> refresh(int id) async {
    final Link? link = await _links.byId(id);
    if (link == null) return;

    await _links.update(
      id,
      const LinksCompanion(fetchStatus: Value<FetchStatus>(FetchStatus.fetching)),
    );
    final MetadataResult result = await _ref
        .read(metadataFetcherProvider)
        .fetch(link.url);
    await _apply(id, result, link.title);
  }

  Future<void> _apply(int id, MetadataResult result, String existingTitle) {
    final LinkMetadata m = result.metadata;
    return _links.update(
      id,
      LinksCompanion(
        // A title the user typed always wins over a suggested one.
        title: existingTitle.trim().isEmpty && m.title != null
            ? Value<String>(m.title!)
            : const Value<String>.absent(),
        siteName: Value<String?>(m.siteName),
        description: Value<String?>(m.description),
        imageUrl: Value<String?>(m.imageUrl),
        faviconUrl: Value<String?>(m.faviconUrl),
        fetchedAt: Value<DateTime>(DateTime.now()),
        fetchStatus: Value<FetchStatus>(switch (result.outcome) {
          MetadataOutcome.ok => FetchStatus.ok,
          MetadataOutcome.noPreview => FetchStatus.noPreview,
          MetadataOutcome.failed => FetchStatus.failed,
        }),
      ),
    );
  }
}

final Provider<MetadataFetcher> metadataFetcherProvider =
    Provider<MetadataFetcher>((Ref ref) {
      final MetadataFetcher fetcher = MetadataFetcher();
      ref.onDispose(fetcher.dispose);
      return fetcher;
    });

final Provider<LinkSaver> linkSaverProvider = Provider<LinkSaver>(
  LinkSaver.new,
);
