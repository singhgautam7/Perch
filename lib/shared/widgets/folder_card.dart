import 'package:flutter/material.dart';

import '../../core/db/folder_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';

/// The folder silhouette used on rows and in the picker — square top-left,
/// rounded elsewhere, same shape as the nav glyph.
class FolderGlyph extends StatelessWidget {
  const FolderGlyph({
    required this.color,
    this.width = 22,
    this.filled = true,
    super.key,
  });

  final Color color;
  final double width;

  /// False draws the outline form the folder picker's tree uses.
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: width * 0.76,
    decoration: BoxDecoration(
      color: filled ? color : null,
      border: filled ? null : Border.all(color: color, width: IconSpec.stroke),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(3),
        topRight: Radius.circular(6),
        bottomLeft: Radius.circular(6),
        bottomRight: Radius.circular(6),
      ),
    ),
  );
}

/// Board 3a — one folder row, in the same rhythm as a link card: a tinted
/// 36dp well, the name, the counts in mono, a chevron.
class FolderRow extends StatelessWidget {
  const FolderRow({
    required this.summary,
    required this.onTap,
    this.onLongPress,
    super.key,
  });

  final FolderSummary summary;
  final VoidCallback onTap;
  final void Function(Offset globalPosition)? onLongPress;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final FolderTint tint = c.folderTint(summary.folder.color);
    final String counts = summary.subfolderCount == 0
        ? plural(summary.linkCount, 'link')
        : '${plural(summary.linkCount, 'link')} · '
              '${plural(summary.subfolderCount, 'folder')}';

    return Semantics(
      button: true,
      label: '${summary.folder.name}, $counts',
      child: Material(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          onLongPressStart: onLongPress == null
              ? null
              : (LongPressStartDetails d) => onLongPress!(d.globalPosition),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.md,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.outline),
              ),
              child: Row(
                spacing: Space.md,
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: tint.container,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: FolderGlyph(color: tint.accent, width: 19),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          summary.folder.name,
                          style: PerchType.titleMedium.copyWith(
                            fontSize: 14.5,
                            color: c.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          counts,
                          style: PerchType.monoLabel.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: c.onSurfaceMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
