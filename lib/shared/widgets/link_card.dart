import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../core/db/link_repository.dart';
import '../../core/db/settings_repository.dart';
import '../../core/db/tables.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/url.dart';
import 'link_thumbnail.dart';
import 'tag_chip.dart';

/// One link, drawn in whichever of the three view modes is active.
///
/// The variants share the preview ladder and the tag chips; only the layout
/// differs, so they live together rather than drifting apart in three files.
class LinkCard extends StatelessWidget {
  const LinkCard({
    required this.data,
    required this.mode,
    required this.onTap,
    this.locationLabel,
    this.onLocationTap,
    super.key,
  });

  final LinkWithTags data;
  final LinkViewMode mode;
  final VoidCallback onTap;

  /// `Reading › Essays`. Null in Grid, which has no room for it.
  final String? locationLabel;
  final VoidCallback? onLocationTap;

  Link get link => data.link;

  /// A link saved a moment ago is still fetching; it draws back until it lands.
  bool get _pending =>
      link.fetchStatus == FetchStatus.pending ||
      link.fetchStatus == FetchStatus.fetching;

  @override
  Widget build(BuildContext context) {
    final Widget card = switch (mode) {
      LinkViewMode.large => _Large(this),
      LinkViewMode.minimal => _Minimal(this),
      LinkViewMode.grid => _Grid(this),
    };
    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: link.title.isEmpty ? hostOf(link.url) : link.title,
        child: Opacity(opacity: _pending ? 0.55 : 1, child: card),
      ),
    );
  }

  String get _title => link.title.isEmpty ? hostOf(link.url) : link.title;
}

/// Large list — 82dp thumbnail, domain and age, tags, a one-line note preview.
class _Large extends StatelessWidget {
  const _Large(this.card);

  final LinkCard card;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final Link link = card.link;

    return Material(
      color: c.surfaceContainer,
      borderRadius: Radii.cardR,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: card.onTap,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: Radii.cardR,
            border: Border.all(color: c.outline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Space.md,
            children: <Widget>[
              LinkThumbnail(
                url: link.url,
                imageUrl: link.imageUrl,
                faviconUrl: link.faviconUrl,
                size: 82,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      card._title,
                      style: PerchType.titleMedium.copyWith(color: c.onSurface),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Space.xs),
                    _MetaRow(card: card),
                    if (card.data.tags.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 5,
                        runSpacing: Space.xs,
                        children: <Widget>[
                          for (final Tag tag in card.data.tags.take(4))
                            TagChip(
                              label: tag.name,
                              compact: true,
                              style: tag.color == null
                                  ? ChipStyle.plain
                                  : ChipStyle.active,
                            ),
                        ],
                      ),
                    ],
                    if (link.note.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        link.note.trim().replaceAll('\n', ' '),
                        style: PerchType.bodySmall.copyWith(
                          color: c.onSurfaceVariant,
                          height: 1.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `craigmod.com · 2h    ↳ Reading › Essays`
///
/// The location is metadata, not a card — a quiet mono line that happens to be
/// tappable and jumps to that folder.
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.card});

  final LinkCard card;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Row(
      spacing: 7,
      children: <Widget>[
        Flexible(
          child: Text(
            '${hostOf(card.link.url)} · ${shortAge(card.link.createdAt)}',
            style: PerchType.monoLabel.copyWith(
              fontSize: 11.5,
              color: c.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (card.locationLabel != null)
          Flexible(
            child: GestureDetector(
              onTap: card.onLocationTap,
              behavior: HitTestBehavior.opaque,
              child: Opacity(
                opacity: 0.9,
                child: Text(
                  '↳ ${card.locationLabel}',
                  style: PerchType.monoSmall.copyWith(
                    color: c.onSurfaceMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Minimal list — a 30dp thumbnail, title, domain. One row of a grouped list,
/// so the divider is drawn by the list, not the card.
class _Minimal extends StatelessWidget {
  const _Minimal(this.card);

  final LinkCard card;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return InkWell(
      onTap: card.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.row,
          vertical: Space.row,
        ),
        child: Row(
          spacing: Space.row,
          children: <Widget>[
            LinkThumbnail(
              url: card.link.url,
              imageUrl: card.link.imageUrl,
              faviconUrl: card.link.faviconUrl,
              size: 30,
              radius: Radii.chip,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    card._title,
                    style: PerchType.label.copyWith(
                      fontSize: 12.5,
                      color: c.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    hostOf(card.link.url),
                    style: PerchType.monoSmall.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid — the thumbnail does the identifying, so the location line is dropped.
class _Grid extends StatelessWidget {
  const _Grid(this.card);

  final LinkCard card;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Material(
      color: c.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: card.onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              LinkThumbnail(
                url: card.link.url,
                imageUrl: card.link.imageUrl,
                faviconUrl: card.link.faviconUrl,
                size: 116,
                radius: 0,
                fill: true,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.row, 9, Space.row, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      card._title,
                      style: PerchType.label.copyWith(
                        fontSize: 12.5,
                        height: 1.35,
                        color: c.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      hostOf(card.link.url),
                      style: PerchType.monoSmall.copyWith(
                        fontSize: 10.5,
                        color: c.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
