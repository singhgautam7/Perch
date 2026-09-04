import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/url.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/states.dart';
import 'stats_providers.dart';

/// Board 1h — three counts, one chart, one ranked list, two prompts that lead
/// somewhere. Everything numeric is tabular mono so the columns hold still.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PerchStats> stats = ref.watch(statsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppHeader(
              title: 'Stats',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: stats.when(
                loading: () => const SizedBox.shrink(),
                error: (Object e, StackTrace _) => ErrorStateView(message: '$e'),
                data: (PerchStats s) => ListView(
                padding: const EdgeInsets.fromLTRB(
                  Space.screen,
                  0,
                  Space.screen,
                  Space.bottomSafe,
                ),
                children: <Widget>[
                  Row(
                    spacing: Space.sm,
                    children: <Widget>[
                      Expanded(
                        child: _Count(
                          value: s.links,
                          label: 'Links',
                          big: true,
                        ),
                      ),
                      Expanded(
                        child: _Count(value: s.folders, label: 'Folders'),
                      ),
                      Expanded(child: _Count(value: s.tags, label: 'Tags')),
                    ],
                  ),
            const SizedBox(height: Space.md),
            _Card(
              title: 'Saved per week',
              caption: 'Last 12 weeks',
              trailing: 'This week · ${s.thisWeek}',
              child: _WeeklyChart(values: s.perWeek),
            ),
            const SizedBox(height: Space.md),
            if (s.topDomains.isNotEmpty)
              _Card(
                title: 'Top domains',
                child: Column(
                  children: <Widget>[
                    for (final ({String domain, int count}) d in s.topDomains)
                      _DomainBar(
                        domain: d.domain,
                        count: d.count,
                        max: s.topDomains.first.count,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: Space.md),
            // The only two cards that ask for action, and both lead into search.
            if (s.unsorted > 0)
              _Prompt(
                label: 'Unsorted',
                value: plural(s.unsorted, 'link'),
                action: 'File them →',
                onTap: () => context.push(Routes.search),
              ),
            if (s.oldestUnopened != null) ...<Widget>[
              const SizedBox(height: Space.sm),
              _Prompt(
                label: 'Oldest unopened',
                value: s.oldestUnopened!.title.isEmpty
                    ? hostOf(s.oldestUnopened!.url)
                    : s.oldestUnopened!.title,
                action: 'saved ${shortAge(s.oldestUnopened!.createdAt)} ago',
                onTap: () => context.push(Routes.link(s.oldestUnopened!.id)),
              ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);
}
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label, this.big = false});

  final int value;
  final String label;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: Space.lg),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.cardR,
        border: Border.all(color: c.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            grouped(value),
            style: PerchType.monoTabular.copyWith(
              fontSize: big ? 30 : 22,
              color: big ? c.accent : c.onSurface,
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(
            label.toUpperCase(),
            style: PerchType.sectionHeader.copyWith(
              fontSize: 10,
              color: c.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.child,
    this.caption,
    this.trailing,
  });

  final String title;
  final Widget child;
  final String? caption;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.cardR,
        border: Border.all(color: c.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: PerchType.titleMedium.copyWith(color: c.onSurface),
                ),
              ),
              if (caption != null)
                Text(
                  caption!.toUpperCase(),
                  style: PerchType.sectionHeader.copyWith(
                    fontSize: 10,
                    color: c.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
          child,
          if (trailing != null) ...<Widget>[
            const SizedBox(height: Space.md),
            Text(
              trailing!.toUpperCase(),
              style: PerchType.sectionHeader.copyWith(
                fontSize: 10,
                color: c.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final int peak = values.fold<int>(1, (int a, int b) => a > b ? a : b);
    return SizedBox(
      height: 90,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 6,
        children: <Widget>[
          for (int i = 0; i < values.length; i++)
            Expanded(
              child: Semantics(
                label: '${values[i]} saved',
                child: Container(
                  height: 8 + 82 * (values[i] / peak),
                  decoration: BoxDecoration(
                    // This week is the one that gets the accent.
                    color: i == values.length - 1
                        ? c.primary
                        : c.surfaceContainerHigh,
                    borderRadius: Radii.chipR,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DomainBar extends StatelessWidget {
  const _DomainBar({
    required this.domain,
    required this.count,
    required this.max,
  });

  final String domain;
  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.row),
      child: Row(
        spacing: Space.md,
        children: <Widget>[
          SizedBox(
            width: 116,
            child: Text(
              domain,
              style: PerchType.monoLabel.copyWith(color: c.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: Radii.chipR,
              child: LinearProgressIndicator(
                value: count / max,
                minHeight: 8,
                backgroundColor: c.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(c.primary),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: PerchType.monoLabel.copyWith(color: c.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({
    required this.label,
    required this.value,
    required this.action,
    required this.onTap,
  });

  final String label;
  final String value;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Material(
      color: c.surfaceContainer,
      borderRadius: Radii.cardR,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            borderRadius: Radii.cardR,
            border: Border.all(color: c.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label.toUpperCase(),
                style: PerchType.sectionHeader.copyWith(
                  fontSize: 10,
                  color: c.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: PerchType.titleMedium.copyWith(color: c.onSurface),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                action,
                style: PerchType.labelStrong.copyWith(color: c.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
