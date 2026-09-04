import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'app_icon_button.dart';

/// Board 3a — the one header. Links, Folders, Search, Stats, More, Add/Edit,
/// Link detail and every settings sub-page use this and nothing else.
///
/// Left: an optional back button then the screen title in Instrument Sans 22.
/// Right: up to four identical circular icon-buttons, 8dp apart. Margins are
/// fixed — 20dp side, 14dp above the title, 12dp below the header — so nothing
/// about this block differs between screens.
class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.title,
    this.onBack,
    this.actions = const <Widget>[],
    this.backLabel = 'Back',
    this.foreground,
    this.background,
    super.key,
  });

  final String title;

  /// Null on a tab root, which has nowhere to go back to.
  final VoidCallback? onBack;
  final List<Widget> actions;
  final String backLabel;

  /// Board 3f — inside a coloured folder the title and back button take the
  /// folder's accent.
  final Color? foreground;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final bool hasBack = onBack != null;

    return ColoredBox(
      color: background ?? Colors.transparent,
      child: Padding(
        // The buttons carry a 48dp target around a 40dp circle, so the inset is
        // 16 wherever one sits — that puts the *visual* edge on the 20dp margin.
        padding: EdgeInsets.fromLTRB(
          hasBack ? Space.lg : Space.screen,
          14,
          actions.isEmpty ? Space.screen : Space.lg,
          Space.md,
        ),
        child: Row(
          children: <Widget>[
            if (hasBack) ...<Widget>[
              AppIconButton(
                icon: Icons.arrow_back_rounded,
                onPressed: onBack,
                semanticLabel: backLabel,
                tint: foreground,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                title,
                style: PerchType.headerTitle.copyWith(
                  color: foreground ?? c.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}
