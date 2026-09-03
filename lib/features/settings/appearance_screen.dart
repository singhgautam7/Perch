import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/settings_repository.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'settings_widgets.dart';

/// Board 1i — every theme card is a miniature of the app, so the choice is made
/// on the thing itself rather than on swatches.
///
/// Light / Dark / System is the mode switch. AMOLED is not a mode but a
/// true-black toggle that appears under it only while dark is in effect.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final AppSettings s = ref.watch(settingsProvider);
    final SettingsController controller = ref.read(settingsProvider.notifier);
    final bool darkInEffect =
        s.themeMode == ThemeMode.dark ||
        (s.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return SettingsScaffold(
      title: 'Appearance',
      children: <Widget>[
        _ModeSwitch(
          mode: s.themeMode,
          onChanged: (ThemeMode m) =>
              controller.setThemeMode(ThemeModeSetting.from(m)),
        ),
        const SizedBox(height: Space.md),

        if (darkInEffect && s.family.hasAmoled)
          _ToggleCard(
            title: 'True black (AMOLED)',
            subtitle: 'Appears only while dark is active',
            value: s.amoled,
            onChanged: (bool v) => controller.setAmoled(value: v),
            leading: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF000000),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: c.outline),
              ),
            ),
          ),
        const SizedBox(height: Space.lg),

        for (final ThemeFamily family in ThemeFamily.all) ...<Widget>[
          _ThemeCard(
            family: family,
            selected: !s.dynamicColor && family.id == s.familyId,
            tone: darkInEffect
                ? (s.amoled && family.hasAmoled ? Tone.amoled : Tone.dark)
                : Tone.light,
            onTap: () {
              controller.setDynamicColor(value: false);
              controller.setFamily(family.id);
            },
          ),
          const SizedBox(height: Space.row),
        ],

        const SizedBox(height: Space.sm),
        _ToggleCard(
          title: 'Dynamic color',
          subtitle: 'Follows your wallpaper',
          value: s.dynamicColor,
          onChanged: (bool v) => controller.setDynamicColor(value: v),
        ),
        const SizedBox(height: Space.row),
        _ToggleCard(
          title: 'Blur behind nav',
          subtitle: 'Prettier, slightly heavier on battery',
          value: s.blur,
          onChanged: (bool v) => controller.setBlur(value: v),
        ),
      ],
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
      height: 44,
      padding: const EdgeInsets.all(Space.xs),
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: Radii.fullR,
      ),
      child: Row(
        children: <Widget>[
          // Board order: Light · Dark · System, not the enum's own.
          for (final ThemeMode m in const <ThemeMode>[
            ThemeMode.light,
            ThemeMode.dark,
            ThemeMode.system,
          ])
            Expanded(
              child: Semantics(
                button: true,
                selected: m == mode,
                child: InkWell(
                  onTap: () => onChanged(m),
                  borderRadius: Radii.fullR,
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.fast),
                    decoration: BoxDecoration(
                      color: m == mode ? c.surface : Colors.transparent,
                      borderRadius: Radii.fullR,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      switch (m) {
                        ThemeMode.light => 'Light',
                        ThemeMode.dark => 'Dark',
                        ThemeMode.system => 'System',
                      },
                      style: PerchType.label.copyWith(
                        fontSize: 13,
                        color: m == mode ? c.onSurface : c.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.leading,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Space.md),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        spacing: Space.md,
        children: <Widget>[
          ?leading,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: PerchType.titleSmall.copyWith(color: c.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: PerchType.bodySmall.copyWith(
                    fontSize: 11.5,
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// A miniature of the app in that theme: top bar, a row, the nav pill.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.family,
    required this.selected,
    required this.tone,
    required this.onTap,
  });

  final ThemeFamily family;
  final bool selected;
  final Tone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors outer = context.colors;
    final PerchColors p = family.colors(tone);

    return Semantics(
      button: true,
      selected: selected,
      label: '${family.name} theme',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(Space.md),
          decoration: BoxDecoration(
            color: outer.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? outer.primary : outer.outline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            spacing: 14,
            children: <Widget>[
              _Miniature(p: p),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      family.name,
                      style: PerchType.titleMedium.copyWith(
                        color: outer.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      family.hasAmoled
                          ? 'Light · Dark · True black'
                          : 'Light · Dark',
                      style: PerchType.monoSmall.copyWith(
                        color: outer.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: outer.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Miniature extends StatelessWidget {
  const _Miniature({required this.p});

  final PerchColors p;

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height, Color color) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );

    return Container(
      width: 78,
      height: 62,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          bar(26, 5, p.onSurface),
          const SizedBox(height: 6),
          Container(
            height: 18,
            decoration: BoxDecoration(
              color: p.surfaceContainer,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: p.outline),
            ),
          ),
          const Spacer(),
          Row(
            spacing: 3,
            children: <Widget>[
              Container(
                height: 10,
                width: 22,
                decoration: BoxDecoration(
                  color: p.primaryContainer,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              bar(6, 6, p.iconMuted),
              bar(6, 6, p.iconMuted),
              const Spacer(),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: p.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
