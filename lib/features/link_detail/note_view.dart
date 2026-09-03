import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// The note, rendered. Markdown resolves — heading, bullets, checkboxes with
/// real strike-through — and tapping anywhere on it starts editing, in the same
/// type and position so the text you were reading does not move.
class NoteView extends StatelessWidget {
  const NoteView({required this.markdown, required this.onTap, super.key});

  final String markdown;
  final VoidCallback onTap;

  /// A ticked item is struck through (board 1f). The renderer has no notion of
  /// that, so the strike is added to the source it is handed — the stored note
  /// keeps plain `- [x]`.
  static String withStruckCheckboxes(String markdown) {
    return markdown
        .split('\n')
        .map((String line) {
          final RegExpMatch? m = RegExp(
            r'^(\s*[-*]\s+\[[xX]\]\s+)(.+)$',
          ).firstMatch(line);
          return m == null ? line : '${m.group(1)}~~${m.group(2)}~~';
        })
        .join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;

    if (markdown.trim().isEmpty) {
      return Semantics(
        button: true,
        label: 'Add a note',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: Space.xl),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.outline),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  'No note yet — tap to start writing.',
                  style: PerchType.bodySmall.copyWith(color: c.onSurfaceMuted),
                ),
                const SizedBox(height: Space.md),
                Text(
                  'Add a note',
                  style: PerchType.labelStrong.copyWith(color: c.accent),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.outline),
        ),
        child: MarkdownBody(
          data: withStruckCheckboxes(markdown),
          selectable: false,
          onTapText: onTap,
          checkboxBuilder: (bool checked) => _Checkbox(checked: checked),
          styleSheet: _styleSheet(context, c),
        ),
      ),
    );
  }

  MarkdownStyleSheet _styleSheet(BuildContext context, PerchColors c) {
    return MarkdownStyleSheet(
      p: PerchType.note.copyWith(color: c.onSurface),
      h1: PerchType.title.copyWith(color: c.onSurface),
      h2: PerchType.titleMedium.copyWith(fontSize: 15, color: c.onSurface),
      h3: PerchType.titleSmall.copyWith(color: c.onSurface),
      listBullet: PerchType.note.copyWith(color: c.onSurface),
      code: PerchType.monoLabel.copyWith(fontSize: 12.5, color: c.onSurface),
      codeblockDecoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: Radii.chipR,
      ),
      blockquoteDecoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: Radii.chipR,
      ),
      a: PerchType.note.copyWith(color: c.accent),
      del: PerchType.note.copyWith(
        color: c.onSurfaceMuted,
        decoration: TextDecoration.lineThrough,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.outline)),
      ),
      blockSpacing: Space.sm,
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(right: 9, top: 2),
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: checked ? c.primary : null,
          border: checked ? null : Border.all(color: c.onSurfaceVariant, width: 1.5),
          borderRadius: const BorderRadius.all(Radius.circular(5)),
        ),
        child: checked
            ? Icon(Icons.check_rounded, size: 11, color: c.onPrimary)
            : null,
      ),
    );
  }
}
