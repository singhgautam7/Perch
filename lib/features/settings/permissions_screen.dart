import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'settings_widgets.dart';

/// What Perch asks the OS for, and what it deliberately does not.
class PermissionsScreen extends StatelessWidget {
  const PermissionsScreen({super.key});

  static const List<(IconData, String, String, bool)> _rows =
      <(IconData, String, String, bool)>[
        (
          Icons.wifi_rounded,
          'Internet',
          'Used only to fetch the preview for a link you save.',
          true,
        ),
        (
          Icons.ios_share_rounded,
          'Share sheet',
          'Lets other apps hand Perch a link. No permission prompt — Android '
              'routes it when you pick Perch.',
          true,
        ),
        (
          Icons.photo_library_outlined,
          'Photos and files',
          'Not requested. Export writes through the system share sheet.',
          false,
        ),
        (
          Icons.location_on_outlined,
          'Location, contacts, camera',
          'Not requested, and never will be.',
          false,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return SettingsScaffold(
      title: 'Permissions',
      children: <Widget>[
        Text(
          'Perch declares one permission. The rest of this list is here so you '
          'can check what it does not ask for.',
          style: PerchType.body.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: Space.xl),
        for (final (IconData, String, String, bool) row in _rows) ...<Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.outline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.md,
              children: <Widget>[
                Icon(
                  row.$1,
                  size: 20,
                  color: row.$4 ? c.accent : c.onSurfaceMuted,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        spacing: Space.sm,
                        children: <Widget>[
                          Text(
                            row.$2,
                            style: PerchType.titleSmall.copyWith(
                              color: c.onSurface,
                            ),
                          ),
                          Text(
                            row.$4 ? 'USED' : 'NOT USED',
                            style: PerchType.monoSmall.copyWith(
                              color: row.$4 ? c.accent : c.onSurfaceMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        row.$3,
                        style: PerchType.bodySmall.copyWith(
                          height: 1.5,
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.row),
        ],
      ],
    );
  }
}
