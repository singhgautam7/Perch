import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// Board 3b — the note toolbar: bold, italic, bullets, numbered, checkbox.
enum NoteTool { bold, italic, heading, bullet, numbered, checkbox, link }

/// The five the board draws, in order.
const List<NoteTool> kNoteTools = <NoteTool>[
  NoteTool.bold,
  NoteTool.italic,
  NoteTool.bullet,
  NoteTool.numbered,
  NoteTool.checkbox,
];

/// The markdown note field. Notes are stored as raw markdown; the toolbar just
/// inserts the marks so the user never has to remember them.
class MarkdownEditor extends StatelessWidget {
  const MarkdownEditor({
    required this.controller,
    this.tools = kNoteTools,
    this.hint = 'Markdown supported — headings, lists, checkboxes',
    this.minLines = 3,
    this.maxLines = 12,
    this.focusNode,
    super.key,
  });

  final TextEditingController controller;
  final List<NoteTool> tools;
  final String hint;
  final int minLines;
  final int maxLines;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(Space.sm),
          decoration: BoxDecoration(
            color: c.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.outline),
          ),
          child: Row(
            spacing: 6,
            children: <Widget>[
              for (final NoteTool tool in tools)
                _ToolButton(tool: tool, onTap: () => _apply(tool)),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          constraints: const BoxConstraints(minHeight: 78),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.outline),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            minLines: minLines,
            maxLines: maxLines,
            keyboardType: TextInputType.multiline,
            style: PerchType.note.copyWith(fontSize: 13, color: c.onSurface),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: hint,
              hintStyle: PerchType.note.copyWith(
                fontSize: 13,
                color: c.onSurfaceMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Wraps the selection for inline marks, or prefixes the line for block ones.
  void _apply(NoteTool tool) {
    final TextEditingValue value = controller.value;
    final TextSelection selection = value.selection;
    final String text = value.text;
    if (!selection.isValid) return;

    final (String? wrap, String? prefix) = switch (tool) {
      NoteTool.bold => ('**', null),
      NoteTool.italic => ('*', null),
      NoteTool.link => ('[', null),
      NoteTool.heading => (null, '## '),
      NoteTool.bullet => (null, '- '),
      NoteTool.numbered => (null, '1. '),
      NoteTool.checkbox => (null, '- [ ] '),
    };

    if (wrap != null) {
      final String selected = selection.textInside(text);
      final String close = tool == NoteTool.link ? '](url)' : wrap;
      final String replacement = '$wrap$selected$close';
      controller.value = value.copyWith(
        text: selection.textBefore(text) + replacement + selection.textAfter(text),
        selection: TextSelection.collapsed(
          offset: selection.start + wrap.length + selected.length,
        ),
      );
      return;
    }

    // Block marks go at the start of the line the caret is on.
    final int lineStart = text.lastIndexOf('\n', selection.start - 1) + 1;
    controller.value = value.copyWith(
      text: text.replaceRange(lineStart, lineStart, prefix!),
      selection: TextSelection.collapsed(
        offset: selection.start + prefix.length,
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.tool, required this.onTap});

  final NoteTool tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Semantics(
      button: true,
      label: _label(tool),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 32,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: c.outline),
          ),
          // The glyph is the mark itself, so nothing has to be learned.
          child: Text(
            _glyph(tool),
            style: PerchType.label
                .copyWith(
                  fontSize: 12.5,
                  color: c.onSurface,
                  fontStyle: tool == NoteTool.italic
                      ? FontStyle.italic
                      : FontStyle.normal,
                )
                .weight(tool == NoteTool.bold ? 700 : 500),
          ),
        ),
      ),
    );
  }

  static String _glyph(NoteTool tool) => switch (tool) {
    NoteTool.bold => 'B',
    NoteTool.italic => 'I',
    NoteTool.heading => 'H',
    NoteTool.bullet => '\u2022',
    NoteTool.numbered => '1.',
    NoteTool.checkbox => '\u2611',
    NoteTool.link => '\u{1F517}',
  };

  static String _label(NoteTool tool) => switch (tool) {
    NoteTool.bold => 'Bold',
    NoteTool.italic => 'Italic',
    NoteTool.heading => 'Heading',
    NoteTool.bullet => 'Bullet list',
    NoteTool.numbered => 'Numbered list',
    NoteTool.checkbox => 'Checklist item',
    NoteTool.link => 'Link',
  };
}
