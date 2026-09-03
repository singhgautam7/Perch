import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../core/db/tables.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/url.dart';
import '../../shared/widgets/link_thumbnail.dart';

/// One collapsed row above the note, opening onto everything the fetch cached.
///
/// It reads from the database, so the expanded card is fully populated offline;
/// ⟳ Re-fetch is the only network affordance and it says when it last ran.
class MetadataCard extends StatelessWidget {
  const MetadataCard({
    required this.link,
    required this.open,
    required this.onToggle,
    required this.onRefetch,
    super.key,
  });

  final Link link;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onRefetch;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return AnimatedSize(
      duration: Motion.of(context, Motion.folderOpen),
      curve: Motion.curveOf(context, Motion.decelerate),
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: Radii.thumbR,
          border: open ? Border.all(color: c.outline) : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              button: true,
              expanded: open,
              child: InkWell(
                onTap: onToggle,
                child: SizedBox(
                  height: 46,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            open ? 'Metadata' : 'Show metadata',
                            style: PerchType.label.copyWith(
                              fontSize: 13,
                              color: c.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (open)
                          _RefetchButton(link: link, onRefetch: onRefetch)
                        else
                          Icon(
                            Icons.expand_more_rounded,
                            size: 18,
                            color: c.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (open) _Expanded(link: link),
          ],
        ),
      ),
    );
  }
}

class _RefetchButton extends StatelessWidget {
  const _RefetchButton({required this.link, required this.onRefetch});

  final Link link;
  final VoidCallback onRefetch;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final bool busy = link.fetchStatus == FetchStatus.fetching;
    return Semantics(
      button: true,
      label: 'Re-fetch metadata',
      child: GestureDetector(
        onTap: busy ? null : onRefetch,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.md),
          child: Text(
            busy ? '⟳ FETCHING…' : '⟳ RE-FETCH',
            style: PerchType.monoSmall.copyWith(fontSize: 11, color: c.accent),
          ),
        ),
      ),
    );
  }
}

class _Expanded extends StatelessWidget {
  const _Expanded({required this.link});

  final Link link;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 11,
            children: <Widget>[
              LinkThumbnail(
                url: link.url,
                imageUrl: link.imageUrl,
                faviconUrl: link.faviconUrl,
                size: 64,
              ),
              Expanded(
                child: Text(
                  link.description ?? 'The page offers no description.',
                  style: PerchType.bodySmall.copyWith(
                    fontSize: 11.5,
                    height: 1.5,
                    color: c.onSurfaceVariant,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          _Fact(label: 'site', value: link.siteName ?? hostOf(link.url)),
          _Fact(
            label: 'fetched',
            value: link.fetchedAt == null
                ? 'not yet'
                : longDate(link.fetchedAt!),
          ),
          _Fact(
            label: 'cached',
            value: switch (link.fetchStatus) {
              FetchStatus.ok => 'yes · works offline',
              FetchStatus.noPreview => 'yes · no image offered',
              FetchStatus.failed => 'no · page could not be read',
              FetchStatus.fetching => 'fetching…',
              FetchStatus.pending => 'not fetched yet',
            },
          ),
          if (link.imageUrl != null)
            _Fact(label: 'preview', value: middleTruncate(link.imageUrl!)),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Space.md,
        children: <Widget>[
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: PerchType.monoSmall.copyWith(color: c.onSurfaceMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: PerchType.monoSmall.copyWith(color: c.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
