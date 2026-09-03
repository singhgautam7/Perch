import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

enum SnackVariant { info, success, warning, error }

/// Which edge the snackbar is anchored to. The anchor decides which way a
/// vertical swipe dismisses it.
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

/// Perch's own snackbar. Flutter's cannot be anchored to the top or dismissed
/// by a directional swipe, and both are in the spec.
///
/// One is visible at a time; the rest queue behind it.
abstract final class AppSnackbar {
  static final Queue<SnackMessage> _queue = Queue<SnackMessage>();
  static OverlayEntry? _entry;
  static OverlayState? _overlay;

  static void show(BuildContext context, SnackMessage message) {
    _overlay = Overlay.of(context, rootOverlay: true);
    _queue.add(message);
    if (_entry == null) _next();
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
  static void clear() {
    _queue.clear();
  }
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
    await _enter.reverse();
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
      left: Space.md,
      right: Space.md,
      top: _top ? mq.padding.top + Space.md : null,
      // Clears the floating nav.
      bottom: _top ? null : mq.padding.bottom + Space.bottomSafe,
      child: AnimatedBuilder(
        animation: _enter,
        builder: (BuildContext context, Widget? child) {
          final double t = _enter.value;
          return Opacity(
            opacity: t,
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
          child: _SnackCard(message: widget.message, onClose: _dismiss),
        ),
      ),
    );
  }
}

class _SnackCard extends StatelessWidget {
  const _SnackCard({required this.message, required this.onClose});

  final SnackMessage message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final Color dot = switch (message.variant) {
      SnackVariant.info => c.accent,
      SnackVariant.success => c.success,
      SnackVariant.warning => c.warning,
      SnackVariant.error => c.danger,
    };

    return Material(
      color: Colors.transparent,
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 11, Space.xs, 11),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: Radii.thumbR,
            border: Border.all(
              color: message.variant == SnackVariant.error
                  ? c.dangerContainer
                  : c.outline,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.shadow,
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            spacing: Space.row,
            children: <Widget>[
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(
                  message.text,
                  style: PerchType.bodySmall.copyWith(color: c.onSurface),
                ),
              ),
              if (message.actionLabel != null)
                TextButton(
                  onPressed: () {
                    message.onAction?.call();
                    onClose();
                  },
                  child: Text(
                    message.actionLabel!.toUpperCase(),
                    style: PerchType.monoLabel.copyWith(color: c.accent),
                  ),
                ),
              IconButton(
                onPressed: onClose,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, color: c.onSurfaceVariant),
                tooltip: 'Dismiss',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
