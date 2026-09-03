import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import 'nav_bar.dart';

/// Hosts the four destinations and the floating nav.
///
/// The pill and the FAB translate down 72 and fade out on scroll-down past
/// 24px, and come back on any scroll-up (board 1b, "Scroll behaviour").
class NavShell extends StatefulWidget {
  const NavShell({
    required this.child,
    required this.index,
    required this.onSelect,
    required this.onAdd,
    required this.tabCount,
    super.key,
  });

  final Widget child;
  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;
  final int tabCount;

  @override
  State<NavShell> createState() => _NavShellState();
}

class _NavShellState extends State<NavShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hide = AnimationController(
    vsync: this,
    duration: Motion.navHide,
  );
  double _lastOffset = 0;

  @override
  void dispose() {
    _hide.dispose();
    super.dispose();
  }

  /// A horizontal fling anywhere on the page moves to the next destination.
  /// Vertical drags belong to the list, so only a decisive horizontal one wins.
  void _onHorizontalFling(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 240) return;
    final int next = velocity < 0 ? widget.index + 1 : widget.index - 1;
    if (next < 0 || next >= widget.tabCount) return;
    widget.onSelect(next);
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n is! ScrollUpdateNotification) {
      return false;
    }
    final double offset = n.metrics.pixels;
    final double delta = offset - _lastOffset;
    if (delta.abs() < 2) return false;
    _lastOffset = offset;

    if (delta > 0 && offset > 24) {
      _hide.forward();
    } else if (delta < 0) {
      _hide.reverse();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = Motion.reduced(context);
    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          children: <Widget>[
            GestureDetector(
              onHorizontalDragEnd: _onHorizontalFling,
              // Transparent, not opaque: the pages underneath still get their
              // own taps and vertical drags.
              behavior: HitTestBehavior.translucent,
              child: widget.child,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 22,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _hide,
                  builder: (BuildContext context, Widget? child) {
                    final double t = _hide.value;
                    return Opacity(
                      opacity: 1 - t,
                      child: Transform.translate(
                        offset: Offset(0, reduced ? 0 : 72 * t),
                        child: IgnorePointer(ignoring: t > 0.5, child: child),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: Space.row,
                    children: <Widget>[
                      PerchNavPill(
                        index: widget.index,
                        onSelect: widget.onSelect,
                      ),
                      PerchFab(onTap: widget.onAdd),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
