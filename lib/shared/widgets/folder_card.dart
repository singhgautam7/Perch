import 'package:flutter/material.dart';

import '../../core/db/folder_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';

/// The folder silhouette used on cards and rows — square top-left, rounded
/// elsewhere, same shape as the nav glyph.
class FolderGlyph extends StatelessWidget {
  const FolderGlyph({required this.color, this.width = 22, super.key});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: width * 0.78,
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(6),
        bottomLeft: Radius.circular(6),
        bottomRight: Radius.circular(6),
      ),
    ),
  );
}

/// A folder in the grid on the Folders tab. Pressing scales it to 0.97 and
/// tints it, which is the only press feedback in the app that changes colour.
class FolderCard extends StatefulWidget {
  const FolderCard({
    required this.summary,
    required this.onTap,
    this.onLongPress,
    super.key,
  });

  final FolderSummary summary;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<FolderCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final FolderSummary s = widget.summary;
    final String counts = s.subfolderCount == 0
        ? plural(s.linkCount, 'link')
        : '${plural(s.subfolderCount, 'folder')} · ${s.linkCount}';

    return Semantics(
      button: true,
      label: '${s.folder.name}, $counts',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: Motion.of(context, Motion.fast),
          child: AnimatedContainer(
            duration: Motion.of(context, Motion.fast),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: BoxDecoration(
              color: _pressed ? c.primaryContainer : c.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _pressed ? c.accent.withValues(alpha: 0.4) : c.outline,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FolderGlyph(color: _pressed ? c.accent : c.primary),
                const SizedBox(height: 9),
                Text(
                  s.folder.name,
                  style: PerchType.titleMedium.copyWith(
                    fontSize: 14,
                    color: _pressed ? c.onPrimaryContainer : c.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  counts,
                  style: PerchType.monoLabel.copyWith(
                    fontSize: 11.5,
                    color: _pressed ? c.accent : c.onSurfaceVariant,
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

/// The single-line form used when drilling into a folder, where subfolders are
/// listed rather than tiled.
class FolderRow extends StatelessWidget {
  const FolderRow({
    required this.summary,
    required this.onTap,
    this.onLongPress,
    super.key,
  });

  final FolderSummary summary;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final String counts = plural(summary.linkCount, 'link');

    return Semantics(
      button: true,
      label: '${summary.folder.name}, $counts',
      child: Material(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.outline),
            ),
            child: Row(
              spacing: 13,
              children: <Widget>[
                FolderGlyph(color: c.primary, width: 26),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        summary.folder.name,
                        style: PerchType.titleMedium.copyWith(
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
                  color: c.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
