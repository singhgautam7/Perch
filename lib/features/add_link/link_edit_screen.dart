import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/tag_repository.dart';
import '../../core/providers.dart';
import '../../core/router/router.dart';
import '../../core/services/link_saver.dart';
import '../../core/services/metadata_fetcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../core/utils/url.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/dashed_border.dart';
import '../../shared/widgets/labelled_field.dart';
import '../../shared/widgets/link_thumbnail.dart';
import '../../shared/widgets/markdown_editor.dart';
import '../../shared/widgets/tag_chip.dart';
import '../../shared/widgets/tag_picker.dart';
import '../folders/folder_picker.dart';
import '../folders/folder_providers.dart';

/// Board 3b — Add and Edit are one full screen. Only the title, the preview
/// chip and the Save label change between them.
///
/// Nothing here is a bottom sheet: that form is reserved for the share flow,
/// where the system gives us less room and less time.
class LinkEditScreen extends ConsumerStatefulWidget {
  const LinkEditScreen({this.linkId, this.sharedUrl, super.key});

  /// Null adds; a value edits that link.
  final int? linkId;
  final String? sharedUrl;

  @override
  ConsumerState<LinkEditScreen> createState() => _LinkEditScreenState();
}

class _LinkEditScreenState extends ConsumerState<LinkEditScreen> {
  final TextEditingController _url = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _note = TextEditingController();

  Timer? _debounce;
  String? _clipboardOffer;
  bool _fetching = false;
  bool _saving = false;
  bool _loading = false;
  bool _dismissedDuplicate = false;
  MetadataResult? _result;
  Link? _existing;
  FolderChoice _folder = (folderId: null, name: 'Unsorted');
  List<int> _tagIds = <int>[];
  Link? _duplicate;

  bool get _isEdit => widget.linkId != null;
  bool get _hasUrl => looksLikeUrl(_url.text);

  @override
  void initState() {
    super.initState();
    _url.addListener(_onUrlChanged);
    if (_isEdit) {
      _loading = true;
      unawaited(_load());
    } else {
      _url.text = widget.sharedUrl ?? '';
      if (_hasUrl) _scheduleFetch();
      unawaited(_offerClipboard());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _url
      ..removeListener(_onUrlChanged)
      ..dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final int id = widget.linkId!;
    final Link? link = await ref.read(linkRepositoryProvider).byId(id);
    final List<Tag> tags = await ref.read(tagRepositoryProvider).forLink(id);
    if (!mounted || link == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final Map<int, String> paths = ref.read(folderPathsProvider);
    setState(() {
      _existing = link;
      _url.text = link.url;
      _title.text = link.title;
      _note.text = link.note;
      _tagIds = tags.map((Tag t) => t.id).toList();
      _folder = (
        folderId: link.folderId,
        name: link.folderId == null
            ? 'Unsorted'
            : paths[link.folderId!] ?? 'Folder',
      );
      _loading = false;
    });
  }

  /// Clipboard detection is an offer, not an action — nothing is filled in
  /// without a tap.
  Future<void> _offerClipboard() async {
    if (_hasUrl) return;
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? url = data?.text == null ? null : extractUrl(data!.text!);
    if (url != null && mounted) setState(() => _clipboardOffer = url);
  }

  void _onUrlChanged() {
    setState(() {});
    if (!_loading) _scheduleFetch();
  }

  /// Fetch begins on a valid URL, debounced 600ms.
  void _scheduleFetch() {
    _debounce?.cancel();
    if (!_hasUrl) {
      setState(() => _result = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), _fetch);
  }

  Future<void> _fetch() async {
    final String url = normalizeUrl(_url.text);
    setState(() => _fetching = true);
    unawaited(_checkDuplicate(url));
    final MetadataResult result = await ref
        .read(metadataFetcherProvider)
        .fetch(url);
    if (!mounted) return;
    setState(() {
      _fetching = false;
      _result = result;
    });
  }

  /// B6 — a normalized-URL lookup, never a block on saving.
  Future<void> _checkDuplicate(String url) async {
    final Link? found = await ref.read(linkRepositoryProvider).byUrl(url);
    if (!mounted) return;
    setState(() => _duplicate = found?.id == widget.linkId ? null : found);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final String url = normalizeUrl(_url.text);

    if (_isEdit) {
      await ref
          .read(linkRepositoryProvider)
          .update(
            widget.linkId!,
            LinksCompanion(
              url: Value<String>(url),
              title: Value<String>(_title.text.trim()),
              note: Value<String>(_note.text),
              folderId: Value<int?>(_folder.folderId),
            ),
          );
      await ref
          .read(tagRepositoryProvider)
          .setForLinkByIds(widget.linkId!, _tagIds);
      if (!mounted) return;
      AppSnackbar.success(context, 'Saved');
      context.pop(widget.linkId);
      return;
    }

    final int id = await ref
        .read(linkSaverProvider)
        .save(
          url: url,
          title: _title.text.trim(),
          note: _note.text,
          folderId: _folder.folderId,
          tagIds: _tagIds,
          metadata: _result?.metadata,
        );
    if (!mounted) return;
    AppSnackbar.success(context, 'Saved to ${_folder.name}');
    context.pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final String? suggested = _result?.metadata.title;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            AppHeader(
              title: _isEdit ? 'Edit link' : 'Add link',
              backLabel: 'Cancel',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        Space.screen,
                        0,
                        Space.screen,
                        Space.xl,
                      ),
                      children: <Widget>[
                        if (_clipboardOffer != null && !_hasUrl) ...<Widget>[
                          _ClipboardOffer(
                            url: _clipboardOffer!,
                            onUse: () {
                              _url.text = _clipboardOffer!;
                              setState(() => _clipboardOffer = null);
                            },
                          ),
                          const SizedBox(height: Space.md),
                        ],
                        LabelledField(
                          label: 'URL',
                          focused: !_hasUrl,
                          child: PlainTextField(
                            controller: _url,
                            autofocus: !_isEdit && _url.text.isEmpty,
                            keyboardType: TextInputType.url,
                            hint: 'https://',
                          ),
                        ),
                        const SizedBox(height: Space.md),
                        if (!_hasUrl)
                          const _UrlPlaceholder()
                        else
                          _PreviewCard(
                            url: normalizeUrl(_url.text),
                            fetching: _fetching,
                            result: _result,
                            existing: _existing,
                            chipLabel: _isEdit
                                ? 'Refresh metadata'
                                : 'Use suggested title',
                            onChip: _isEdit
                                ? _fetch
                                : (suggested == null
                                      ? null
                                      : () => setState(
                                          () => _title.text = suggested,
                                        )),
                          ),
                        if (_duplicate != null && !_dismissedDuplicate) ...[
                          const SizedBox(height: Space.md),
                          _DuplicateBanner(
                            link: _duplicate!,
                            onOpen: () =>
                                context.pushReplacement(
                                  Routes.link(_duplicate!.id),
                                ),
                            onSaveAnyway: () =>
                                setState(() => _dismissedDuplicate = true),
                          ),
                        ],
                        const SizedBox(height: Space.md),
                        LabelledField(
                          label: 'Title',
                          focused: _isEdit,
                          child: PlainTextField(
                            controller: _title,
                            hint: 'Untitled link',
                            style: PerchType.label.copyWith(
                              fontSize: 14,
                              color: c.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(height: Space.md),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 0, 2, 7),
                          child: Text(
                            'NOTE',
                            style: PerchType.sectionHeader.copyWith(
                              fontSize: 9.5,
                              letterSpacing: 0.86,
                              color: c.onSurfaceVariant,
                            ),
                          ),
                        ),
                        MarkdownEditor(controller: _note, maxLines: 20),
                        const SizedBox(height: Space.md),
                        _PickerRow(
                          label: 'Folder',
                          value: _folder.name,
                          actionLabel: 'Change',
                          onTap: () async {
                            final FolderChoice? picked =
                                await showFolderPicker(
                                  context,
                                  title: 'Choose folder',
                                );
                            if (picked != null) {
                              setState(() => _folder = picked);
                            }
                          },
                        ),
                        const SizedBox(height: Space.md),
                        _TagsRow(
                          tagIds: _tagIds,
                          onChanged: (List<int> ids) =>
                              setState(() => _tagIds = ids),
                        ),
                      ],
                    ),
            ),
            _SaveBar(
              label: _isEdit ? 'Save changes' : 'Save',
              enabled: _hasUrl && !_saving,
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Sticky, and disabled until a URL resolves or is accepted as-is.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Space.screen,
        Space.md,
        Space.screen,
        Space.screen,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.outline)),
      ),
      child: SizedBox(
        height: 52,
        child: AppButton(
          label: label,
          fullWidth: true,
          loading: loading,
          onPressed: enabled ? onPressed : null,
        ),
      ),
    );
  }
}

class _ClipboardOffer extends StatelessWidget {
  const _ClipboardOffer({required this.url, required this.onUse});

  final String url;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 11),
      decoration: BoxDecoration(
        color: c.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        spacing: Space.row,
        children: <Widget>[
          Expanded(
            child: Text(
              'On your clipboard — ${middleTruncate(url)}',
              style: PerchType.bodySmall.copyWith(
                fontSize: 12.5,
                color: c.onPrimaryContainer,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppButton(label: 'Paste', compact: true, onPressed: onUse),
        ],
      ),
    );
  }
}

/// What the preview slot says before there is a URL to fetch.
class _UrlPlaceholder extends StatelessWidget {
  const _UrlPlaceholder();

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return CustomPaint(
      foregroundPainter: DashedBorderPainter(c.outline, radius: 18),
      child: Container(
        height: 104,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        child: Text(
          'Add a URL and Perch fetches the title, description and preview '
          'image',
          textAlign: TextAlign.center,
          style: PerchType.bodySmall.copyWith(
            fontSize: 12.5,
            height: 1.45,
            color: c.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}

/// The preview ladder: fetching → og:image → favicon → monogram.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.url,
    required this.fetching,
    required this.result,
    required this.existing,
    required this.chipLabel,
    required this.onChip,
  });

  final String url;
  final bool fetching;
  final MetadataResult? result;

  /// In edit mode the card shows what is already stored until a refetch lands.
  final Link? existing;
  final String chipLabel;
  final VoidCallback? onChip;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final LinkMetadata? meta = result?.metadata;
    final String? image = meta?.imageUrl ?? existing?.imageUrl;
    final String? favicon = meta?.faviconUrl ?? existing?.faviconUrl;
    final String title =
        meta?.title ??
        (existing?.title.isNotEmpty ?? false
            ? existing!.title
            : (result?.outcome == MetadataOutcome.failed
                  ? "That link couldn't be read"
                  : 'No preview yet'));

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Space.md,
        children: <Widget>[
          SizedBox(
            width: 64,
            height: 64,
            child: fetching
                ? const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    child: ThumbnailSkeleton(),
                  )
                : LinkThumbnail(
                    url: url,
                    imageUrl: image,
                    faviconUrl: favicon,
                    size: 64,
                    radius: 12,
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  fetching ? 'Fetching preview…' : title,
                  style: PerchType.titleSmall.copyWith(color: c.onSurface),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Space.xs),
                Text(
                  hostOf(url),
                  style: PerchType.monoLabel.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
                if (onChip != null) ...<Widget>[
                  const SizedBox(height: Space.sm),
                  _AccentPill(label: chipLabel, onTap: onChip!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The small accent pill the board uses for a suggestion or a sub-action.
class _AccentPill extends StatelessWidget {
  const _AccentPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.fullR,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Space.row, vertical: 5),
          decoration: BoxDecoration(
            color: c.primaryContainer,
            borderRadius: Radii.fullR,
          ),
          child: Text(
            label,
            style: PerchType.label
                .copyWith(fontSize: 11, color: c.onPrimaryContainer)
                .weight(600),
          ),
        ),
      ),
    );
  }
}

/// B6 — the designed duplicate state. It never blocks the save.
class _DuplicateBanner extends ConsumerWidget {
  const _DuplicateBanner({
    required this.link,
    required this.onOpen,
    required this.onSaveAnyway,
  });

  final Link link;
  final VoidCallback onOpen;
  final VoidCallback onSaveAnyway;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final Map<int, String> paths = ref.watch(folderPathsProvider);
    final String where = link.folderId == null
        ? 'Unsorted'
        : paths[link.folderId!] ?? 'a folder';

    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        color: c.warnContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'You already saved this',
            style: PerchType.label
                .copyWith(fontSize: 12.5, color: c.onWarnContainer)
                .weight(600),
          ),
          const SizedBox(height: 3),
          Text(
            '${shortAge(link.createdAt)} ago, in $where',
            style: PerchType.bodySmall.copyWith(color: c.onWarnContainer),
          ),
          const SizedBox(height: Space.row),
          Row(
            spacing: Space.sm,
            children: <Widget>[
              AppButton(
                label: 'Open existing',
                compact: true,
                onPressed: onOpen,
              ),
              AppButton(
                label: 'Save anyway',
                type: AppButtonType.outlined,
                compact: true,
                onPressed: onSaveAnyway,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A row that opens a picker rather than editing in place — Folder and Tags,
/// so the flow is identical wherever you save from.
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.onTap,
    this.value,
    this.actionLabel,
    this.trailing,
  });

  final String label;
  final String? value;
  final String? actionLabel;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Semantics(
      button: true,
      label: value == null ? label : '$label, $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.outline),
          ),
          child: Row(
            spacing: Space.md,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: PerchType.titleMedium.copyWith(
                        fontSize: 14,
                        color: c.onSurface,
                      ),
                    ),
                    if (value != null) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        value!,
                        style: PerchType.bodySmall.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (actionLabel != null)
                _AccentPill(label: actionLabel!, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagsRow extends ConsumerWidget {
  const _TagsRow({required this.tagIds, required this.onChanged});

  final List<int> tagIds;
  final ValueChanged<List<int>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final List<TagWithCount> all =
        ref.watch(allTagsProvider).valueOrNull ?? const <TagWithCount>[];
    final List<TagWithCount> chosen = all
        .where((TagWithCount t) => tagIds.contains(t.tag.id))
        .toList(growable: false);

    Future<void> open() async {
      final List<int>? picked = await showTagPicker(context, selected: tagIds);
      if (picked != null) onChanged(picked);
    }

    return _PickerRow(
      label: 'Tags',
      onTap: open,
      actionLabel: chosen.isEmpty ? 'Add tags' : null,
      trailing: chosen.isEmpty
          ? null
          : Flexible(
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 5,
                runSpacing: 5,
                children: <Widget>[
                  for (final TagWithCount t in chosen)
                    TagChip(
                      label: t.tag.name,
                      compact: true,
                      selected: true,
                      color: c.tagColor(t.tag.color),
                      onRemove: () => onChanged(
                        tagIds
                            .where((int id) => id != t.tag.id)
                            .toList(growable: false),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
