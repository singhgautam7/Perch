import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/db/database.dart';
import '../../core/db/link_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_menu.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/tag_picker.dart';
import '../folders/folder_picker.dart';
import 'link_selection.dart';

/// Board 3d — the long-press menu. Every one of these is also reachable from
/// Link detail; this is the shortcut layer, not a second set of behaviours.
enum LinkAction { open, share, copy, edit, move, tag, pin, select, delete }

/// Opens the link in the browser and records the open, so the unopened dot
/// clears and the "Recently opened" sort has something to sort on (B4).
Future<void> openLink(BuildContext context, WidgetRef ref, Link link) async {
  unawaited(ref.read(linkRepositoryProvider).markOpened(link.id));
  final Uri? uri = Uri.tryParse(link.url);
  final bool ok =
      uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    AppSnackbar.error(context, 'Nothing here can open that link');
  }
}

/// The quick-action menu, opened beside the card the finger is holding.
Future<void> showLinkQuickMenu(
  BuildContext context,
  WidgetRef ref,
  Link link,
  Offset at,
) async {
  final LinkAction? action = await showAppMenu<LinkAction>(
    context: context,
    globalPosition: at,
    minWidth: 196,
    entries: <AppMenuEntry<LinkAction>>[
      const AppMenuEntry<LinkAction>(value: LinkAction.open, label: 'Open'),
      const AppMenuEntry<LinkAction>(value: LinkAction.share, label: 'Share'),
      const AppMenuEntry<LinkAction>(value: LinkAction.copy, label: 'Copy URL'),
      const AppMenuEntry<LinkAction>(value: LinkAction.edit, label: 'Edit'),
      const AppMenuEntry<LinkAction>(value: LinkAction.move, label: 'Move'),
      const AppMenuEntry<LinkAction>(value: LinkAction.tag, label: 'Tag'),
      AppMenuEntry<LinkAction>(
        value: LinkAction.pin,
        label: link.isFavorite ? 'Unpin' : 'Pin to top',
      ),
      // Board 3f enters selection by holding one card and tapping a second;
      // that gesture is indistinguishable from dismissing this menu, so the
      // way in is a row on the menu the hold already opened.
      const AppMenuEntry<LinkAction>(value: LinkAction.select, label: 'Select'),
      const AppMenuEntry<LinkAction>.divider(),
      const AppMenuEntry<LinkAction>(
        value: LinkAction.delete,
        label: 'Delete',
        danger: true,
      ),
    ],
  );
  if (action == null || !context.mounted) return;
  await runLinkAction(context, ref, link, action);
}

Future<void> runLinkAction(
  BuildContext context,
  WidgetRef ref,
  Link link,
  LinkAction action,
) async {
  final LinkRepository repo = ref.read(linkRepositoryProvider);
  switch (action) {
    case LinkAction.open:
      await openLink(context, ref, link);
    case LinkAction.share:
      await SharePlus.instance.share(ShareParams(uri: Uri.parse(link.url)));
    case LinkAction.copy:
      await Clipboard.setData(ClipboardData(text: link.url));
      if (context.mounted) AppSnackbar.info(context, 'Copied link to clipboard');
    case LinkAction.edit:
      unawaited(context.push(Routes.editLink(link.id)));
    case LinkAction.move:
      final FolderChoice? choice = await showFolderPicker(context);
      if (choice == null || !context.mounted) return;
      await repo.moveToFolder(link.id, choice.folderId);
      if (context.mounted) {
        AppSnackbar.success(context, 'Moved to ${choice.name}');
      }
    case LinkAction.tag:
      final List<Tag> current = await ref
          .read(tagRepositoryProvider)
          .forLink(link.id);
      if (!context.mounted) return;
      final List<int>? picked = await showTagPicker(
        context,
        selected: current.map((Tag t) => t.id).toList(growable: false),
      );
      if (picked == null) return;
      await ref.read(tagRepositoryProvider).setForLinkByIds(link.id, picked);
    case LinkAction.pin:
      await repo.setFavorite(link.id, value: !link.isFavorite);
      if (context.mounted) {
        AppSnackbar.info(
          context,
          link.isFavorite ? 'Unpinned' : 'Pinned to the top',
        );
      }
    case LinkAction.select:
      ref.read(linkSelectionProvider.notifier).start(link.id);
    case LinkAction.delete:
      await confirmDeleteLinks(context, ref, <int>[link.id]);
  }
}

/// One confirmation for both the single delete and the bulk one (B2).
Future<bool> confirmDeleteLinks(
  BuildContext context,
  WidgetRef ref,
  List<int> ids,
) async {
  final bool? confirmed = await showAppBottomSheet<bool>(
    context: context,
    title: ids.length == 1
        ? 'Delete this link?'
        : 'Delete ${ids.length} links?',
    description: 'The link and its note go for good.',
    builder: (BuildContext sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppButton(
          label: 'Delete',
          type: AppButtonType.danger,
          fullWidth: true,
          onPressed: () => Navigator.of(sheetContext).pop(true),
        ),
        const SizedBox(height: Space.sm),
        AppButton(
          label: 'Keep it',
          type: AppButtonType.outlined,
          fullWidth: true,
          onPressed: () => Navigator.of(sheetContext).pop(false),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;
  await ref.read(linkRepositoryProvider).deleteAll(ids);
  return true;
}
