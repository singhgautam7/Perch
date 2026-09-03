import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'more_screen.dart';
import 'settings_widgets.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return SettingsScaffold(
      title: 'About',
      children: <Widget>[
        const SizedBox(height: Space.xl),
        Center(
          child: Text(
            'Perch',
            style: PerchType.display.copyWith(fontSize: 44, color: c.onSurface),
          ),
        ),
        const SizedBox(height: Space.sm),
        Center(
          child: Text(
            'calm · quick · quietly premium',
            style: PerchType.monoLabel.copyWith(color: c.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: Space.xl),
        const Center(child: VersionLine()),
        const SizedBox(height: Space.section),
        const SizedBox(height: Space.lg),
        Text(
          'Perch is a local-first link manager. Everything you save lives in a '
          'single database file on this device. There is no account and no '
          'server.',
          textAlign: TextAlign.center,
          style: PerchType.body.copyWith(color: c.onSurfaceVariant),
        ),
      ],
    );
  }
}
