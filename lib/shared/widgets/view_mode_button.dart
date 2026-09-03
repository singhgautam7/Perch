import 'package:flutter/material.dart';

import '../../core/db/settings_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';

/// The top-bar control that shows — and changes — how links are drawn.
///
/// The glyph is the mode itself: three bars for Large, two for Minimal, a 2×2
/// for Grid. Tapping moves to the next mode.
class ViewModeButton extends StatelessWidget {
  const ViewModeButton({
    required this.mode,
    required this.onChanged,
    super.key,
  });

  final LinkViewMode mode;
  final ValueChanged<LinkViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final LinkViewMode next = LinkViewMode
        .values[(mode.index + 1) % LinkViewMode.values.length];

    return Semantics(
      button: true,
      label: '${mode.label} view. Switch to ${next.label}',
      child: SizedBox(
        width: IconSpec.tapTarget,
        height: IconSpec.tapTarget,
        child: Center(
          child: Material(
            color: c.surfaceContainerHigh,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onChanged(next),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(child: ViewModeGlyph(mode: mode, color: c.icon)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ViewModeGlyph extends StatelessWidget {
  const ViewModeGlyph({required this.mode, required this.color, super.key});

  final LinkViewMode mode;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.all(Radius.circular(2)),
      ),
    );

    return switch (mode) {
      LinkViewMode.large => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 2.5,
        children: <Widget>[bar(15, 2.5), bar(15, 2.5), bar(15, 2.5)],
      ),
      LinkViewMode.minimal => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: <Widget>[bar(15, 2), bar(15, 2)],
      ),
      // Constrained so the four dots wrap into a 2×2.
      LinkViewMode.grid => SizedBox(
        width: 14.5,
        child: Wrap(
          spacing: 2.5,
          runSpacing: 2.5,
          children: <Widget>[
            for (int i = 0; i < 4; i++)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.all(Radius.circular(1.5)),
                ),
              ),
          ],
        ),
      ),
    };
  }
}
