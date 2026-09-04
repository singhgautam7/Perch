import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/db/link_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/services/import_export.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/tag_picker.dart';
import '../folders/folder_picker.dart';
import 'link_actions.dart';
import 'link_selection.dart';

/// A tap on a card: in selection mode it toggles, otherwise it opens the link.
void onLinkTapped(
  BuildContext context,
  WidgetRef ref,
  LinkWithTags item,
  LinkSelection selection,
) {
  if (selection.active) {
    ref.read(linkSelectionProvider.notifier).toggle(item.link.id);
  } else {
    context.push(Routes.link(item.link.id));
  }
}

/// A hold on a card: in selection mode it toggles, otherwise the quick menu.
void onLinkHeld(
  BuildContext context,
  WidgetRef ref,
  LinkWithTags item,
  Offset at,
  LinkSelection selection,
) {
  if (selection.active) {
    ref.read(linkSelectionProvider.notifier).toggle(item.link.id);
  } else {
    showLinkQuickMenu(context, ref, item.link, at);
  }
}

/// Board 3f — the header becomes a selection bar while a selection is live.
class SelectionBar extends ConsumerWidget {
  const SelectionBar({required this.visible, super.key});

  /// What "select all" can reach: the page currently loaded.
  final List<LinkWithTags> visible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final LinkSelection selection = ref.watch(linkSelectionProvider);
    final LinkSelectionNotifier notifier = ref.read(
      linkSelectionProvider.notifier,
    );

    return ColoredBox(
      color: c.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.lg, 14, Space.lg, Space.md),
        child: Row(
          children: <Widget>[
            AppIconButton(
              icon: Icons.close_rounded,
              onPressed: notifier.clear,
              semanticLabel: 'Leave selection',
              filled: false,
              tint: c.onPrimaryContainer,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${selection.ids.length} selected',
                style: PerchType.title
                    .copyWith(fontSize: 17, color: c.onPrimaryContainer)
                    .weight(600),
              ),
            ),
            AppIconButton(
              icon: Icons.select_all_rounded,
              onPressed: () => notifier.selectAll(
                visible.map((LinkWithTags i) => i.link.id),
              ),
              semanticLabel: 'Select all loaded links',
              filled: false,
              tint: c.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

/// Board 3f — the bulk actions float where the nav pill was.
class SelectionActionBar extends ConsumerWidget {
  const SelectionActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final LinkSelection selection = ref.watch(linkSelectionProvider);
    final List<int> ids = selection.ids.toList(growable: false);
    final bool enabled = ids.isNotEmpty;

    return Positioned(
      left: Space.screen,
      right: Space.screen,
      bottom: 22,
      child: Container(
        padding: const EdgeInsets.all(Space.row),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.outline),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: c.shadow,
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _Action(
              icon: Icons.drive_file_move_outline,
              label: 'Move',
              enabled: enabled,
              onTap: () => _move(context, ref, ids),
            ),
            _Action(
              icon: Icons.sell_outlined,
              label: 'Tag',
              enabled: enabled,
              onTap: () => _tag(context, ref, ids),
            ),
            _Action(
              icon: Icons.ios_share_rounded,
              label: 'Export',
              enabled: enabled,
              onTap: () => _export(context, ref, ids),
            ),
            _Action(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              danger: true,
              enabled: enabled,
              onTap: () => _delete(context, ref, ids),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    List<int> ids,
  ) async {
    final FolderChoice? choice = await showFolderPicker(context);
    if (choice == null) return;
    await ref.read(linkRepositoryProvider).moveAllToFolder(ids, choice.folderId);
    ref.read(linkSelectionProvider.notifier).clear();
    if (context.mounted) {
      AppSnackbar.success(context, 'Moved ${ids.length} to ${choice.name}');
    }
  }

  Future<void> _tag(BuildContext context, WidgetRef ref, List<int> ids) async {
    final List<int>? picked = await showTagPicker(context);
    if (picked == null || picked.isEmpty) return;
    await ref.read(tagRepositoryProvider).addToLinks(ids, picked);
    ref.read(linkSelectionProvider.notifier).clear();
    if (context.mounted) {
      AppSnackbar.success(context, 'Tagged ${ids.length} links');
    }
  }

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    List<int> ids,
  ) async {
    final String json = await ref
        .read(importExportProvider)
        .exportJson(onlyLinkIds: ids);
    await SharePlus.instance.share(
      ShareParams(text: json, subject: 'Perch — ${ids.length} links'),
    );
    ref.read(linkSelectionProvider.notifier).clear();
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    List<int> ids,
  ) async {
    final bool done = await confirmDeleteLinks(context, ref, ids);
    if (done) ref.read(linkSelectionProvider.notifier).clear();
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final Color fg = !enabled
        ? c.onSurfaceMuted
        : (danger ? c.danger : c.onSurface);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(Radii.thumb),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: 6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: <Widget>[
              Icon(icon, size: 18, color: fg),
              Text(
                label,
                style: PerchType.label
                    .copyWith(fontSize: 11, color: fg)
                    .weight(600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
