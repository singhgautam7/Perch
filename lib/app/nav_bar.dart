import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/settings_repository.dart';
import '../core/providers.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/palette.dart';
import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import '../shared/widgets/perch_icons.dart';

/// One destination in the floating nav pill.
class NavDestination {
  const NavDestination(this.glyph, this.label);

  final PerchGlyph glyph;
  final String label;
}

const List<NavDestination> kDestinations = <NavDestination>[
  NavDestination(PerchGlyph.links, 'Links'),
  NavDestination(PerchGlyph.folders, 'Folders'),
  NavDestination(PerchGlyph.search, 'Search'),
  NavDestination(PerchGlyph.more, 'More'),
];

/// Board 2a — a content-hugging pill, not a bar. Only the selected destination
/// carries text; inactive tabs are glyphs at 40×40 inside the pill's padding.
///
/// The tinted indicator travels to the tapped tab and the label fades up as it
/// arrives; under reduced motion the pill jumps and the label cross-fades.
class PerchNavPill extends ConsumerWidget {
  const PerchNavPill({
    required this.index,
    required this.onSelect,
    super.key,
  });

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    // The nav renders opaque by default. Blur is the one real GPU cost in the
    // app, so it only happens behind the explicit Appearance toggle.
    final bool blur = ref.watch(
      settingsProvider.select((AppSettings s) => s.blur),
    );

    return RepaintBoundary(
      child: _MaybeBlurred(
        enabled: blur,
        child: Container(
          height: 56,
          padding: const EdgeInsets.all(Space.sm),
          decoration: BoxDecoration(
            color: blur ? c.surface.withValues(alpha: 0.72) : c.surface,
            borderRadius: Radii.fullR,
            border: Border.all(color: c.outline),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.shadow,
                blurRadius: 18,
                offset: const Offset(0, Elevations.navPill),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: <Widget>[
              for (int i = 0; i < kDestinations.length; i++)
                _NavItem(
                  destination: kDestinations[i],
                  selected: i == index,
                  onTap: () => onSelect(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wraps [child] in a backdrop blur only when the toggle is on — a
/// `BackdropFilter` that is always in the tree costs whether or not it blurs.
class _MaybeBlurred extends StatelessWidget {
  const _MaybeBlurred({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return ClipRRect(
      borderRadius: Radii.fullR,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: child,
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final Color glyphColor = selected ? c.onPrimaryContainer : c.iconMuted;
    // Under a large OS text scale the nav labels drop first; the glyphs and the
    // indicator still say where you are.
    final bool showLabel =
        selected && MediaQuery.textScalerOf(context).scale(13.5) <= 20;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.navIndicator),
          curve: Motion.curveOf(context, Motion.spring),
          height: 40,
          padding: EdgeInsets.only(
            left: showLabel ? 11 : 8,
            right: showLabel ? 14 : 8,
          ),
          decoration: BoxDecoration(
            color: selected ? c.primaryContainer : Colors.transparent,
            borderRadius: Radii.fullR,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: showLabel ? Space.sm : 0,
            children: <Widget>[
              PerchIcon(
                destination.glyph,
                color: glyphColor,
                filled: selected && destination.glyph == PerchGlyph.folders,
                background: selected ? c.primaryContainer : c.surface,
              ),
              // The label is what morphs in; the outgoing one fades over the
              // first 80ms so two are never legible at once.
              AnimatedSize(
                duration: Motion.of(context, Motion.navIndicator),
                curve: Motion.curveOf(context, Motion.spring),
                child: showLabel
                    ? Text(
                        destination.label,
                        style: PerchType.titleSmall.copyWith(
                          color: c.onPrimaryContainer,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The circular Add button. It sits beside the pill, never inside it — adding a
/// link is not a destination.
class PerchFab extends StatefulWidget {
  const PerchFab({required this.onTap, this.extended = false, super.key});

  final VoidCallback onTap;

  /// The extended form is used only in the empty state.
  final bool extended;

  @override
  State<PerchFab> createState() => _PerchFabState();
}

class _PerchFabState extends State<PerchFab> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Semantics(
      button: true,
      label: 'Add link',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          // 40ms squash, then the circle becomes the sheet.
          scale: _pressed ? 0.94 : 1,
          duration: const Duration(milliseconds: 40),
          child: Container(
            height: 56,
            width: widget.extended ? null : 56,
            padding: widget.extended
                ? const EdgeInsets.symmetric(horizontal: 22)
                : null,
            decoration: BoxDecoration(
              color: _pressed ? c.primaryPressed : c.primary,
              borderRadius: Radii.fullR,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: c.primary.withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, Elevations.fab),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 9,
              children: <Widget>[
                Icon(Icons.add_rounded, color: c.onPrimary, size: 26),
                if (widget.extended)
                  Text(
                    'Add link',
                    style: PerchType.body.weight(600).copyWith(
                      color: c.onPrimary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
