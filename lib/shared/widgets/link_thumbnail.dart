import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/oklch.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/url.dart';

/// The preview ladder from board 1j: `og:image` → favicon → monogram tile.
///
/// Every rung fails downward rather than showing an error — a saved link always
/// draws something.
class LinkThumbnail extends StatelessWidget {
  const LinkThumbnail({
    required this.url,
    required this.imageUrl,
    required this.faviconUrl,
    required this.size,
    this.radius = 13,
    this.fill = false,
    super.key,
  });

  final String url;
  final String? imageUrl;
  final String? faviconUrl;

  /// The box side, or the height when [fill] is set.
  final double size;
  final double radius;

  /// Grid cards give the thumbnail the full card width.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final BorderRadius shape = BorderRadius.circular(radius);

    Widget frame(Widget child, {Color? background}) => ClipRRect(
      borderRadius: shape,
      child: Container(
        width: fill ? double.infinity : size,
        height: size,
        color: background,
        child: child,
      ),
    );

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return RepaintBoundary(
        child: frame(
          CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            // Decoding at display size keeps a 1200×630 hero out of memory.
            memCacheHeight: (size * MediaQuery.devicePixelRatioOf(context))
                .round(),
            placeholder: (BuildContext c, String _) =>
                const ThumbnailSkeleton(),
            errorWidget: (BuildContext context, String _, Object _) =>
                _faviconOrMonogram(context),
          ),
          background: c.surfaceContainerHigh,
        ),
      );
    }
    return frame(_faviconOrMonogram(context), background: c.surfaceContainerHigh);
  }

  Widget _faviconOrMonogram(BuildContext context) {
    if (faviconUrl == null || faviconUrl!.isEmpty) {
      return _Monogram(url: url, size: size);
    }
    return Center(
      child: SizedBox(
        // The favicon is centred on the tint, not stretched across it.
        width: size * 0.43,
        height: size * 0.43,
        child: CachedNetworkImage(
          imageUrl: faviconUrl!,
          fit: BoxFit.contain,
          errorWidget: (BuildContext context, String _, Object _) =>
              _Monogram(url: url, size: size),
        ),
      ),
    );
  }
}

/// Last rung — a tinted tile with the domain's initial, hue hashed from the
/// domain so the same site always gets the same colour.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String host = hostOf(url);
    final String letter = host.isEmpty ? '?' : host[0].toUpperCase();
    final double hue = (host.hashCode.abs() % 360).toDouble();
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: Oklch(dark ? 0.52 : 0.58, 0.12, hue).toColor(),
      child: Center(
        child: Text(
          letter,
          style: PerchType.title.copyWith(
            fontSize: size * 0.4,
            color: const Oklch(1, 0, 0).toColor(),
          ),
        ),
      ),
    );
  }
}

/// The shimmer that sweeps a preview block while metadata is in flight.
class ThumbnailSkeleton extends StatefulWidget {
  const ThumbnailSkeleton({super.key});

  @override
  State<ThumbnailSkeleton> createState() => _ThumbnailSkeletonState();
}

class _ThumbnailSkeletonState extends State<ThumbnailSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.shimmerLoop,
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
    // Under reduced motion the sweep becomes a static tint.
    if (Motion.reduced(context)) {
      return ColoredBox(color: c.surfaceContainerHigh);
    }
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? _) {
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + _c.value * 3, -0.4),
                end: Alignment(_c.value * 3, 0.4),
                colors: <Color>[
                  c.surfaceContainerHigh,
                  c.surface,
                  c.surfaceContainerHigh,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
