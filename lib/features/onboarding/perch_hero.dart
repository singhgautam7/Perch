import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';

/// Five rounded cards falling at different rates onto a single accent line,
/// each settling with a small bounce. 4s loop (board 1c).
class PerchHero extends StatefulWidget {
  const PerchHero({super.key});

  @override
  State<PerchHero> createState() => _PerchHeroState();
}

class _PerchHeroState extends State<PerchHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  /// width, horizontal offset, and how far into the loop each card starts.
  static const List<(double, double, double)> _cards =
      <(double, double, double)>[
        (92, -34, 0.00),
        (68, 30, 0.10),
        (110, -8, 0.20),
        (56, 46, 0.30),
        (80, -50, 0.40),
      ];

  @override
  void initState() {
    super.initState();
    if (!WidgetsBinding.instance.disableAnimations) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    // Under reduced motion the cards are simply already perched.
    final bool still = Motion.reduced(context);

    return RepaintBoundary(
      child: SizedBox(
        width: 240,
        height: 200,
        child: AnimatedBuilder(
          animation: _c,
          builder: (BuildContext context, Widget? _) {
            return Stack(
              alignment: Alignment.bottomCenter,
              children: <Widget>[
                for (int i = 0; i < _cards.length; i++)
                  _FallingCard(
                    width: _cards[i].$1,
                    dx: _cards[i].$2,
                    // Each card lands, then holds until the loop restarts.
                    progress: still
                        ? 1
                        : Curves.easeOutBack.transform(
                            (((_c.value - _cards[i].$3) / 0.45).clamp(0.0, 1.0)),
                          ),
                    color: i.isEven ? c.primaryContainer : c.surfaceContainer,
                    border: i.isEven ? null : c.outline,
                    restHeight: 22.0 * (i + 1),
                  ),
                Container(
                  width: 200,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.primary,
                    borderRadius: Radii.fullR,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FallingCard extends StatelessWidget {
  const _FallingCard({
    required this.width,
    required this.dx,
    required this.progress,
    required this.color,
    required this.border,
    required this.restHeight,
  });

  final double width;
  final double dx;
  final double progress;
  final Color color;
  final Color? border;

  /// Where the card comes to rest above the perch.
  final double restHeight;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: restHeight * progress - 4,
      left: null,
      child: Opacity(
        opacity: progress.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(dx, (1 - progress) * -120),
          child: Container(
            width: width,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: Radii.chipR,
              border: border == null ? null : Border.all(color: border!),
            ),
          ),
        ),
      ),
    );
  }
}
