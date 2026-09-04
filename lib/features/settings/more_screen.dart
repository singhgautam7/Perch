import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/db/settings_repository.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/router/router.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/perch_icons.dart';
import '../../shared/widgets/view_mode_button.dart';
import '../stats/stats_providers.dart';
import 'settings_widgets.dart';

/// Board 2e — three short groups, each row showing its current value on the
/// right so most questions are answered without opening anything.
class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  int _versionTaps = 0;

  @override
  Widget build(BuildContext context) {
    final AppSettings s = ref.watch(settingsProvider);
    final SettingsController controller = ref.read(settingsProvider.notifier);
    final int? tagCount = ref.watch(statsProvider).valueOrNull?.tags;

    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          const AppHeader(title: 'More'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.screen,
                0,
                Space.screen,
                Space.bottomSafe,
              ),
              children: <Widget>[

          // Board 3g — one flat list of rows, each showing its current value on
          // the line below, so nothing needs an icon column or a group header.
          SettingsListRow(
            label: 'Appearance',
            value: '${s.family.name} · ${_modeLabel(s.themeMode)}',
            onTap: () => context.push(Routes.appearance),
          ),
          const SizedBox(height: Space.sm),
          SettingsListRow(
            label: 'Tags',
            value: tagCount == null ? null : plural(tagCount, 'tag'),
            onTap: () => context.push(Routes.tags),
          ),
          const SizedBox(height: Space.sm),
          SettingsListRow(
            label: 'Data',
            value: 'Export, import',
            onTap: () => context.push(Routes.data),
          ),
          const SizedBox(height: Space.sm),
          SettingsListRow(
            label: 'Open on launch',
            value: s.landingTab == LandingTab.folders ? 'Folders' : 'Links',
            onTap: () => _pickLandingTab(s, controller),
          ),
          const SizedBox(height: Space.sm),
          SettingsListRow(
            label: 'Default view',
            value: s.viewMode.label,
            onTap: () => _pickViewMode(s, controller),
          ),
          const SizedBox(height: Space.sm),
          SettingsListRow(
            label: 'Privacy',
            value: 'Everything stays on this device',
            onTap: () => context.push(Routes.privacy),
          ),
          const SizedBox(height: Space.sm),
          SettingsListRow(
            label: 'Permissions',
            value: 'Internet only',
            onTap: () => context.push(Routes.permissions),
          ),
          const SizedBox(height: Space.sm),
          SettingsListRow(
            label: 'About Perch',
            value: 'free, no accounts',
            onTap: () => context.push(Routes.about),
          ),
          const SizedBox(height: Space.lg),

          // Seven taps on the version line reveals Dev tools, and it stays
          // until toggled off.
          if (s.devTools) ...<Widget>[
            SettingsListRow(
              label: 'Database explorer',
              value: 'Dev tools',
              onTap: () => context.push(Routes.devTools),
            ),
            const SizedBox(height: Space.sm),
            SettingsListRow(
              label: 'Hide dev tools',
              onTap: () {
                controller.setDevTools(value: false);
                setState(() => _versionTaps = 0);
              },
            ),
            const SizedBox(height: Space.lg),
          ],

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
          ),
        ],
      ),
    );
  }

  /// Which tab Perch opens on. Two choices do not earn a screen — they get the
  /// shared option sheet, like every other single choice in the app.
  Future<void> _pickLandingTab(
    AppSettings s,
    SettingsController controller,
  ) async {
    final LandingTab? picked = await showOptionSheet<LandingTab>(
      context: context,
      title: 'Open on launch',
      description: 'Where Perch lands when you open it.',
      selected: s.landingTab,
      options: <SheetOption<LandingTab>>[
        SheetOption<LandingTab>(
          value: LandingTab.links,
          label: 'Links',
          description: 'Everything you have saved, newest first',
          leading: (Color c) => PerchIcon(PerchGlyph.links, color: c),
        ),
        SheetOption<LandingTab>(
          value: LandingTab.folders,
          label: 'Folders',
          description: 'The structure you filed it into',
          leading: (Color c) => PerchIcon(PerchGlyph.folders, color: c),
        ),
      ],
    );
    if (picked != null) await controller.setLandingTab(picked);
  }

  Future<void> _pickViewMode(
    AppSettings s,
    SettingsController controller,
  ) async {
    final LinkViewMode? picked = await showOptionSheet<LinkViewMode>(
      context: context,
      title: 'Default view mode',
      description: 'How link cards are drawn in Links and inside a folder.',
      selected: s.viewMode,
      options: <SheetOption<LinkViewMode>>[
        SheetOption<LinkViewMode>(
          value: LinkViewMode.large,
          label: 'Large',
          description: 'Thumbnail, tags and a line of the note',
          leading: (Color c) =>
              ViewModeGlyph(mode: LinkViewMode.large, color: c),
        ),
        SheetOption<LinkViewMode>(
          value: LinkViewMode.minimal,
          label: 'Minimal',
          description: 'Title and domain, densely packed',
          leading: (Color c) =>
              ViewModeGlyph(mode: LinkViewMode.minimal, color: c),
        ),
        SheetOption<LinkViewMode>(
          value: LinkViewMode.grid,
          label: 'Grid',
          description: 'Two up, led by the preview image',
          leading: (Color c) =>
              ViewModeGlyph(mode: LinkViewMode.grid, color: c),
        ),
      ],
    );
    if (picked != null) await controller.setViewMode(picked);
  }

  static String _modeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };
}

/// The app's real version and build, read from the installed package.
///
/// Resolved once and cached: a `FutureBuilder` in `build` re-reads the platform
/// on every rebuild and blanks the line each time it does.
final FutureProvider<PackageInfo> packageInfoProvider =
    FutureProvider<PackageInfo>((Ref ref) => PackageInfo.fromPlatform());

/// `Perch 1.0.0 · build 118` — never hardcoded.
class VersionLine extends ConsumerWidget {
  const VersionLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final PackageInfo? info = ref.watch(packageInfoProvider).valueOrNull;
    return Text(
      info == null
          ? 'Perch'
          : 'Perch ${info.version} · build ${info.buildNumber}',
      textAlign: TextAlign.center,
      style: PerchType.monoLabel.copyWith(color: c.onSurfaceMuted),
    );
  }
}
