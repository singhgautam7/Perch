import 'package:flutter/material.dart';

import '../../core/db/settings_repository.dart';
import 'app_icon_button.dart';
import 'app_menu.dart';

/// Board 3a — the view switcher is a menu anchored to the icon-button, with a
/// radio item per mode and the current one checked.
///
/// The glyph is the mode itself: three bars for Large, two for Minimal, a 2×2
/// for Grid. The selection is one app-wide preference, so it applies to the
/// links inside a folder too.
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
    return Builder(
      builder: (BuildContext anchor) => AppIconButton(
        semanticLabel: '${mode.label} view. Change how links are drawn',
        child: (Color color) => ViewModeGlyph(mode: mode, color: color),
        onPressed: () async {
          final LinkViewMode? picked = await showAppMenu<LinkViewMode>(
            context: anchor,
            anchorContext: anchor,
            minWidth: 206,
            entries: <AppMenuEntry<LinkViewMode>>[
              for (final LinkViewMode m in LinkViewMode.values)
                AppMenuEntry<LinkViewMode>(
                  value: m,
                  label: m.menuLabel,
                  selected: m == mode,
                  radio: true,
                ),
            ],
          );
          if (picked != null && picked != mode) onChanged(picked);
        },
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
