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
/// The variants share the preview ladder, the unopened dot, the pin star and
/// the tag chips; only the layout differs, so they live together rather than
/// drifting apart in three files.
class LinkCard extends StatelessWidget {
  const LinkCard({
    required this.data,
    required this.mode,
    required this.onTap,
    this.onLongPress,
    this.locationLabel,
    this.onLocationTap,
    this.selectionMode = false,
    this.selected = false,
    super.key,
  });

  final LinkWithTags data;
  final LinkViewMode mode;
  final VoidCallback onTap;

  /// Board 3d — hold for the quick-action menu, board 3f — hold to select.
  final void Function(Offset globalPosition)? onLongPress;

  /// `Reading › Essays`. Null in Grid, which has no room for it.
  final String? locationLabel;
  final VoidCallback? onLocationTap;

  /// Board 3f — every card grows a checkmark well on the left, and the
  /// thumbnail stays put so the list does not reflow.
  final bool selectionMode;
  final bool selected;

  Link get link => data.link;

  /// A link saved a moment ago is still fetching; it draws back until it lands.
  bool get _pending =>
      link.fetchStatus == FetchStatus.pending ||
      link.fetchStatus == FetchStatus.fetching;

  /// Board 3f — 6dp of accent before the title until the link is first opened.
  bool get _unopened => link.openedAt == null;

  String get _title => link.title.isEmpty ? hostOf(link.url) : link.title;

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
        selected: selectionMode ? selected : null,
        label: _title,
        child: Opacity(opacity: _pending ? 0.55 : 1, child: card),
      ),
    );
  }

  /// Wires tap and long-press once for every variant.
  Widget _tappable({required BuildContext context, required Widget child}) {
    return GestureDetector(
      onLongPressStart: onLongPress == null
          ? null
          : (LongPressStartDetails d) => onLongPress!(d.globalPosition),
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

/// The title line: unopened dot, title, pin star.
class _TitleLine extends StatelessWidget {
  const _TitleLine({required this.card, this.maxLines = 3});

  final LinkCard card;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.sm,
      children: <Widget>[
        Expanded(
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                if (card._unopened)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: c.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                TextSpan(text: card._title),
              ],
            ),
            style: PerchType.titleMedium.copyWith(
              fontSize: 14.5,
              height: 1.35,
              color: c.onSurface,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (card.link.isFavorite)
          Text('★', style: TextStyle(fontSize: 17, height: 1, color: c.primary)),
      ],
    );
  }
}

/// The 22dp well board 3f puts on the left of every card in selection mode.
class _SelectionWell extends StatelessWidget {
  const _SelectionWell({required this.selected, this.height = 82});

  final bool selected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return SizedBox(
      height: height,
      child: Center(
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? c.primary : Colors.transparent,
            border: Border.all(
              color: selected ? c.primary : c.outline,
              width: 1.8,
            ),
          ),
          child: selected
              ? Icon(Icons.check_rounded, size: 14, color: c.onPrimary)
              : null,
        ),
      ),
    );
  }
}

/// Large list — 82dp thumbnail, domain and age, tags, a one-line note preview.
class _Large extends StatelessWidget {
  const _Large(this.card);

  final LinkCard card;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final Link link = card.link;
    final bool on = card.selectionMode && card.selected;

    return Material(
      color: on ? c.primaryContainer : c.surfaceContainer,
      borderRadius: Radii.cardR,
      clipBehavior: Clip.antiAlias,
      child: card._tappable(
        context: context,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: Radii.cardR,
            border: Border.all(color: on ? c.primary : c.outline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Space.md,
            children: <Widget>[
              if (card.selectionMode) _SelectionWell(selected: card.selected),
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
                    _TitleLine(card: card),
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
                              color: c.tagColor(tag.color),
                              selected: tag.color != null,
                            ),
                        ],
                      ),
                    ],
                    if (link.note.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        notePreview(link.note),
                        style: PerchType.bodySmall.copyWith(
                          color: c.onSurfaceVariant,
                          height: 1.35,
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
              child: Text(
                '↳ ${card.locationLabel}',
                style: PerchType.monoSmall.copyWith(color: c.onSurfaceMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
    return card._tappable(
      context: context,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.row,
          vertical: Space.row,
        ),
        child: Row(
          spacing: Space.row,
          children: <Widget>[
            if (card.selectionMode)
              _SelectionWell(selected: card.selected, height: 30),
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
                  _TitleLine(card: card, maxLines: 1),
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
    final bool on = card.selectionMode && card.selected;
    return Material(
      color: on ? c.primaryContainer : c.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: card._tappable(
        context: context,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: on ? c.primary : c.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Stack(
                children: <Widget>[
                  LinkThumbnail(
                    url: card.link.url,
                    imageUrl: card.link.imageUrl,
                    faviconUrl: card.link.faviconUrl,
                    size: 116,
                    radius: 0,
                    fill: true,
                  ),
                  if (card.selectionMode)
                    Positioned(
                      left: Space.sm,
                      top: Space.sm,
                      child: _SelectionWell(
                        selected: card.selected,
                        height: 22,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.row, 9, Space.row, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _TitleLine(card: card, maxLines: 2),
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
