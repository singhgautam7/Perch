import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// Matches a markdown task item and captures its state and text.
final RegExp _checkbox = RegExp(r'^(\s*[-*+]\s+)\[([ xX])\]\s+(.*)$');

/// The note, rendered. Board 3d — headings, bullets and interactive checkboxes
/// that write straight back into the markdown (B8).
///
/// Task lines are drawn here rather than by the markdown renderer, because the
/// renderer has no way to tell which line a checkbox came from — and without
/// that a tick cannot be persisted.
class NoteView extends StatelessWidget {
  const NoteView({required this.markdown, this.onToggle, super.key});

  final String markdown;

  /// Called with the whole note, rewritten, when a checkbox is tapped.
  final ValueChanged<String>? onToggle;

  /// Flips the checkbox on [line] and returns the new note.
  static String toggleAt(String markdown, int line) {
    final List<String> lines = markdown.split('\n');
    if (line < 0 || line >= lines.length) return markdown;
    final RegExpMatch? m = _checkbox.firstMatch(lines[line]);
    if (m == null) return markdown;
    final bool checked = m.group(2)!.toLowerCase() == 'x';
    lines[line] = '${m.group(1)}[${checked ? ' ' : 'x'}] ${m.group(3)}';
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    if (markdown.trim().isEmpty) {
      return Text(
        'No note yet.',
        style: PerchType.note.copyWith(color: c.onSurfaceMuted),
      );
    }

    // Prose and task lines alternate; each run of prose goes to the renderer in
    // one piece so paragraphs and lists still work.
    final List<Widget> blocks = <Widget>[];
    final List<String> prose = <String>[];
    final List<String> lines = markdown.split('\n');

    void flushProse() {
      final String text = prose.join('\n').trim();
      prose.clear();
      if (text.isEmpty) return;
      blocks.add(
        MarkdownBody(
          data: text,
          selectable: false,
          styleSheet: _styleSheet(c),
        ),
      );
    }

    final List<Widget> tasks = <Widget>[];
    void flushTasks() {
      if (tasks.isEmpty) return;
      blocks.add(
        Padding(
          padding: EdgeInsets.only(top: blocks.isEmpty ? 0 : Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 9,
            children: List<Widget>.of(tasks),
          ),
        ),
      );
      tasks.clear();
    }

    for (int i = 0; i < lines.length; i++) {
      final RegExpMatch? m = _checkbox.firstMatch(lines[i]);
      if (m == null) {
        flushTasks();
        prose.add(lines[i]);
        continue;
      }
      flushProse();
      final int index = i;
      tasks.add(
        _Task(
          label: m.group(3)!,
          checked: m.group(2)!.toLowerCase() == 'x',
          onTap: onToggle == null
              ? null
              : () => onToggle!(toggleAt(markdown, index)),
        ),
      );
    }
    flushProse();
    flushTasks();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }

  MarkdownStyleSheet _styleSheet(PerchColors c) {
    return MarkdownStyleSheet(
      p: PerchType.note.copyWith(fontSize: 14, height: 1.6, color: c.onSurface),
      h1: PerchType.title.copyWith(color: c.onSurface),
      h2: PerchType.titleMedium.copyWith(fontSize: 15, color: c.onSurface),
      h3: PerchType.titleSmall.copyWith(color: c.onSurface),
      listBullet: PerchType.note.copyWith(fontSize: 14, color: c.onSurface),
      code: PerchType.monoLabel.copyWith(fontSize: 12.5, color: c.onSurface),
      codeblockDecoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: Radii.chipR,
      ),
      blockquoteDecoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: Radii.chipR,
      ),
      a: PerchType.note.copyWith(fontSize: 14, color: c.accent),
      del: PerchType.note.copyWith(
        fontSize: 14,
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

/// One task line: a 19dp box, and the text struck through once it is ticked.
class _Task extends StatelessWidget {
  const _Task({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Semantics(
      checked: checked,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Space.row,
          children: <Widget>[
            Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: checked ? c.primary : null,
                border: checked ? null : Border.all(color: c.outline, width: 1.8),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
              child: checked
                  ? Icon(Icons.check_rounded, size: 13, color: c.onPrimary)
                  : null,
            ),
            Expanded(
              child: Text(
                label,
                style: PerchType.note.copyWith(
                  fontSize: 13.5,
                  color: checked ? c.onSurfaceVariant : c.onSurface,
                  decoration: checked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
