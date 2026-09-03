import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_button.dart';

/// `＋ New folder in Reading`, which flips into the name field in place.
///
/// It is scoped to wherever you are: the new folder's parent is the location
/// showing it.
class NewFolderRow extends StatefulWidget {
  const NewFolderRow({
    required this.locationName,
    required this.onCreate,
    super.key,
  });

  /// "Root", or the folder being viewed.
  final String locationName;
  final ValueChanged<String> onCreate;

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
    return AnimatedSize(
      duration: Motion.of(context, Motion.folderOpen),
      curve: Motion.curveOf(context, Motion.decelerate),
      alignment: Alignment.topCenter,
      child: _editing ? _field(c) : _pill(c),
    );
  }

  Widget _pill(PerchColors c) {
    return Semantics(
      button: true,
      label: 'New folder in ${widget.locationName}',
      child: Material(
        color: c.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _open,
          child: SizedBox(
            height: 52,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                spacing: 11,
                children: <Widget>[
                  Icon(Icons.add_rounded, size: 20, color: c.accent),
                  Expanded(
                    child: Text(
                      'New folder in ${widget.locationName}',
                      style: PerchType.titleMedium.copyWith(
                        color: c.onPrimaryContainer,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(PerchColors c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.primary, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text.rich(
            TextSpan(
              text: 'New folder in ',
              style: PerchType.monoSmall.copyWith(
                fontSize: 10.5,
                color: c.onSurfaceVariant,
              ),
              children: <InlineSpan>[
                TextSpan(
                  text: widget.locationName,
                  style: TextStyle(color: c.accent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          Row(
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
        ],
      ),
    );
  }
}
