import 'package:flutter/material.dart';

import '../../core/db/link_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/url.dart';
import '../../shared/widgets/link_thumbnail.dart';

/// A search hit: title with the match highlighted, domain and age, and the
/// folder it lives in as a chip.
class SearchResultTile extends StatelessWidget {
  const SearchResultTile({
    required this.data,
    required this.query,
    required this.location,
    required this.onTap,
    super.key,
  });

  final LinkWithTags data;
  final String query;
  final String location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final String title = data.link.title.isEmpty
        ? hostOf(data.link.url)
        : data.link.title;

    return RepaintBoundary(
      child: Material(
        color: c.surfaceContainer,
        borderRadius: Radii.cardR,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
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
                  url: data.link.url,
                  imageUrl: data.link.imageUrl,
                  faviconUrl: data.link.faviconUrl,
                  size: 66,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Highlighted(
                        text: title,
                        query: query,
                        style: PerchType.titleMedium.copyWith(
                          fontSize: 14,
                          height: 1.32,
                          color: c.onSurface,
                        ),
                        highlight: c.accent,
                      ),
                      const SizedBox(height: Space.xs),
                      Text(
                        '${hostOf(data.link.url)} · '
                        '${shortAge(data.link.createdAt)}',
                        style: PerchType.monoLabel.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.sm,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: c.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          location,
                          style: PerchType.monoSmall.copyWith(
                            fontSize: 10.5,
                            color: c.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows why a result matched by tinting the matched run of the title.
class _Highlighted extends StatelessWidget {
  const _Highlighted({
    required this.text,
    required this.query,
    required this.style,
    required this.highlight,
  });

  final String text;
  final String query;
  final TextStyle style;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    final String needle = query.trim().toLowerCase();
    final int at = needle.isEmpty ? -1 : text.toLowerCase().indexOf(needle);
    if (at < 0) {
      return Text(text, style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    return Text.rich(
      TextSpan(
        text: text.substring(0, at),
        style: style,
        children: <InlineSpan>[
          TextSpan(
            text: text.substring(at, at + needle.length),
            style: style.copyWith(color: highlight),
          ),
          TextSpan(text: text.substring(at + needle.length)),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
