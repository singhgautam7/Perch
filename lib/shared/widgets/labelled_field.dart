import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// Boards 3b and 3c — the labelled box every text field on the Add/Edit screen
/// and in the sheets sits in: a mono caps label, then the value.
///
/// The outline turns accent while the field is the one being edited, which is
/// the only state these fields have.
class LabelledField extends StatelessWidget {
  const LabelledField({
    required this.label,
    required this.child,
    this.focused = false,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
    super.key,
  });

  final String label;
  final Widget child;
  final bool focused;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: focused ? c.primary : c.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: PerchType.sectionHeader.copyWith(
              fontSize: 9.5,
              letterSpacing: 0.86,
              color: focused ? c.accent : c.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 5),
          child,
        ],
      ),
    );
  }
}

/// A bare text field for use inside a [LabelledField] — no border of its own,
/// because the box already has one.
class PlainTextField extends StatelessWidget {
  const PlainTextField({
    required this.controller,
    this.hint,
    this.style,
    this.autofocus = false,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String? hint;
  final TextStyle? style;
  final bool autofocus;
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final TextStyle base =
        style ?? PerchType.body.copyWith(fontSize: 14, color: c.onSurface);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: keyboardType,
      minLines: minLines,
      maxLines: maxLines,
      autocorrect: keyboardType != TextInputType.url,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: base,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        hintText: hint,
        hintStyle: base.copyWith(color: c.onSurfaceMuted),
      ),
    );
  }
}

/// The seven-swatch colour choice from board 3c, shared by tag create, tag edit
/// and folder colour.
class ColorSwatchRow extends StatelessWidget {
  const ColorSwatchRow({
    required this.selected,
    required this.onChanged,
    this.size = 26,
    this.allowNone = true,
    super.key,
  });

  /// An index into `PerchColors.tagHues`, or null for the theme accent.
  final int? selected;
  final ValueChanged<int?> onChanged;
  final double size;

  /// Offers the "no colour set" swatch, which falls back to the accent.
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Wrap(
      spacing: Space.row,
      runSpacing: Space.sm,
      children: <Widget>[
        for (int i = 0; i < PerchColors.tagHues.length; i++)
          _Swatch(
            color: c.tagColor(i),
            selected: selected == i,
            size: size,
            label: 'Colour ${i + 1}',
            onTap: () => onChanged(i),
          ),
        if (allowNone)
          _Swatch(
            color: c.onSurfaceMuted,
            selected: selected == null,
            size: size,
            label: 'No colour',
            onTap: () => onChanged(null),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.size,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final double size;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: size + 8,
          height: size + 8,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: c.onSurface, width: 2)
                    : null,
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: size * 0.55, color: c.surface)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
