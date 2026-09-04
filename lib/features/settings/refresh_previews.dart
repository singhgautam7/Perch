import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/services/link_saver.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/url.dart';
import '../../shared/widgets/app_button.dart';
import '../links/link_feed.dart';

/// B10 — where the batch refresh has got to.
@immutable
class RefreshProgress {
  const RefreshProgress({
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.failed = 0,
    this.missing = 0,
    this.current,
  });

  final bool running;
  final int done;
  final int total;
  final int failed;

  /// How many links have no preview image right now — the idle row's count.
  final int missing;

  /// The host being fetched, so the card is never silently busy.
  final String? current;
}

/// Re-fetches metadata for every link missing a preview image.
///
/// One at a time and off the UI isolate (the fetcher parses HTML in `compute`),
/// so the rest of Perch stays usable while it runs.
class RefreshPreviewsNotifier extends Notifier<RefreshProgress> {
  bool _cancelled = false;

  @override
  RefreshProgress build() {
    // The idle count follows the table, so finishing a run updates the row.
    ref.watch(linkChangeSignalProvider);
    unawaited(_countMissing());
    return const RefreshProgress();
  }

  Future<void> _countMissing() async {
    final int n = (await ref.read(linkRepositoryProvider).missingPreviews())
        .length;
    if (!state.running) state = RefreshProgress(missing: n);
  }

  Future<void> start() async {
    if (state.running) return;
    _cancelled = false;
    final List<Link> targets = await ref
        .read(linkRepositoryProvider)
        .missingPreviews();
    state = RefreshProgress(
      running: true,
      total: targets.length,
      missing: targets.length,
    );

    int failed = 0;
    for (int i = 0; i < targets.length; i++) {
      if (_cancelled) break;
      state = RefreshProgress(
        running: true,
        done: i,
        total: targets.length,
        failed: failed,
        missing: targets.length - i,
        current: hostOf(targets[i].url),
      );
      try {
        await ref.read(linkSaverProvider).refresh(targets[i].id);
      } on Object {
        failed++;
      }
    }
    state = RefreshProgress(failed: failed);
    await _countMissing();
  }

  void stop() => _cancelled = true;
}

final NotifierProvider<RefreshPreviewsNotifier, RefreshProgress>
refreshPreviewsProvider =
    NotifierProvider<RefreshPreviewsNotifier, RefreshProgress>(
      RefreshPreviewsNotifier.new,
    );

/// Board 3g — a progress card rather than a blocking dialog, with a stop and an
/// honest count of failures.
class RefreshProgressCard extends ConsumerWidget {
  const RefreshProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final RefreshProgress p = ref.watch(refreshPreviewsProvider);
    final double fraction = p.total == 0 ? 0 : p.done / p.total;

    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            spacing: 11,
            children: <Widget>[
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.accent,
                ),
              ),
              Expanded(
                child: Text(
                  'Refreshing previews',
                  style: PerchType.titleMedium.copyWith(
                    fontSize: 14,
                    color: c.onSurface,
                  ),
                ),
              ),
              Text(
                '${p.done} / ${p.total}',
                style: PerchType.monoLabel.copyWith(
                  fontSize: 12,
                  color: c.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: Radii.fullR,
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: c.surfaceContainerHigh,
            ),
          ),
          const SizedBox(height: 11),
          Text(
            p.current == null
                ? 'Starting…'
                : '${p.current} · fetching metadata. You can keep using Perch.',
            style: PerchType.bodySmall.copyWith(color: c.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 13),
          Row(
            spacing: Space.sm,
            children: <Widget>[
              AppButton(
                label: 'Stop',
                type: AppButtonType.outlined,
                compact: true,
                onPressed: ref.read(refreshPreviewsProvider.notifier).stop,
              ),
              if (p.failed > 0)
                Text(
                  '${p.failed} failed — retry later',
                  style: PerchType.label.copyWith(
                    fontSize: 12,
                    color: c.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
