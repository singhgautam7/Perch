import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// Board 1c — three saved links drift down and settle on the perch, 4s loop.
///
/// The cards are the app's own link card in miniature, each landing with a
/// small bounce; under reduced motion they are simply already perched.
class PerchHero extends StatefulWidget {
  const PerchHero({super.key});

  @override
  State<PerchHero> createState() => _PerchHeroState();
}

/// Layout is the board's, on its 390×330 frame, scaled to whatever it gets.
class _Card {
  const _Card({
    required this.left,
    required this.top,
    required this.width,
    required this.turns,
    required this.delay,
    this.monogram,
  });

  final double? left;
  final double top;
  final double width;

  /// Rotation in degrees.
  final double turns;

  /// Where in the 4s loop this card starts falling.
  final double delay;

  /// Null draws the hatched placeholder thumbnail instead.
  final String? monogram;
}

class _PerchHeroState extends State<PerchHero>
    with SingleTickerProviderStateMixin {
  static const double _frameWidth = 390;
  static const double _frameHeight = 330;

  static const List<_Card> _cards = <_Card>[
    _Card(left: 26, top: 18, width: 184, turns: -3, delay: 0.00),
    _Card(left: 198, top: 76, width: 170, turns: 2.5, delay: 0.09, monogram: 'A'),
    _Card(left: 44, top: 136, width: 176, turns: -1.5, delay: 0.18),
  ];

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

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
    final bool still = Motion.reduced(context);

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double scale = (constraints.maxWidth / _frameWidth).clamp(
            0.6,
            1.2,
          );
          return SizedBox(
            height: _frameHeight * scale,
            child: AnimatedBuilder(
              animation: _c,
              builder: (BuildContext context, Widget? _) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    // The perch, and the light it throws.
                    Positioned(
                      left: 34 * scale,
                      right: 34 * scale,
                      top: 216 * scale,
                      height: 26 * scale,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              c.primary.withValues(alpha: 0.16),
                              c.primary.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 34 * scale,
                      right: 34 * scale,
                      top: 212 * scale,
                      height: 4 * scale,
                      child: Opacity(
                        opacity: 0.9,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.primary,
                            borderRadius: Radii.fullR,
                          ),
                        ),
                      ),
                    ),
                    for (final _Card card in _cards)
                      _FallingCard(
                        card: card,
                        scale: scale,
                        // Each card falls over its own 45% of the loop, then
                        // holds perched until the loop restarts.
                        progress: still
                            ? 1
                            : Curves.easeOutBack.transform(
                                ((_c.value - card.delay) / 0.45).clamp(
                                  0.0,
                                  1.0,
                                ),
                              ),
                      ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FallingCard extends StatelessWidget {
  const _FallingCard({
    required this.card,
    required this.scale,
    required this.progress,
  });

  final _Card card;
  final double scale;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;

    return Positioned(
      left: card.left! * scale,
      top: card.top * scale,
      width: card.width * scale,
      child: Opacity(
        opacity: progress.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - progress) * -110 * scale),
          child: Transform.rotate(
            angle: card.turns * 3.1415926535 / 180,
            child: Container(
              padding: EdgeInsets.all(9 * scale),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(15 * scale),
                border: Border.all(color: c.outline),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: c.shadow,
                    blurRadius: 20 * scale,
                    offset: Offset(0, 8 * scale),
                  ),
                ],
              ),
              child: Row(
                spacing: 9 * scale,
                children: <Widget>[
                  Container(
                    width: 32 * scale,
                    height: 32 * scale,
                    decoration: BoxDecoration(
                      color: card.monogram == null
                          ? c.surfaceContainerHigh
                          : c.primary,
                      borderRadius: BorderRadius.circular(9 * scale),
                    ),
                    child: card.monogram == null
                        ? null
                        : Center(
                            child: Text(
                              card.monogram!,
                              style: PerchType.titleSmall.copyWith(
                                fontSize: 15 * scale,
                                color: c.onPrimary,
                              ),
                            ),
                          ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 6 * scale,
                      children: <Widget>[
                        _Bar(widthFactor: 0.88, height: 6 * scale, color: c.onSurfaceMuted),
                        _Bar(widthFactor: 0.5, height: 5 * scale, color: c.outline),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.widthFactor,
    required this.height,
    required this.color,
  });

  final double widthFactor;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    alignment: Alignment.centerLeft,
    widthFactor: widthFactor,
    child: Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}
