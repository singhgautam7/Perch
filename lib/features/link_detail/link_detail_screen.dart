import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/db/database.dart';
import '../../core/db/link_repository.dart';
import '../../core/providers.dart';
import '../../core/services/link_saver.dart';
import '../../core/router/router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/url.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_menu.dart';
import '../../shared/widgets/breadcrumb.dart';
import '../../shared/widgets/link_thumbnail.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/tag_chip.dart';
import '../folders/folder_providers.dart';
import '../links/link_actions.dart';
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

/// Boards 1f and 3d — the note is the body of this screen; metadata is one
/// collapsed row under it. The title is static: editing is an explicit act,
/// and the pencil in the header opens the Add/Edit screen.
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

  Link get _link => widget.data.link;
  LinkRepository get _repo => ref.read(linkRepositoryProvider);

  Future<void> _open() => openLink(context, ref, _link);

  /// B8 — a tick in the note writes straight back into the markdown.
  Future<void> _saveNote(String markdown) =>
      _repo.update(_link.id, LinksCompanion(note: Value<String>(markdown)));

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final List<Crumb> crumbs =
        ref.watch(breadcrumbProvider(_link.folderId)).valueOrNull ??
        const <Crumb>[];

    return Column(
      children: <Widget>[
        AppHeader(
          title: '',
          onBack: () => context.pop(),
          actions: <Widget>[
            AppIconButton(
              icon: Icons.edit_outlined,
              onPressed: () => context.push(Routes.editLink(_link.id)),
              semanticLabel: 'Edit link',
            ),
            AppIconButton(
              icon: Icons.ios_share_rounded,
              onPressed: () => SharePlus.instance.share(
                ShareParams(uri: Uri.parse(_link.url)),
              ),
              semanticLabel: 'Share link',
            ),
            _OverflowButton(link: _link),
          ],
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
              // Tapping the hero or the title opens the link.
              Semantics(
                button: true,
                label: 'Open link',
                child: GestureDetector(
                  onTap: _open,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: SizedBox(
                          height: 186,
                          width: double.infinity,
                          child: LinkThumbnail(
                            url: _link.url,
                            imageUrl: _link.imageUrl,
                            faviconUrl: _link.faviconUrl,
                            size: 186,
                            radius: 0,
                            fill: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: Space.lg),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: Space.row,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              _link.title.isEmpty
                                  ? hostOf(_link.url)
                                  : _link.title,
                              style: PerchType.title.copyWith(
                                fontSize: 21,
                                height: 1.25,
                                color: c.onSurface,
                              ),
                            ),
                          ),
                          _PinButton(link: _link),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${hostOf(_link.url)} · saved '
                        '${shortAge(_link.createdAt)} ago',
                        style: PerchType.monoLabel.copyWith(
                          fontSize: 12,
                          color: c.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.data.tags.isNotEmpty) ...<Widget>[
                const SizedBox(height: Space.md),
                _TagRow(data: widget.data),
              ],
              const SizedBox(height: Space.lg),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: c.outline),
                ),
                child: NoteView(markdown: _link.note, onToggle: _saveNote),
              ),
              const SizedBox(height: Space.md),
              MetadataCard(
                link: _link,
                open: _metadataOpen,
                onToggle: () => setState(() => _metadataOpen = !_metadataOpen),
              ),
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
}

/// Board 3f — the pin lives on the card as a star; here it is the same toggle.
class _PinButton extends ConsumerWidget {
  const _PinButton({required this.link});

  final Link link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    return Semantics(
      button: true,
      selected: link.isFavorite,
      label: link.isFavorite ? 'Unpin' : 'Pin to top',
      child: GestureDetector(
        onTap: () => ref
            .read(linkRepositoryProvider)
            .setFavorite(link.id, value: !link.isFavorite),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(
            child: Text(
              link.isFavorite ? '★' : '☆',
              style: TextStyle(
                fontSize: 20,
                height: 1,
                color: link.isFavorite ? c.primary : c.onSurfaceMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Everything secondary. Delete is separated by a rule and takes the danger
/// role (board 3d).
enum _DetailMenu { copy, move, refresh, delete }

class _OverflowButton extends ConsumerWidget {
  const _OverflowButton({required this.link});

  final Link link;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Builder(
      builder: (BuildContext anchor) => AppIconButton(
        icon: Icons.more_vert_rounded,
        semanticLabel: 'More actions',
        onPressed: () async {
          final _DetailMenu? picked = await showAppMenu<_DetailMenu>(
            context: anchor,
            anchorContext: anchor,
            minWidth: 220,
            entries: const <AppMenuEntry<_DetailMenu>>[
              AppMenuEntry<_DetailMenu>(
                value: _DetailMenu.copy,
                label: 'Copy URL',
              ),
              AppMenuEntry<_DetailMenu>(
                value: _DetailMenu.move,
                label: 'Move to folder…',
              ),
              AppMenuEntry<_DetailMenu>(
                value: _DetailMenu.refresh,
                label: 'Refresh metadata',
              ),
              AppMenuEntry<_DetailMenu>.divider(),
              AppMenuEntry<_DetailMenu>(
                value: _DetailMenu.delete,
                label: 'Delete link',
                danger: true,
              ),
            ],
          );
          if (picked == null || !context.mounted) return;
          switch (picked) {
            case _DetailMenu.copy:
              await runLinkAction(context, ref, link, LinkAction.copy);
            case _DetailMenu.move:
              await runLinkAction(context, ref, link, LinkAction.move);
            case _DetailMenu.refresh:
              await ref.read(linkSaverProvider).refresh(link.id);
            case _DetailMenu.delete:
              final bool gone = await confirmDeleteLinks(
                context,
                ref,
                <int>[link.id],
              );
              if (gone && context.mounted) context.pop();
          }
        },
      ),
    );
  }
}

/// Board 3d — tags are real chips in their own colour and each one filters.
///
/// There is no add affordance here: tags are changed on the Add/Edit screen the
/// header pencil opens, which is the one place that edits a link.
class _TagRow extends StatelessWidget {
  const _TagRow({required this.data});

  final LinkWithTags data;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Wrap(
      spacing: 7,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (final Tag tag in data.tags)
          TagChip(
            label: tag.name,
            selected: true,
            color: c.tagColor(tag.color),
            onTap: () => context.push(Routes.tagged(tag.id)),
          ),
      ],
    );
  }
}
