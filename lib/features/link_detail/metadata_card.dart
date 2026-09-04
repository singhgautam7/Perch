import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/url.dart';

/// Board 3d — a collapsed row that opens into the raw fields Perch cached.
///
/// It stays collapsed by default: the note leads this screen, metadata is what
/// you consult when the note is not enough.
class MetadataCard extends StatelessWidget {
  const MetadataCard({
    required this.link,
    required this.open,
    required this.onToggle,
    super.key,
  });

  final Link link;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          button: true,
          expanded: open,
          label: open ? 'Hide metadata' : 'Show metadata',
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: c.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.outline),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      open ? 'Hide metadata' : 'Show metadata',
                      style: PerchType.label
                          .copyWith(fontSize: 13.5, color: c.onSurface)
                          .weight(600),
                    ),
                  ),
                  Icon(
                    open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: c.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (open) ...<Widget>[
          const SizedBox(height: Space.sm),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 9,
              children: <Widget>[
                _Field(label: 'URL', value: link.url),
                if (link.description != null && link.description!.isNotEmpty)
                  _Field(label: 'Description', value: link.description!),
                _Field(
                  label: 'Site',
                  value: link.siteName?.isNotEmpty ?? false
                      ? link.siteName!
                      : hostOf(link.url),
                ),
                _Field(
                  label: 'Fetched',
                  value: link.fetchedAt == null
                      ? 'Not fetched yet'
                      : longDate(link.fetchedAt!),
                ),
                if (link.openCount > 0)
                  _Field(
                    label: 'Opened',
                    value:
                        '${plural(link.openCount, 'time')}'
                        '${link.openedAt == null ? '' : ', last ${shortAge(link.openedAt!)} ago'}',
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: PerchType.sectionHeader.copyWith(
            fontSize: 9.5,
            letterSpacing: 0.86,
            color: c.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: PerchType.bodySmall.copyWith(
            fontSize: 12.5,
            height: 1.45,
            color: c.onSurface,
          ),
        ),
      ],
    );
  }
}
