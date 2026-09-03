import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/db/database.dart';
import '../../core/db/link_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/services/link_saver.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/url.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/breadcrumb.dart';
import '../../shared/widgets/markdown_editor.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/tag_chip.dart';
import '../add_link/tag_field.dart';
import '../folders/folder_picker.dart';
import '../folders/folder_providers.dart';
import '../links/link_feed.dart';
import 'metadata_card.dart';
import 'note_view.dart';

/// One saved link, re-read whenever anything in the links table changes.
final FutureProviderFamily<LinkWithTags?, int> linkDetailProvider =
    FutureProvider.family<LinkWithTags?, int>((Ref ref, int id) async {
      ref.watch(linkChangeSignalProvider);
      final LinkRepository repo = ref.watch(linkRepositoryProvider);
      final Link? link = await repo.byId(id);
      if (link == null) return null;
      return (await repo.withTags(<Link>[link])).firstOrNull;
    });

/// Board 1f — the note is the body of this screen; metadata is one collapsed
/// row above it. That ordering is the whole point of "link = note".
class LinkDetailScreen extends ConsumerWidget {
  const LinkDetailScreen({required this.linkId, super.key});

  final int linkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LinkWithTags?> link = ref.watch(
      linkDetailProvider(linkId),
    );
    return Scaffold(
      body: SafeArea(
        child: link.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace _) => ErrorStateView(message: '$e'),
          data: (LinkWithTags? data) => data == null
              ? const EmptyState(
                  title: 'Gone',
                  message: 'This link is no longer saved.',
                  showMark: false,
                )
              : _Detail(data: data),
        ),
      ),
    );
  }
}

class _Detail extends ConsumerStatefulWidget {
  const _Detail({required this.data});

  final LinkWithTags data;

  @override
  ConsumerState<_Detail> createState() => _DetailState();
}

class _DetailState extends ConsumerState<_Detail> {
  bool _metadataOpen = false;
  bool _editingNote = false;
  bool _editingTitle = false;
  TextEditingController? _note;
  TextEditingController? _title;

  Link get _link => widget.data.link;

  @override
  void dispose() {
    _note?.dispose();
    _title?.dispose();
    super.dispose();
  }

  LinkRepository get _repo => ref.read(linkRepositoryProvider);

  Future<void> _open() async {
    final Uri uri = Uri.parse(_link.url);
    unawaited(_repo.markOpened(_link.id));
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) AppSnackbar.error(context, 'Nothing here can open that link');
    }
  }

  void _startEditingNote() {
    setState(() {
      _note = TextEditingController(text: _link.note);
      _editingNote = true;
    });
  }

  Future<void> _saveNote() async {
    final String text = _note?.text ?? '';
    setState(() => _editingNote = false);
    await _repo.update(_link.id, LinksCompanion(note: Value<String>(text)));
    _note?.dispose();
    _note = null;
  }

  Future<void> _saveTitle() async {
    final String text = _title?.text.trim() ?? '';
    setState(() => _editingTitle = false);
    if (text.isNotEmpty && text != _link.title) {
      await _repo.update(_link.id, LinksCompanion(title: Value<String>(text)));
    }
    _title?.dispose();
    _title = null;
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final List<Crumb> crumbs =
        ref.watch(breadcrumbProvider(_link.folderId)).valueOrNull ??
        const <Crumb>[];

    return Column(
      children: <Widget>[
        _TopBar(
          link: _link,
          editingNote: _editingNote,
          onDone: _saveNote,
          onRefetch: () => ref.read(linkSaverProvider).refresh(_link.id),
          onDelete: () => _confirmDelete(context),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.screen,
              0,
              Space.screen,
              Space.xxl,
            ),
            children: <Widget>[
              if (crumbs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: Breadcrumb(
                    crumbs: crumbs,
                    onTap: (int? id) => context.go(
                      id == null ? Routes.folders : Routes.folder(id),
                    ),
                  ),
                ),
              _Title(
                link: _link,
                editing: _editingTitle,
                controller: _title,
                onStartEditing: () => setState(() {
                  _title = TextEditingController(text: _link.title);
                  _editingTitle = true;
                }),
                onDone: _saveTitle,
              ),
              const SizedBox(height: Space.sm),
              _DomainRow(link: _link),
              const SizedBox(height: Space.lg),
              AppButton(
                label: 'Open link ↗',
                fullWidth: true,
                onPressed: _open,
              ),
              const SizedBox(height: Space.row),
              MetadataCard(
                link: _link,
                open: _metadataOpen,
                onToggle: () => setState(() => _metadataOpen = !_metadataOpen),
                onRefetch: () => ref.read(linkSaverProvider).refresh(_link.id),
              ),
              const SizedBox(height: Space.lg),
              _TagRow(data: widget.data),
              const SizedBox(height: Space.lg),
              if (_editingNote)
                MarkdownEditor(
                  controller: _note!,
                  minLines: 8,
                  maxLines: 30,
                )
              else
                NoteView(markdown: _link.note, onTap: _startEditingNote),
              const SizedBox(height: Space.section),
              Text(
                'Saved ${longDate(_link.createdAt)}',
                textAlign: TextAlign.center,
                style: PerchType.monoSmall.copyWith(color: c.onSurfaceMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirmed = await showAppBottomSheet<bool>(
      context: context,
      title: 'Delete this link?',
      builder: (BuildContext sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'The link and its note go for good.',
            style: PerchType.body.copyWith(
              color: sheetContext.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.xl),
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
    if (confirmed != true || !context.mounted) return;
    await _repo.delete(_link.id);
    if (context.mounted) context.pop();
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.link,
    required this.editingNote,
    required this.onDone,
    required this.onRefetch,
    required this.onDelete,
  });

  final Link link;
  final bool editingNote;
  final VoidCallback onDone;
  final VoidCallback onRefetch;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, Space.sm),
      child: Row(
        children: <Widget>[
          AppIconButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () => context.pop(),
            semanticLabel: 'Back',
            size: 40,
          ),
          if (editingNote) ...<Widget>[
            Expanded(
              child: Text(
                'Editing note',
                style: PerchType.screenTitle.copyWith(color: c.onSurface),
              ),
            ),
            AppButton(label: 'Done', compact: true, onPressed: onDone),
          ] else ...<Widget>[
            const Spacer(),
            AppIconButton(
              icon: Icons.ios_share_rounded,
              onPressed: () => SharePlus.instance.share(
                ShareParams(uri: Uri.parse(link.url)),
              ),
              semanticLabel: 'Share link',
              size: 40,
              filled: false,
            ),
            _OverflowMenu(onRefetch: onRefetch, onDelete: onDelete),
          ],
        ],
      ),
    );
  }
}

class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu({required this.onRefetch, required this.onDelete});

  final VoidCallback onRefetch;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return SizedBox(
      width: IconSpec.tapTarget,
      height: IconSpec.tapTarget,
      child: PopupMenuButton<VoidCallback>(
        tooltip: 'More actions',
        icon: Icon(Icons.more_vert_rounded, color: c.icon),
        color: c.surfaceContainer,
        shape: const RoundedRectangleBorder(borderRadius: Radii.thumbR),
        onSelected: (VoidCallback action) => action(),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<VoidCallback>>[
          PopupMenuItem<VoidCallback>(
            value: onRefetch,
            child: Text('Re-fetch metadata', style: PerchType.body),
          ),
          PopupMenuItem<VoidCallback>(
            value: onDelete,
            child: Text(
              'Delete link',
              style: PerchType.body.copyWith(color: c.danger),
            ),
          ),
        ],
      ),
    );
  }
}

/// Long titles wrap to three lines and then clamp.
class _Title extends StatelessWidget {
  const _Title({
    required this.link,
    required this.editing,
    required this.controller,
    required this.onStartEditing,
    required this.onDone,
  });

  final Link link;
  final bool editing;
  final TextEditingController? controller;
  final VoidCallback onStartEditing;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final TextStyle style = PerchType.title.copyWith(
      fontSize: 26,
      height: 1.2,
      color: c.onSurface,
    );

    if (editing && controller != null) {
      return TextField(
        controller: controller,
        autofocus: true,
        maxLines: 3,
        style: style,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onDone(),
        onTapOutside: (_) => onDone(),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Edit title',
      child: GestureDetector(
        onTap: onStartEditing,
        behavior: HitTestBehavior.opaque,
        child: Text(
          link.title.isEmpty ? hostOf(link.url) : link.title,
          style: style,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// The domain row never wraps.
class _DomainRow extends StatelessWidget {
  const _DomainRow({required this.link});

  final Link link;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Text(
      '${hostOf(link.url)} · saved ${shortAge(link.createdAt)} ago',
      style: PerchType.monoLabel.copyWith(
        fontSize: 12,
        color: c.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Tags past three collapse to +N, which expands the row in place.
class _TagRow extends ConsumerStatefulWidget {
  const _TagRow({required this.data});

  final LinkWithTags data;

  @override
  ConsumerState<_TagRow> createState() => _TagRowState();
}

class _TagRowState extends ConsumerState<_TagRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final List<Tag> tags = widget.data.tags;
    final bool overflowing = tags.length > 3 && !_expanded;
    final List<Tag> shown = overflowing ? tags.sublist(0, 3) : tags;

    Future<void> setTags(List<String> names) => ref
        .read(tagRepositoryProvider)
        .setForLink(widget.data.link.id, names);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (final Tag tag in shown)
          TagChip(
            label: tag.name,
            style: ChipStyle.active,
            onRemove: () => setTags(
              tags
                  .where((Tag t) => t.id != tag.id)
                  .map((Tag t) => t.name)
                  .toList(growable: false),
            ),
          ),
        if (overflowing)
          TagChip(
            label: '+${tags.length - 3} more',
            onTap: () => setState(() => _expanded = true),
          ),
        TagChip(
          label: 'Add tag',
          style: ChipStyle.add,
          onTap: () async {
            final String? picked = await showTagPicker(
              context,
              exclude: tags.map((Tag t) => t.name).toList(growable: false),
            );
            if (picked == null) return;
            await setTags(<String>[
              ...tags.map((Tag t) => t.name),
              picked,
            ]);
          },
        ),
        _MoveChip(link: widget.data.link),
      ],
    );
  }
}

class _MoveChip extends ConsumerWidget {
  const _MoveChip({required this.link});

  final Link link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TagChip(
      label: 'Move ⇄',
      onTap: () async {
        final FolderChoice? choice = await showFolderPicker(context);
        if (choice == null || !context.mounted) return;
        await ref
            .read(linkRepositoryProvider)
            .moveToFolder(link.id, choice.folderId);
        if (context.mounted) {
          AppSnackbar.success(context, 'Moved to ${choice.name}');
        }
      },
    );
  }
}
