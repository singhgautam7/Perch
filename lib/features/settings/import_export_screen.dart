import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/services/import_export.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_bottom_sheet.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_snackbar.dart';
import 'settings_widgets.dart';

class ImportExportScreen extends StatelessWidget {
  const ImportExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return SettingsScaffold(
      title: 'Import / Export',
      children: <Widget>[
        Text(
          'Your library is a single file. Export writes it out, import reads it '
          'back — losslessly, in a format you can open in any text editor.',
          style: PerchType.body.copyWith(color: c.onSurfaceVariant),
        ),
        const SizedBox(height: Space.xl),
        const BackupCard(),
      ],
    );
  }
}

/// Export and import, shown both here and on the Privacy screen — "where does
/// my data live" and "how do I take it with me" are the same question.
class BackupCard extends ConsumerStatefulWidget {
  const BackupCard({super.key});

  @override
  ConsumerState<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends ConsumerState<BackupCard> {
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
      if (mounted) setState(() {});
    } on Object catch (e) {
      if (mounted) AppSnackbar.error(context, 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Import reads pasted JSON. Perch asks for no storage permission, so the
  /// file is handed over the same way any other text is.
  Future<void> _import() async {
    final TextEditingController controller = TextEditingController();
    final ClipboardData? clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null && clip!.text!.trimLeft().startsWith('{')) {
      controller.text = clip.text!;
    }
    if (!mounted) return;

    final bool? go = await showAppBottomSheet<bool>(
      context: context,
      title: 'Import',
      builder: (BuildContext sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'This replaces everything currently in Perch. Paste the contents of '
            'a Perch export below.',
            style: PerchType.bodySmall.copyWith(
              color: sheetContext.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.lg),
          TextField(
            controller: controller,
            maxLines: 6,
            style: PerchType.monoSmall,
            decoration: const InputDecoration(hintText: '{ "perch": 1, … }'),
          ),
          const SizedBox(height: Space.lg),
          AppButton(
            label: 'Replace my library',
            type: AppButtonType.danger,
            fullWidth: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
        ],
      ),
    );

    if (go != true) {
      controller.dispose();
      return;
    }
    setState(() => _busy = true);
    try {
      final int count = await ref
          .read(importExportProvider)
          .importJson(controller.text);
      if (mounted) {
        AppSnackbar.success(context, 'Imported ${plural(count, 'link')}');
      }
    } on Object catch (e) {
      if (mounted) AppSnackbar.error(context, 'That file could not be read: $e');
    } finally {
      controller.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Your backup'.toUpperCase(),
            style: PerchType.sectionHeader.copyWith(
              fontSize: 10.5,
              color: c.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.row),
          Text(
            'Export writes a single file — links, folders, tags and notes — '
            'that you can read in any text editor and import back at any time.',
            style: PerchType.bodySmall.copyWith(
              height: 1.55,
              color: c.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Space.lg),
          Row(
            spacing: Space.sm,
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: 'Export',
                  loading: _busy,
                  fullWidth: true,
                  onPressed: _busy ? null : _export,
                ),
              ),
              Expanded(
                child: AppButton(
                  label: 'Import',
                  type: AppButtonType.outlined,
                  fullWidth: true,
                  onPressed: _busy ? null : _import,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          const _LastExportLine(settingKey: _lastExportKey),
        ],
      ),
    );
  }
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
