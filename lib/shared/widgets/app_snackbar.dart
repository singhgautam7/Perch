import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

export '../../core/theme/palette.dart' show SnackVariant;

/// Which edge the strip is anchored to. The anchor decides which way a vertical
/// swipe dismisses it.
enum SnackPosition { top, bottom }

class SnackMessage {
  const SnackMessage({
    required this.text,
    this.variant = SnackVariant.info,
    this.position = SnackPosition.bottom,
    this.duration,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final SnackVariant variant;
  final SnackPosition position;

  /// Null takes the board's default: 4s, or 7s when an action is offered.
  final Duration? duration;
  final String? actionLabel;
  final VoidCallback? onAction;

  Duration get resolvedDuration =>
      duration ?? (actionLabel == null ? _kPlain : _kWithAction);

  static const Duration _kPlain = Duration(seconds: 4);
  static const Duration _kWithAction = Duration(seconds: 7);
}

/// One queued message plus the identity the layer animates against.
class _Entry {
  _Entry(this.message) : id = ++_seq;

  static int _seq = 0;

  final SnackMessage message;
  final int id;
}

/// Board 3h — one spec, four theme-role variants, three themes.
///
/// Flutter's own snackbar cannot be anchored to the top, dismissed by a
/// directional swipe, or stacked, and all three are in the spec.
abstract final class AppSnackbar {
  /// Newest last. At most [_maxVisible] per anchor are on screen; a further
  /// message collapses the oldest rather than waiting behind it.
  static const int _maxVisible = 2;

  static final ValueNotifier<List<_Entry>> _entries =
      ValueNotifier<List<_Entry>>(const <_Entry>[]);
  static OverlayEntry? _layer;

  static void show(BuildContext context, SnackMessage message) {
    _push(message);
    if (_attach(context)) return;
    // A save can land before the first frame — a share that cold-starts the app
    // does exactly that. The message waits for an overlay rather than throwing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) _attach(context);
    });
  }

  static void _push(SnackMessage message) {
    final List<_Entry> next = <_Entry>[..._entries.value, _Entry(message)];
    final Iterable<_Entry> sameAnchor = next.where(
      (_Entry e) => e.message.position == message.position,
    );
    if (sameAnchor.length > _maxVisible) {
      final _Entry oldest = sameAnchor.first;
      next.remove(oldest);
    }
    _entries.value = next;
  }

  static void _remove(int id) {
    _entries.value = _entries.value
        .where((_Entry e) => e.id != id)
        .toList(growable: false);
  }

  /// Finds the overlay to host the layer, and inserts it once.
  ///
  /// `Overlay.maybeOf` only looks up the tree, so a context taken from the
  /// router's navigator key — which sits *above* its own overlay — needs the
  /// navigator asked directly.
  static bool _attach(BuildContext context) {
    final OverlayState? overlay =
        Overlay.maybeOf(context, rootOverlay: true) ??
        Navigator.maybeOf(context, rootNavigator: true)?.overlay;
    if (overlay == null || !overlay.mounted) return false;
    if (_layer == null || !_layer!.mounted) {
      _layer = OverlayEntry(builder: (BuildContext _) => const _SnackLayer());
      overlay.insert(_layer!);
    }
    return true;
  }

  static void info(BuildContext context, String text) =>
      show(context, SnackMessage(text: text));

  static void success(BuildContext context, String text) =>
      show(context, SnackMessage(text: text, variant: SnackVariant.success));

  static void warning(BuildContext context, String text) =>
      show(context, SnackMessage(text: text, variant: SnackVariant.warning));

  static void error(BuildContext context, String text) =>
      show(context, SnackMessage(text: text, variant: SnackVariant.error));

  /// Drops everything on screen — used when the screen that raised them goes.
  static void clear() => _entries.value = const <_Entry>[];
}

/// Renders both anchors. Nothing is painted while the queue is empty, so the
/// layer costs one `IgnorePointer` when idle.
class _SnackLayer extends StatelessWidget {
  const _SnackLayer();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<_Entry>>(
      valueListenable: AppSnackbar._entries,
      builder: (BuildContext context, List<_Entry> entries, Widget? _) {
        if (entries.isEmpty) return const SizedBox.shrink();
        final MediaQueryData mq = MediaQuery.of(context);
        List<_Entry> at(SnackPosition p) => entries
            .where((_Entry e) => e.message.position == p)
            .toList(growable: false);

        return Stack(
          children: <Widget>[
            _Stack(
              entries: at(SnackPosition.top),
              position: SnackPosition.top,
              inset: mq.padding.top + Space.md,
            ),
            _Stack(
              entries: at(SnackPosition.bottom),
              position: SnackPosition.bottom,
              // Above the floating nav pill, as the board places it.
              inset: mq.padding.bottom + 96,
            ),
          ],
        );
      },
    );
  }
}

class _Stack extends StatelessWidget {
  const _Stack({
    required this.entries,
    required this.position,
    required this.inset,
  });

  final List<_Entry> entries;
  final SnackPosition position;
  final double inset;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final bool top = position == SnackPosition.top;
    // Newest reads in front: at the top anchor that is the last row, at the
    // bottom anchor it is the row nearest the edge.
    final List<Widget> strips = <Widget>[
      for (final _Entry e in entries)
        Padding(
          key: ValueKey<int>(e.id),
          padding: const EdgeInsets.only(top: 6),
          child: _AnimatedStrip(entry: e),
        ),
    ];

    return Positioned(
      left: Space.md,
      right: Space.md,
      top: top ? inset : null,
      bottom: top ? null : inset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: top ? strips : strips.reversed.toList(growable: false),
      ),
    );
  }
}

/// Enter, dwell, swipe and exit for one message.
class _AnimatedStrip extends StatefulWidget {
  const _AnimatedStrip({required this.entry});

  final _Entry entry;

  @override
  State<_AnimatedStrip> createState() => _AnimatedStripState();
}

class _AnimatedStripState extends State<_AnimatedStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: Motion.snackEnter,
    reverseDuration: Motion.snackExit,
  )..forward();

  Timer? _timer;
  Offset _drag = Offset.zero;
  Offset _exitTo = Offset.zero;
  bool _dismissing = false;

  SnackMessage get _m => widget.entry.message;
  bool get _top => _m.position == SnackPosition.top;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _enter.dispose();
    super.dispose();
  }

  /// Reduced motion trades the translate for a longer read.
  void _restartTimer() {
    _timer?.cancel();
    final Duration base = _m.resolvedDuration;
    final Duration wait = Motion.reduced(context) && _m.duration == null
        ? const Duration(seconds: 6)
        : base;
    _timer = Timer(wait, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _timer?.cancel();
    if (mounted) await _enter.reverse();
    AppSnackbar._remove(widget.entry.id);
  }

  void _onPanStart(DragStartDetails _) => _timer?.cancel();

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      // Horizontal either way; vertical only away from the anchored edge.
      final double dy = _top
          ? (_drag.dy + d.delta.dy).clamp(-400.0, 0.0)
          : (_drag.dy + d.delta.dy).clamp(0.0, 400.0);
      _drag = Offset(_drag.dx + d.delta.dx, dy);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    const double threshold = 64;
    if (_drag.dx.abs() > threshold || _drag.dy.abs() > threshold) {
      // Exit continues the way the finger was going.
      _exitTo = Offset(_drag.dx.sign * 360, _drag.dy.sign * 200);
      unawaited(_dismiss());
    } else {
      setState(() => _drag = Offset.zero);
      _restartTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = Motion.reduced(context);
    final double slide = _top ? -16 : 16;

    return AnimatedBuilder(
      animation: _enter,
      builder: (BuildContext context, Widget? child) {
        final double t = _enter.value;
        final Offset offset = reduced
            ? _drag
            : _drag +
                  (_dismissing && _exitTo != Offset.zero
                      ? _exitTo * (1 - t)
                      : Offset(0, slide * (1 - t)));
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.translate(offset: offset, child: child),
        );
      },
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: _Strip(message: _m, onClose: _dismiss),
      ),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.message, required this.onClose});

  final SnackMessage message;
  final VoidCallback onClose;

  static IconData iconFor(SnackVariant variant) => switch (variant) {
    SnackVariant.info => Icons.info_outline_rounded,
    SnackVariant.success => Icons.check_circle_outline_rounded,
    SnackVariant.warning => Icons.error_outline_rounded,
    SnackVariant.error => Icons.cancel_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final SnackColors s = c.snack(message.variant);

    return Material(
      color: Colors.transparent,
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: s.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: s.tint),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.shadow,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            spacing: Space.md,
            children: <Widget>[
              SizedBox(
                width: 20,
                child: Icon(iconFor(message.variant), size: 18, color: s.tint),
              ),
              Expanded(
                child: Text(
                  message.text,
                  style: PerchType.label.copyWith(fontSize: 13, color: s.on),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (message.actionLabel != null)
                Semantics(
                  button: true,
                  label: message.actionLabel,
                  child: GestureDetector(
                    onTap: () {
                      message.onAction?.call();
                      onClose();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.xs,
                        vertical: 6,
                      ),
                      child: Text(
                        message.actionLabel!.toUpperCase(),
                        style: PerchType.labelStrong
                            .copyWith(color: s.tint, letterSpacing: 0.24)
                            .weight(700),
                      ),
                    ),
                  ),
                ),
              // Always present, per the board — never an implicit-only dismiss.
              Semantics(
                button: true,
                label: 'Dismiss',
                child: GestureDetector(
                  onTap: onClose,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: s.on.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
