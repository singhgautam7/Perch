import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/dashed_border.dart';

/// Board 3a — `＋ New folder`, one component used identically on the Folders
/// tab and inside the folder picker. It flips into the name field in place, and
/// is scoped to wherever you are: the new folder's parent is the location
/// showing it.
class NewFolderRow extends StatefulWidget {
  const NewFolderRow({
    required this.onCreate,
    this.label = 'New folder',
    this.tint,
    super.key,
  });

  final ValueChanged<String> onCreate;
  final String label;

  /// Board 3f — inside a coloured folder the row takes that folder's accent.
  final FolderTint? tint;

  @override
  State<NewFolderRow> createState() => _NewFolderRowState();
}

class _NewFolderRowState extends State<NewFolderRow> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _editing = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _open() {
    setState(() => _editing = true);
    _focus.requestFocus();
  }

  void _submit() {
    final String name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _editing = false);
      return;
    }
    widget.onCreate(name);
    _controller.clear();
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final FolderTint tint = widget.tint ?? c.folderTint(null);
    return AnimatedSize(
      duration: Motion.of(context, Motion.folderOpen),
      curve: Motion.curveOf(context, Motion.decelerate),
      alignment: Alignment.topCenter,
      child: _editing ? _field(c, tint) : _pill(c, tint),
    );
  }

  Widget _pill(PerchColors c, FolderTint tint) {
    return Semantics(
      button: true,
      label: widget.label,
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(18),
        child: CustomPaint(
          foregroundPainter: DashedBorderPainter(
            tint.accent.withValues(alpha: 0.5),
            radius: 18,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: Space.md,
            ),
            decoration: BoxDecoration(
              color: tint.container,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              spacing: Space.row,
              children: <Widget>[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: tint.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_rounded, size: 15, color: c.onPrimary),
                ),
                Expanded(
                  child: Text(
                    widget.label,
                    style: PerchType.label
                        .copyWith(fontSize: 13.5, color: tint.onContainer)
                        .weight(600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(PerchColors c, FolderTint tint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.accent),
      ),
      child: Row(
        spacing: 9,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onTapOutside: (_) => _submit(),
              style: PerchType.titleMedium.copyWith(color: c.onSurface),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Folder name',
              ),
            ),
          ),
          AppButton(label: 'Create', onPressed: _submit, compact: true),
        ],
      ),
    );
  }
}
