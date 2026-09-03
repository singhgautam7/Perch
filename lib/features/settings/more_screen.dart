import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/db/settings_repository.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/perch_icons.dart';
import '../stats/stats_providers.dart';
import 'about_screen.dart';
import 'appearance_screen.dart';
import 'dev_tools_screen.dart';
import 'import_export_screen.dart';
import 'permissions_screen.dart';
import 'privacy_screen.dart';
import 'settings_widgets.dart';
import 'tags_screen.dart';

/// Board 2e — three short groups, each row showing its current value on the
/// right so most questions are answered without opening anything.
class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  int _versionTaps = 0;

  void _push(Widget screen) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final AppSettings s = ref.watch(settingsProvider);
    final SettingsController controller = ref.read(settingsProvider.notifier);
    final int? tagCount = ref.watch(statsProvider).valueOrNull?.tags;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.screen,
          0,
          Space.screen,
          Space.bottomSafe,
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, Space.lg),
            child: Text(
              'More',
              style: PerchType.title.copyWith(fontSize: 22, color: c.onSurface),
            ),
          ),

          SettingsGroup(
            label: 'General',
            children: <Widget>[
              SettingsChoiceRow<LandingTab>(
                label: 'Open on launch',
                value:
                    'Default · '
                    '${s.landingTab == LandingTab.folders ? 'Folders' : 'Links'}',
                selected: s.landingTab,
                onChanged: controller.setLandingTab,
                // The nav's own glyphs, so the row and the destination match.
                options: <(LandingTab, String, Widget Function(Color))>[
                  (
                    LandingTab.links,
                    'Links',
                    (Color c) => PerchIcon(PerchGlyph.links, color: c),
                  ),
                  (
                    LandingTab.folders,
                    'Folders',
                    (Color c) => PerchIcon(PerchGlyph.folders, color: c),
                  ),
                ],
              ),
              SettingsRow(
                icon: Icons.view_agenda_outlined,
                label: 'Default view mode',
                value: s.viewMode.label,
                onTap: () => _cycleViewMode(controller, s),
              ),
              SettingsRow(
                icon: Icons.palette_outlined,
                label: 'Appearance',
                value: '${s.family.name} · ${_modeLabel(s.themeMode)}',
                onTap: () => _push(const AppearanceScreen()),
              ),
            ],
          ),

          SettingsGroup(
            label: 'Your data',
            children: <Widget>[
              SettingsRow(
                icon: Icons.swap_vert_rounded,
                label: 'Import / Export',
                onTap: () => _push(const ImportExportScreen()),
              ),
              SettingsRow(
                icon: Icons.sell_outlined,
                label: 'Tags',
                value: tagCount == null ? null : '$tagCount',
                onTap: () => _push(const TagsScreen()),
              ),
              SettingsRow(
                icon: Icons.key_outlined,
                label: 'Permissions',
                onTap: () => _push(const PermissionsScreen()),
              ),
            ],
          ),

          SettingsGroup(
            label: 'About Perch',
            children: <Widget>[
              SettingsRow(
                icon: Icons.shield_outlined,
                label: 'Privacy',
                value: 'Local only',
                onTap: () => _push(const PrivacyScreen()),
              ),
              SettingsRow(
                icon: Icons.info_outline_rounded,
                label: 'About',
                onTap: () => _push(const AboutScreen()),
              ),
            ],
          ),

          // Seven taps on the version line reveals Dev tools, and it stays
          // until toggled off.
          if (s.devTools)
            SettingsGroup(
              label: 'Dev tools',
              children: <Widget>[
                SettingsRow(
                  icon: Icons.storage_rounded,
                  label: 'Database explorer',
                  onTap: () => _push(const DevToolsScreen()),
                ),
                SettingsRow(
                  icon: Icons.visibility_off_outlined,
                  label: 'Hide dev tools',
                  onTap: () {
                    controller.setDevTools(value: false);
                    setState(() => _versionTaps = 0);
                  },
                ),
              ],
            ),

          GestureDetector(
            onTap: () {
              setState(() => _versionTaps++);
              if (_versionTaps >= 7 && !s.devTools) {
                controller.setDevTools(value: true);
              }
            },
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.only(top: 2),
              child: VersionLine(),
            ),
          ),
        ],
      ),
    );
  }

  void _cycleViewMode(SettingsController controller, AppSettings s) {
    final LinkViewMode next = LinkViewMode
        .values[(s.viewMode.index + 1) % LinkViewMode.values.length];
    controller.setViewMode(next);
  }

  static String _modeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };
}

/// `Perch 1.0.0 · build 118` — read from the package at runtime, never
/// hardcoded.
class VersionLine extends StatelessWidget {
  const VersionLine({super.key});

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
        final PackageInfo? info = snapshot.data;
        return Text(
          info == null
              ? 'Perch'
              : 'Perch ${info.version} · build ${info.buildNumber}',
          textAlign: TextAlign.center,
          style: PerchType.monoLabel.copyWith(color: c.onSurfaceMuted),
        );
      },
    );
  }
}
