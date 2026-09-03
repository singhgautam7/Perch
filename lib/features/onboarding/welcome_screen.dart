import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/settings_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/folder_card.dart';
import '../../shared/widgets/tag_chip.dart';
import 'perch_hero.dart';

/// Board 1c — three steps, every one skippable from the first.
///
/// The value prop is set in Instrument Serif at 42px: the only place in the app
/// where type gets this large, doing the work an illustration usually does.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final PageController _pages = PageController();
  int _step = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(settingsProvider.notifier).setOnboarded(value: true);
    context.go(
      ref.read(settingsProvider).landingTab == LandingTab.folders
          ? Routes.folders
          : Routes.links,
    );
  }

  void _next() {
    if (_step == 2) {
      _finish();
      return;
    }
    _pages.nextPage(
      duration: Motion.of(context, Motion.containerTransform),
      curve: Motion.curveOf(context, Motion.decelerate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (int i) => setState(() => _step = i),
                children: const <Widget>[
                  _HeroStep(),
                  _OrganiseStep(),
                  _ThemeStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, Space.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AppButton(
                    label: _step == 2 ? 'Start' : 'Next',
                    fullWidth: true,
                    onPressed: _next,
                  ),
                  const SizedBox(height: Space.md),
                  Center(
                    child: TextButton(
                      onPressed: _finish,
                      child: Text(
                        'Skip',
                        style: PerchType.label.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepNumber extends StatelessWidget {
  const _StepNumber(this.step);

  final int step;

  @override
  Widget build(BuildContext context) => Text(
    '0$step / 03',
    style: PerchType.sectionHeader.copyWith(
      color: context.colors.onSurfaceVariant,
    ),
  );
}

class _HeroStep extends StatelessWidget {
  const _HeroStep();

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Expanded(child: Center(child: PerchHero())),
          const _StepNumber(1),
          const SizedBox(height: Space.md),
          Text(
            'Save any link.\nSort it your way.\nStays on your phone.',
            style: PerchType.display.copyWith(
              fontSize: 42,
              height: 1.06,
              color: c.onSurface,
            ),
          ),
          const SizedBox(height: Space.lg),
          Text(
            'No account · no ads · no tracking.',
            style: PerchType.monoTabular.copyWith(
              height: 1.5,
              color: c.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.xxl),
        ],
      ),
    );
  }
}

class _OrganiseStep extends StatelessWidget {
  const _OrganiseStep();

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Expanded(child: Center(child: _NestedFolderArt())),
          const _StepNumber(2),
          const SizedBox(height: Space.md),
          Text(
            'Organize with folders & tags',
            style: PerchType.display.copyWith(
              fontSize: 32,
              height: 1.1,
              color: c.onSurface,
            ),
          ),
          const SizedBox(height: Space.md),
          Text(
            'Nest folders as deep as you like, tag across them, and everything '
            'stays one tap away in the Folders tab.',
            style: PerchType.body.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: Space.xxl),
        ],
      ),
    );
  }
}

/// Nested folders on the left, one link with its tags on the right.
class _NestedFolderArt extends StatelessWidget {
  const _NestedFolderArt();

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    Widget row(String name, double indent, Color color) => Padding(
      padding: EdgeInsets.only(left: indent, bottom: Space.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: Space.row,
        children: <Widget>[
          FolderGlyph(color: color, width: 20),
          Text(
            name,
            style: PerchType.titleSmall.copyWith(color: c.onSurface),
          ),
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              row('Reading', 0, c.primary),
              row('AI papers', Space.screen, c.accent),
              row('Essays', Space.screen, c.accent),
              row('Recipes', 0, c.primary),
            ],
          ),
        ),
        const Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            TagChip(label: 'reading', style: ChipStyle.active),
            TagChip(label: 'essays'),
          ],
        ),
      ],
    );
  }
}

/// The theme step can be dismissed without choosing — Perch is already applied.
class _ThemeStep extends ConsumerWidget {
  const _ThemeStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final String selected = ref.watch(
      settingsProvider.select((AppSettings s) => s.familyId),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Space.xxl),
          const _StepNumber(3),
          const SizedBox(height: Space.md),
          Text(
            'Pick a look',
            style: PerchType.display.copyWith(
              fontSize: 32,
              height: 1.1,
              color: c.onSurface,
            ),
          ),
          const SizedBox(height: Space.md),
          Text(
            'All themes are free, and you can change this any time in '
            'More → Appearance.',
            style: PerchType.body.copyWith(color: c.onSurfaceVariant),
          ),
          const SizedBox(height: Space.xl),
          Wrap(
            spacing: Space.md,
            runSpacing: Space.md,
            children: <Widget>[
              for (final ThemeFamily family in ThemeFamily.all)
                _ThemeSwatch(
                  family: family,
                  selected: family.id == selected,
                  onTap: () =>
                      ref.read(settingsProvider.notifier).setFamily(family.id),
                ),
            ],
          ),
          const Spacer(),
          _ShareHint(),
          const SizedBox(height: Space.xl),
        ],
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.family,
    required this.selected,
    required this.onTap,
  });

  final ThemeFamily family;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final PerchColors swatch = family.colors(Tone.light);
    return Semantics(
      button: true,
      selected: selected,
      label: '${family.name} theme',
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.fullR,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: swatch.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? c.primaryContainer : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              family.name,
              style: PerchType.label.copyWith(
                color: selected ? c.accent : c.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A card, not a tooltip — it survives being read slowly and needs no dismissal.
class _ShareHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outline),
      ),
      child: Text.rich(
        TextSpan(
          text: 'Next: open any app, hit ',
          style: PerchType.bodySmall.copyWith(color: c.onSurfaceVariant),
          children: <InlineSpan>[
            TextSpan(
              text: 'Share → Perch',
              style: PerchType.labelStrong.copyWith(color: c.accent),
            ),
            const TextSpan(text: ' to save your first link.'),
          ],
        ),
      ),
    );
  }
}
