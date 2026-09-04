import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/services/import_export.dart';
import '../../core/services/import_sources.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../stats/stats_providers.dart';
import 'refresh_previews.dart';
import 'settings_widgets.dart';

/// Board 3g — Data is where you act on your library. Privacy answers "what
/// does this app do with my data"; this page answers "how do I move it".
class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  bool _busy = false;

  static const String _lastExportKey = 'data.lastExport';

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final ImportExportService service = ref.read(importExportProvider);
      final String json = await service.exportJson();
      final int count = (await service.buildArchive()).linkCount;

      final Directory dir = await getTemporaryDirectory();
      final String stamp = DateTime.now().toIso8601String().split('T').first;
      final File file = File('${dir.path}/perch-$stamp.json');
      await file.writeAsString(json);

      await ref
          .read(settingsRepositoryProvider)
          .put(_lastExportKey, '${DateTime.now().toIso8601String()}|$count');

      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path)],
          fileNameOverrides: <String>['perch-$stamp.json'],
        ),
      );
    } on Object catch (e) {
      if (mounted) AppSnackbar.error(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Perch asks for no storage permission, so a file is handed over the same
  /// way any other text is: pasted in.
  Future<String?> _askForFile(ImportSource source, String warning) async {
    final ClipboardData? clip = await Clipboard.getData(Clipboard.kTextPlain);
    final String initial =
        (clip?.text?.length ?? 0) > 40 ? clip!.text! : '';
    if (!mounted) return null;

    return showAppBottomSheet<String>(
      context: context,
      title: 'Import ${source.label}',
      description: warning,
      builder: (BuildContext sheetContext) => _ImportFileSheet(
        source: source,
        initialText: initial,
      ),
    );
  }

  Future<void> _importPerch() async {
    final String? raw = await _askForFile(
      ImportSource.perch,
      'This replaces everything currently in Perch.',
    );
    if (raw == null || raw.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final int count = await ref.read(importExportProvider).importJson(raw);
      if (mounted) {
        AppSnackbar.success(context, 'Imported ${plural(count, 'link')}');
      }
    } on Object catch (e) {
      if (mounted) AppSnackbar.error(context, 'That file could not be read: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importSource(ImportSource source) async {
    final String? raw = await _askForFile(
      source,
      'Links are added to what you already have. Anything already saved is '
      'skipped.',
    );
    if (raw == null || raw.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final List<ImportedLink> parsed = await parseImport(source, raw);
      if (parsed.isEmpty) {
        if (mounted) {
          AppSnackbar.warning(context, 'No links found in that file');
        }
        return;
      }
      final (int imported, int skipped) = await ref
          .read(importExportProvider)
          .importLinks(parsed);
      if (mounted) {
        AppSnackbar.success(
          context,
          'Imported ${plural(imported, 'link')}'
          '${skipped == 0 ? '' : ' · $skipped already saved'}',
        );
      }
    } on Object catch (e) {
      if (mounted) AppSnackbar.error(context, 'That file could not be read: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final PerchStats? stats = ref.watch(statsProvider).valueOrNull;
    final RefreshProgress refresh = ref.watch(refreshPreviewsProvider);

    return SettingsScaffold(
      title: 'Data',
      children: <Widget>[
        _DataRow(
          label: 'Export backup',
          value: stats == null
              ? 'Everything, as one JSON file'
              : '${plural(stats.links, 'link')}, ${plural(stats.tags, 'tag')}, '
                    '${plural(stats.folders, 'folder')} → JSON',
          trailing: AppButton(
            label: 'Export',
            compact: true,
            loading: _busy,
            onPressed: _busy ? null : _export,
          ),
        ),
        const SizedBox(height: Space.sm),
        _DataRow(
          label: 'Import backup',
          value: ImportSource.perch.blurb,
          onTap: _busy ? null : _importPerch,
        ),
        const SizedBox(height: Space.lg),
        const _GroupLabel('Import from'),
        for (final ImportSource source in <ImportSource>[
          ImportSource.bookmarks,
          ImportSource.pocket,
          ImportSource.raindrop,
        ]) ...<Widget>[
          _DataRow(
            label: source.label,
            value: source.blurb,
            onTap: _busy ? null : () => _importSource(source),
          ),
          const SizedBox(height: Space.sm),
        ],
        const SizedBox(height: Space.sm),
        if (refresh.running)
          const RefreshProgressCard()
        else
          _DataRow(
            label: 'Refresh previews',
            value: refresh.missing == 0
                ? 'Every link has a preview image'
                : '${plural(refresh.missing, 'link')} missing a preview image',
            trailing: AppButton(
              label: 'Refresh',
              type: AppButtonType.secondary,
              compact: true,
              onPressed: refresh.missing == 0
                  ? null
                  : () => ref.read(refreshPreviewsProvider.notifier).start(),
            ),
          ),
        const SizedBox(height: Space.lg),
        const _LastExportLine(settingKey: _lastExportKey),
        const SizedBox(height: Space.sm),
        Text(
          'An export is one file: links, notes, tags, folders and pin and '
          'opened state. Nothing here is gated.',
          style: PerchType.bodySmall.copyWith(
            height: 1.55,
            color: c.onSurfaceMuted,
          ),
        ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
    child: Text(
      text.toUpperCase(),
      style: PerchType.sectionHeader.copyWith(
        fontSize: 10,
        letterSpacing: 0.9,
        color: context.colors.onSurfaceVariant,
      ),
    ),
  );
}

class _LastExportLine extends ConsumerWidget {
  const _LastExportLine({required this.settingKey});

  final String settingKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    return FutureBuilder<Map<String, String>>(
      future: ref.watch(settingsRepositoryProvider).all(),
      builder:
          (BuildContext context, AsyncSnapshot<Map<String, String>> snapshot) {
            final String? raw = snapshot.data?[settingKey];
            if (raw == null) {
              return Text(
                'NO EXPORT YET',
                style: PerchType.monoSmall.copyWith(color: c.onSurfaceMuted),
              );
            }
            final List<String> parts = raw.split('|');
            final DateTime? at = DateTime.tryParse(parts.first);
            return Text(
              'LAST EXPORT · ${at == null ? '—' : longDate(at).toUpperCase()}'
              '${parts.length > 1 ? ' · ${parts[1]} LINKS' : ''}',
              style: PerchType.monoSmall.copyWith(color: c.onSurfaceMuted),
            );
          },
    );
  }
}

/// Board 3g's Data row: a title, a line of detail, and either an action or a
/// chevron. Only this page uses it — More keeps board 2e's grouped rows.
class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final Widget row = Container(
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
                const SizedBox(height: 3),
                Text(
                  value,
                  style: PerchType.bodySmall.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: c.onSurfaceMuted,
            ),
        ],
      ),
    );

    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '$label, $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: row,
      ),
    );
  }
}

class _ImportFileSheet extends StatefulWidget {
  const _ImportFileSheet({required this.source, required this.initialText});

  final ImportSource source;
  final String initialText;

  @override
  State<_ImportFileSheet> createState() => _ImportFileSheetState();
}

class _ImportFileSheetState extends State<_ImportFileSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _controller,
          maxLines: 6,
          style: PerchType.monoSmall,
          decoration: InputDecoration(
            hintText: 'Paste the contents of your ${widget.source.label} export',
          ),
        ),
        const SizedBox(height: Space.lg),
        AppButton(
          label: 'Import',
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(_controller.text),
        ),
      ],
    );
  }
}
