import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../core/services/link_saver.dart';
import '../../core/services/metadata_fetcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/url.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_icon_button.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../../shared/widgets/folder_card.dart';
import '../../shared/widgets/link_thumbnail.dart';
import '../../shared/widgets/markdown_editor.dart';
import '../folders/folder_picker.dart';
import 'tag_field.dart';

/// Board 2d — full screen, not a sheet: the in-app add usually means typing,
/// and a keyboard over a sheet leaves no room for the preview and note together.
class AddLinkScreen extends ConsumerStatefulWidget {
  const AddLinkScreen({this.sharedUrl, super.key});

  final String? sharedUrl;

  @override
  ConsumerState<AddLinkScreen> createState() => _AddLinkScreenState();
}

class _AddLinkScreenState extends ConsumerState<AddLinkScreen> {
  final TextEditingController _url = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _note = TextEditingController();

  Timer? _debounce;
  String? _clipboardOffer;
  bool _fetching = false;
  bool _saving = false;
  MetadataResult? _result;
  FolderChoice _folder = (folderId: null, name: 'Unsorted');
  List<String> _tags = <String>[];
  Link? _duplicate;

  bool get _hasUrl => looksLikeUrl(_url.text);

  @override
  void initState() {
    super.initState();
    _url.text = widget.sharedUrl ?? '';
    _url.addListener(_onUrlChanged);
    if (_hasUrl) _scheduleFetch();
    unawaited(_offerClipboard());
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
    _scheduleFetch();
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

  Future<void> _checkDuplicate(String url) async {
    final Link? existing = await ref.read(linkRepositoryProvider).byUrl(url);
    if (mounted) setState(() => _duplicate = existing);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final int id = await ref
        .read(linkSaverProvider)
        .save(
          url: normalizeUrl(_url.text),
          title: _title.text.trim(),
          note: _note.text,
          folderId: _folder.folderId,
          tags: _tags,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                Space.md,
                Space.lg,
                14,
              ),
              child: Row(
                spacing: Space.row,
                children: <Widget>[
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => context.pop(),
                    semanticLabel: 'Cancel',
                    size: 40,
                  ),
                  Expanded(
                    child: Text(
                      'Add link',
                      style: PerchType.screenTitle.copyWith(color: c.onSurface),
                    ),
                  ),
                  AppButton(
                    label: 'Save',
                    compact: true,
                    loading: _saving,
                    onPressed: _hasUrl && !_saving ? _save : null,
                  ),
                ],
              ),
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
                  const _FieldLabel('Link'),
                  _UrlField(controller: _url),
                  if (_clipboardOffer != null && !_hasUrl) ...<Widget>[
                    const SizedBox(height: Space.row),
                    _ClipboardOffer(
                      url: _clipboardOffer!,
                      onUse: () {
                        _url.text = _clipboardOffer!;
                        setState(() => _clipboardOffer = null);
                      },
                      onDismiss: () => setState(() => _clipboardOffer = null),
                    ),
                  ],
                  if (_hasUrl) ...<Widget>[
                    const SizedBox(height: Space.row),
                    _PreviewBlock(
                      url: normalizeUrl(_url.text),
                      fetching: _fetching,
                      result: _result,
                      onRetry: _fetch,
                    ),
                  ],
                  if (_duplicate != null) ...<Widget>[
                    const SizedBox(height: Space.row),
                    _DuplicateHint(link: _duplicate!),
                  ],

                  // Folder, tags and note dim rather than hide, so the shape of
                  // the screen does not jump when a URL appears.
                  Opacity(
                    opacity: _hasUrl ? 1 : 0.4,
                    child: IgnorePointer(
                      ignoring: !_hasUrl,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const SizedBox(height: Space.xl),
                          const _FieldLabel('Title'),
                          _TitleField(
                            controller: _title,
                            suggested: suggested,
                            onUseSuggested: () =>
                                setState(() => _title.text = suggested!),
                          ),
                          const SizedBox(height: Space.xl),
                          const _FieldLabel('Folder'),
                          _FolderRow(
                            choice: _folder,
                            onChange: () async {
                              final FolderChoice? picked =
                                  await showFolderPicker(
                                    context,
                                    title: 'Save to',
                                  );
                              if (picked != null) {
                                setState(() => _folder = picked);
                              }
                            },
                          ),
                          const SizedBox(height: Space.xl),
                          const _FieldLabel('Tags'),
                          TagField(
                            tags: _tags,
                            onChanged: (List<String> t) =>
                                setState(() => _tags = t),
                          ),
                          const SizedBox(height: Space.xl),
                          const _FieldLabel('Note'),
                          MarkdownEditor(
                            controller: _note,
                            tools: kCompactTools,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!_hasUrl)
                    Padding(
                      padding: const EdgeInsets.only(top: Space.lg),
                      child: Text(
                        "Folder, tags and note unlock once there's a link.",
                        textAlign: TextAlign.center,
                        style: PerchType.bodySmall.copyWith(
                          color: c.onSurfaceMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: Text(
      text.toUpperCase(),
      style: PerchType.sectionHeader.copyWith(
        fontSize: 10.5,
        color: context.colors.onSurfaceVariant,
      ),
    ),
  );
}

class _UrlField extends StatelessWidget {
  const _UrlField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.outline),
      ),
      child: TextField(
        controller: controller,
        autofocus: controller.text.isEmpty,
        keyboardType: TextInputType.url,
        autocorrect: false,
        style: PerchType.body.copyWith(color: c.onSurface),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: 'Paste or type a URL',
          hintStyle: PerchType.body.copyWith(color: c.onSurfaceMuted),
        ),
      ),
    );
  }
}

class _ClipboardOffer extends StatelessWidget {
  const _ClipboardOffer({
    required this.url,
    required this.onUse,
    required this.onDismiss,
  });

  final String url;
  final VoidCallback onUse;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: c.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        spacing: Space.row,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Link on your clipboard',
                  style: PerchType.monoSmall.copyWith(color: c.accent),
                ),
                const SizedBox(height: 3),
                Text(
                  middleTruncate(url),
                  style: PerchType.label.copyWith(color: c.onPrimaryContainer),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AppButton(label: 'Use', compact: true, onPressed: onUse),
          AppIconButton(
            icon: Icons.close_rounded,
            onPressed: onDismiss,
            semanticLabel: 'Dismiss clipboard suggestion',
            size: 32,
            filled: false,
          ),
        ],
      ),
    );
  }
}

/// Skeleton → preview → no-preview. Same ladder as everywhere else; a page that
/// offers no image collapses to the monogram rather than showing an error.
class _PreviewBlock extends StatelessWidget {
  const _PreviewBlock({
    required this.url,
    required this.fetching,
    required this.result,
    required this.onRetry,
  });

  final String url;
  final bool fetching;
  final MetadataResult? result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final LinkMetadata? meta = result?.metadata;

    return Container(
      padding: const EdgeInsets.all(Space.row),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 11,
        children: <Widget>[
          SizedBox(
            width: 64,
            height: 64,
            child: fetching
                ? const ClipRRect(
                    borderRadius: Radii.thumbR,
                    child: ThumbnailSkeleton(),
                  )
                : LinkThumbnail(
                    url: url,
                    imageUrl: meta?.imageUrl,
                    faviconUrl: meta?.faviconUrl,
                    size: 64,
                  ),
          ),
          Expanded(
            child: fetching
                ? Text(
                    'FETCHING PREVIEW…',
                    style: PerchType.monoSmall.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        meta?.title ??
                            (result?.outcome == MetadataOutcome.failed
                                ? "That link couldn't be read"
                                : 'No preview found'),
                        style: PerchType.titleSmall.copyWith(
                          color: c.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        meta?.description ??
                            'Saves fine — the page offers no preview.',
                        style: PerchType.bodySmall.copyWith(
                          fontSize: 11.5,
                          height: 1.45,
                          color: c.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (result?.outcome != MetadataOutcome.ok) ...<Widget>[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: onRetry,
                          child: Text(
                            '⟳ TRY AGAIN',
                            style: PerchType.monoSmall.copyWith(
                              fontSize: 11,
                              color: c.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// An inline hint with Open. It never blocks the save.
class _DuplicateHint extends StatelessWidget {
  const _DuplicateHint({required this.link});

  final Link link;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: Radii.thumbR,
        border: Border.all(color: c.outline),
      ),
      child: Row(
        spacing: Space.row,
        children: <Widget>[
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: c.warning, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(
              'Already saved',
              style: PerchType.bodySmall.copyWith(color: c.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// The title the user will see, with the fetched one offered as a chip rather
/// than written in over the top of anything they typed.
class _TitleField extends StatelessWidget {
  const _TitleField({
    required this.controller,
    required this.suggested,
    required this.onUseSuggested,
  });

  final TextEditingController controller;
  final String? suggested;
  final VoidCallback onUseSuggested;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final bool offerable =
        suggested != null && suggested!.trim() != controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: c.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.outline),
          ),
          child: TextField(
            controller: controller,
            style: PerchType.titleMedium.copyWith(color: c.onSurface),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: suggested ?? 'Give it a title',
              hintStyle: PerchType.titleMedium.copyWith(
                color: c.onSurfaceMuted,
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        if (offerable)
          GestureDetector(
            onTap: onUseSuggested,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Text(
                '✓ Use suggested title',
                style: PerchType.labelStrong.copyWith(color: c.accent),
              ),
            ),
          )
        else
          Text(
            suggested == null
                ? 'No suggestion available — your title is the title.'
                : 'Using the page title.',
            style: PerchType.bodySmall.copyWith(color: c.onSurfaceMuted),
          ),
      ],
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.choice, required this.onChange});

  final FolderChoice choice;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.outline),
      ),
      child: Row(
        spacing: Space.md,
        children: <Widget>[
          FolderGlyph(
            color: choice.folderId == null ? c.onSurfaceMuted : c.primary,
            width: 20,
          ),
          Expanded(
            child: Text(
              choice.name,
              style: PerchType.titleMedium.copyWith(color: c.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppButton(
            label: 'Change',
            type: AppButtonType.muted,
            compact: true,
            onPressed: onChange,
          ),
        ],
      ),
    );
  }
}
