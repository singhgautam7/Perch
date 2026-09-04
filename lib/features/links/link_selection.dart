import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Board 3f — long-press enters selection; the header becomes a selection bar
/// and the actions dock at the bottom.
@immutable
class LinkSelection {
  const LinkSelection({this.active = false, this.ids = const <int>{}});

  final bool active;
  final Set<int> ids;

  bool get isEmpty => ids.isEmpty;

  bool contains(int id) => ids.contains(id);
}

class LinkSelectionNotifier extends Notifier<LinkSelection> {
  @override
  LinkSelection build() => const LinkSelection();

  /// Entering with the card that was held already selected — otherwise the
  /// gesture would appear to do nothing.
  void start(int id) => state = LinkSelection(active: true, ids: <int>{id});

  /// Entering empty, from the header overflow.
  void enter() => state = const LinkSelection(active: true);

  void selectAll(Iterable<int> ids) =>
      state = LinkSelection(active: true, ids: ids.toSet());

  void toggle(int id) {
    final Set<int> next = <int>{...state.ids};
    if (!next.remove(id)) next.add(id);
    // Emptying the selection leaves the mode, which is the way back out.
    state = next.isEmpty
        ? const LinkSelection()
        : LinkSelection(active: true, ids: next);
  }

  void clear() => state = const LinkSelection();
}

final NotifierProvider<LinkSelectionNotifier, LinkSelection>
linkSelectionProvider =
    NotifierProvider<LinkSelectionNotifier, LinkSelection>(
      LinkSelectionNotifier.new,
    );
