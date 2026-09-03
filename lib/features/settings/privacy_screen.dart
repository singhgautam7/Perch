import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'import_export_screen.dart';
import 'settings_widgets.dart';

/// Board 1i — leads with the sentence from the brief, at display size, then
/// three claims a reader can check.
///
/// Import/Export appears here too, because "where does my data live" and "how
/// do I take it with me" are the same question.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const List<(String, String)> _claims = <(String, String)>[
    ('No account, ever', 'There is nothing to sign in to.'),
    ('No analytics, no ads', 'No third-party SDKs are bundled.'),
    (
      'One network call, and you cause it',
      "Saving a link fetches that page's preview. Nothing else leaves your "
          'phone.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return SettingsScaffold(
      title: 'Privacy',
      children: <Widget>[
        Text(
          'Perch stores everything on your device.',
          style: PerchType.display.copyWith(
            fontSize: 30,
            height: 1.15,
            color: c.onSurface,
          ),
        ),
        const SizedBox(height: Space.md),
        Text(
          'Metadata is fetched directly from the link you save — there is no '
          'Perch server, so nothing is ever sent to us.',
          style: PerchType.body.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: Space.section),
        for (final (String, String) claim in _claims) ...<Widget>[
          _Claim(title: claim.$1, body: claim.$2),
          const SizedBox(height: Space.row),
        ],
        const SizedBox(height: Space.lg),
        const BackupCard(),
      ],
    );
  }
}

class _Claim extends StatelessWidget {
  const _Claim({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
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
          Icon(Icons.check_rounded, size: 18, color: c.success),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: PerchType.titleSmall.copyWith(color: c.onSurface),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
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
    );
  }
}
