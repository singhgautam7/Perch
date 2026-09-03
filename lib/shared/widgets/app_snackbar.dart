import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

enum SnackVariant { info, success, warning, error }

/// Which edge the strip is anchored to. The anchor decides which way a vertical
/// swipe dismisses it.
enum SnackPosition { top, bottom }

class SnackMessage {
  const SnackMessage({
    required this.text,
    this.variant = SnackVariant.info,
    this.position = SnackPosition.bottom,
    this.duration = const Duration(seconds: 4),
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final SnackVariant variant;
  final SnackPosition position;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// Board 1e — the undo strip. An inverse-surface bar with a round status mark,
/// one line, and an optional action. There is no dialog anywhere in this flow.
///
/// Flutter's own snackbar cannot be anchored to the top or dismissed by a
/// directional swipe, and both are in the spec.
abstract final class AppSnackbar {
  static final Queue<SnackMessage> _queue = Queue<SnackMessage>();
  static OverlayEntry? _entry;
  static OverlayState? _overlay;

  static void show(BuildContext context, SnackMessage message) {
    _queue.add(message);
    if (_attach(context)) return;
    // A save can land before the first frame — a share that cold-starts the app
    // does exactly that. The message waits for an overlay rather than throwing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) _attach(context);
    });
  }

  /// Finds the overlay to host the strip, and starts it if one exists.
  ///
  /// `Overlay.maybeOf` only looks up the tree, so a context taken from the
  /// router's navigator key — which sits *above* its own overlay — needs the
  /// navigator asked directly.
  static bool _attach(BuildContext context) {
    final OverlayState? overlay =
        Overlay.maybeOf(context, rootOverlay: true) ??
        Navigator.maybeOf(context, rootNavigator: true)?.overlay;
    if (overlay == null || !overlay.mounted) return false;
    _overlay = overlay;
    if (_entry == null) _next();
    return true;
  }

  static void info(BuildContext context, String text) =>
      show(context, SnackMessage(text: text));

  static void success(BuildContext context, String text) =>
      show(context, SnackMessage(text: text, variant: SnackVariant.success));

  static void error(BuildContext context, String text) =>
      show(context, SnackMessage(text: text, variant: SnackVariant.error));

  static void _next() {
    final OverlayState? overlay = _overlay;
    if (overlay == null || !overlay.mounted || _queue.isEmpty) {
      _entry = null;
      return;
    }
    final SnackMessage message = _queue.removeFirst();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext context) => _SnackHost(
        message: message,
        onDismissed: () {
          entry.remove();
          _entry = null;
          _next();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// Drops anything still queued — used when the screen that raised them goes.
  static void clear() => _queue.clear();
}

class _SnackHost extends StatefulWidget {
  const _SnackHost({required this.message, required this.onDismissed});

  final SnackMessage message;
  final VoidCallback onDismissed;

  @override
  State<_SnackHost> createState() => _SnackHostState();
}

class _SnackHostState extends State<_SnackHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: Motion.fast,
  )..forward();
  Timer? _timer;
  Offset _drag = Offset.zero;
  bool _dismissing = false;

  bool get _top => widget.message.position == SnackPosition.top;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.message.duration, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _enter.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _timer?.cancel();
    if (mounted) await _enter.reverse();
    if (mounted) widget.onDismissed();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      // Horizontal either way; vertical only towards the anchored edge.
      final double dy = _top
          ? (_drag.dy + d.delta.dy).clamp(-400.0, 0.0)
          : (_drag.dy + d.delta.dy).clamp(0.0, 400.0);
      _drag = Offset(_drag.dx + d.delta.dx, dy);
    });
  }

  void _onPanEnd(DragEndDetails d) {
    const double threshold = 64;
    if (_drag.dx.abs() > threshold || _drag.dy.abs() > threshold) {
      unawaited(_dismiss());
    } else {
      setState(() => _drag = Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final bool reduced = Motion.reduced(context);
    final double slide = _top ? -24 : 24;

    return Positioned(
      left: Space.screen,
      right: Space.screen,
      top: _top ? mq.padding.top + Space.md : null,
      // Sits above the floating nav, as the board places it.
      bottom: _top ? null : mq.padding.bottom + 96,
      child: AnimatedBuilder(
        animation: _enter,
        builder: (BuildContext context, Widget? child) {
          final double t = _enter.value;
          return Opacity(
            opacity: t.clamp(0, 1),
            child: Transform.translate(
              offset:
                  _drag + (reduced ? Offset.zero : Offset(0, slide * (1 - t))),
              child: child,
            ),
          );
        },
        child: GestureDetector(
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: _Strip(message: widget.message, onClose: _dismiss),
        ),
      ),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.message, required this.onClose});

  final SnackMessage message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final (Color markColor, IconData markIcon) = switch (message.variant) {
      SnackVariant.info => (c.inverseAccent, Icons.info_outline_rounded),
      SnackVariant.success => (c.primary, Icons.check_rounded),
      SnackVariant.warning => (c.warning, Icons.priority_high_rounded),
      SnackVariant.error => (c.danger, Icons.close_rounded),
    };

    return Material(
      color: Colors.transparent,
      child: Semantics(
        liveRegion: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          decoration: BoxDecoration(
            color: c.inverseSurface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.shadow,
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            spacing: 11,
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: markColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(markIcon, size: 14, color: c.onPrimary),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.md),
                  child: Text(
                    message.text,
                    style: PerchType.label.copyWith(
                      fontSize: 13.5,
                      color: c.onInverseSurface,
                    ),
                  ),
                ),
              ),
              if (message.actionLabel != null)
                GestureDetector(
                  onTap: () {
                    message.onAction?.call();
                    onClose();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.sm,
                      vertical: Space.md,
                    ),
                    child: Text(
                      message.actionLabel!,
                      style: PerchType.labelStrong.copyWith(
                        fontSize: 12.5,
                        color: c.inverseAccent,
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
