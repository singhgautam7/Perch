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
import 'perch_hero.dart';
import 'welcome_art.dart';

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
            _Footer(
              step: _step,
              // The boards label the first and last steps Start, and the
              // middle one Next.
              primaryLabel: _step == 1 ? 'Next' : 'Start',
              onPrimary: _next,
              onSkip: _finish,
            ),
          ],
        ),
      ),
    );
  }
}

/// The page dots and the two buttons, side by side: a wide primary and a
/// 96dp outlined Skip.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.step,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onSkip,
  });

  final int step;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            spacing: 7,
            children: <Widget>[
              for (int i = 0; i < 3; i++)
                AnimatedContainer(
                  duration: Motion.of(context, Motion.navIndicator),
                  curve: Motion.curveOf(context, Motion.decelerate),
                  width: i == step ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == step ? c.primary : c.outline,
                    borderRadius: Radii.fullR,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            spacing: Space.row,
            children: <Widget>[
              Expanded(
                child: Semantics(
                  button: true,
                  label: primaryLabel,
                  child: Material(
                    color: c.primary,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onPrimary,
                      child: SizedBox(
                        height: 56,
                        child: Center(
                          child: Text(
                            primaryLabel,
                            style: PerchType.body
                                .copyWith(
                                  fontSize: 16,
                                  letterSpacing: 0.16,
                                  color: c.onPrimary,
                                )
                                .weight(600),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Skip',
                child: Material(
                  color: Colors.transparent,
                  shape: StadiumBorder(side: BorderSide(color: c.outline)),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onSkip,
                    child: SizedBox(
                      width: 96,
                      height: 56,
                      child: Center(
                        child: Text(
                          'Skip',
                          style: PerchType.body.copyWith(
                            fontSize: 15,
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
      letterSpacing: 0.99,
      color: context.colors.accent,
    ),
  );
}

class _HeroStep extends StatelessWidget {
  const _HeroStep();

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Stack(
      children: <Widget>[
        const Positioned(
          top: -120,
          left: -80,
          right: -80,
          height: 520,
          child: HeroGlow(),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 6),
            const PerchHero(),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _StepNumber(1),
                  const SizedBox(height: Space.md),
                  Text(
                    'Save any link.\nSort it your way.\nStays on your phone.',
                    style: PerchType.display.copyWith(
                      fontSize: 42,
                      height: 1.06,
                      letterSpacing: -0.84,
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
                ],
              ),
            ),
            const SizedBox(height: Space.xxl),
          ],
        ),
      ],
    );
  }
}

class _OrganiseStep extends StatelessWidget {
  const _OrganiseStep();

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.screen),
            child: Center(child: OrganiseArt()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _StepNumber(2),
              const SizedBox(height: Space.md),
              Text(
                'Organize with folders & tags',
                style: PerchType.display.copyWith(
                  fontSize: 36,
                  height: 1.12,
                  letterSpacing: -0.72,
                  color: c.onSurface,
                ),
              ),
              const SizedBox(height: Space.row),
              Text(
                'Nest folders as deep as you like, tag across them, and '
                'everything stays one tap away in the Folders tab.',
                style: PerchType.body.copyWith(
                  fontSize: 14.5,
                  height: 1.55,
                  color: c.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xxl),
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
    final AppSettings s = ref.watch(settingsProvider);
    final Tone tone =
        s.toneFor(MediaQuery.platformBrightnessOf(context)) == Tone.light
        ? Tone.light
        : Tone.dark;

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xl),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 40, 26, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const _StepNumber(3),
              const SizedBox(height: Space.md),
              Text(
                'Pick a look',
                style: PerchType.display.copyWith(
                  fontSize: 36,
                  height: 1.12,
                  letterSpacing: -0.72,
                  color: c.onSurface,
                ),
              ),
              const SizedBox(height: Space.row),
              Text(
                'All themes are free, and you can change this any time in '
                'More → Appearance.',
                style: PerchType.body.copyWith(
                  fontSize: 14.5,
                  height: 1.55,
                  color: c.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 26, 26, 0),
          // A Wrap rather than a grid: a fixed aspect ratio pins the card
          // height, and at a large OS text scale the name line then has
          // nowhere to go. Here the card is as tall as its content needs.
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double half = (constraints.maxWidth - Space.md) / 2;
              return Wrap(
                spacing: Space.md,
                runSpacing: Space.md,
                children: <Widget>[
                  for (final ThemeFamily family in ThemeFamily.all)
                    SizedBox(
                      width: half,
                      child: ThemeSwatchCard(
                        family: family,
                        tone: tone,
                        selected: !s.dynamicColor && family.id == s.familyId,
                        onTap: () => ref
                            .read(settingsProvider.notifier)
                            .setFamily(family.id),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(26, 20, 26, 0),
          child: ShareHintCard(),
        ),
      ],
    );
  }
}
