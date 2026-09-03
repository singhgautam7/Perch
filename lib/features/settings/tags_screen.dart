import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/tag_repository.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/oklch.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../add_link/tag_field.dart';
import 'settings_widgets.dart';

/// Board 1h — tag actions expand inside the row instead of opening a menu, so
/// the tag being edited stays visible with its count.
class TagsScreen extends ConsumerStatefulWidget {
  const TagsScreen({super.key});

  @override
  ConsumerState<TagsScreen> createState() => _TagsScreenState();
}

class _TagsScreenState extends ConsumerState<TagsScreen> {
  final TextEditingController _query = TextEditingController();
  int? _expanded;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PerchColors c = context.colors;
    final List<TagWithCount> all =
        ref.watch(allTagsProvider).valueOrNull ?? const <TagWithCount>[];
    final String q = _query.text.trim().toLowerCase();
    final List<TagWithCount> tags = q.isEmpty
        ? all
        : all
              .where((TagWithCount t) => t.tag.name.toLowerCase().contains(q))
              .toList(growable: false);

    return SettingsScaffold(
      title: 'Tags',
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: c.surfaceContainerHigh,
            borderRadius: Radii.fullR,
          ),
          child: Row(
            spacing: Space.row,
            children: <Widget>[
              Icon(Icons.search_rounded, size: 18, color: c.iconMuted),
              Expanded(
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  style: PerchType.body.copyWith(color: c.onSurface),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Find a tag',
                    hintStyle: PerchType.body.copyWith(color: c.onSurfaceMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        if (tags.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.xxl),
            child: Text(
              all.isEmpty ? 'No tags yet.' : 'No tag matches that.',
              textAlign: TextAlign.center,
              style: PerchType.body.copyWith(color: c.onSurfaceMuted),
            ),
          ),
        for (final TagWithCount t in tags) ...<Widget>[
          _TagRow(
            data: t,
            expanded: _expanded == t.tag.id,
            onToggle: () => setState(
              () => _expanded = _expanded == t.tag.id ? null : t.tag.id,
            ),
            allTags: all,
          ),
          const SizedBox(height: Space.sm),
        ],
      ],
    );
  }
}

class _TagRow extends ConsumerWidget {
  const _TagRow({
    required this.data,
    required this.expanded,
    required this.onToggle,
    required this.allTags,
  });

  final TagWithCount data;
  final bool expanded;
  final VoidCallback onToggle;
  final List<TagWithCount> allTags;

  /// Tag colors are drawn from the active theme's hues only, which keeps a long
  /// tag list from turning into confetti.
  static const List<double> _hueOffsets = <double>[0, 40, 80, 200, 300];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PerchColors c = context.colors;
    final TagRepository repo = ref.read(tagRepositoryProvider);

    return AnimatedSize(
      duration: Motion.of(context, Motion.folderOpen),
      curve: Motion.curveOf(context, Motion.decelerate),
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: expanded ? c.primary : c.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  spacing: Space.md,
                  children: <Widget>[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: data.tag.color == null
                            ? c.primary
                            : Color(data.tag.color!),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        data.tag.name,
                        style: PerchType.titleMedium.copyWith(
                          color: c.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      plural(data.linkCount, 'link'),
                      style: PerchType.monoLabel.copyWith(
                        color: c.onSurfaceVariant,
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 20,
                      color: c.onSurfaceMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.sm,
                      children: <Widget>[
                        AppButton(
                          label: 'Rename',
                          type: AppButtonType.secondary,
                          compact: true,
                          onPressed: () => _rename(context, repo),
                        ),
                        AppButton(
                          label: 'Merge into…',
                          type: AppButtonType.secondary,
                          compact: true,
                          onPressed: () => _merge(context, ref),
                        ),
                        AppButton(
                          label: 'Delete',
                          type: AppButtonType.danger,
                          compact: true,
                          onPressed: () => _delete(context, repo),
                        ),
                      ],
                    ),
                    const SizedBox(height: Space.md),
                    Row(
                      spacing: Space.sm,
                      children: <Widget>[
                        Text(
                          'COLOR',
                          style: PerchType.monoSmall.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                        for (final double offset in _hueOffsets)
                          _Swatch(
                            color: Oklch(
                              0.58,
                              0.12,
                              _familyHue(ref) + offset,
                            ).toColor(),
                            onTap: (Color picked) =>
                                repo.setColor(data.tag.id, picked.toARGB32()),
                          ),
                        _Swatch(
                          color: c.onSurfaceMuted,
                          onTap: (_) => repo.setColor(data.tag.id, null),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _familyHue(WidgetRef ref) =>
      ref.read(settingsProvider).family.primaryHue;

  Future<void> _rename(BuildContext context, TagRepository repo) async {
    final String? name = await _prompt(context, 'Rename tag', data.tag.name);
    if (name == null || name.isEmpty) return;
    await repo.rename(data.tag.id, name);
  }

  /// Merge moves every link onto the target tag, then removes this one.
  Future<void> _merge(BuildContext context, WidgetRef ref) async {
    final String? target = await showTagPicker(
      context,
      exclude: <String>[data.tag.name],
    );
    if (target == null || !context.mounted) return;

    final TagRepository repo = ref.read(tagRepositoryProvider);
    final PerchDatabase db = ref.read(databaseProvider);
    final int targetId = await repo.ensure(target);
    await db.customStatement(
      'INSERT OR IGNORE INTO link_tags (link_id, tag_id) '
      'SELECT link_id, ? FROM link_tags WHERE tag_id = ?',
      <Object>[targetId, data.tag.id],
    );
    await repo.delete(data.tag.id);
    if (context.mounted) {
      AppSnackbar.success(context, 'Merged into $target');
    }
  }

  Future<void> _delete(BuildContext context, TagRepository repo) async {
    await repo.delete(data.tag.id);
    if (context.mounted) {
      AppSnackbar.info(context, 'Deleted ${data.tag.name}');
    }
  }

  Future<String?> _prompt(
    BuildContext context,
    String title,
    String initial,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: initial,
    );
    final String? result = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: dialogContext.colors.surfaceContainer,
        title: Text(title, style: PerchType.titleMedium),
        content: TextField(controller: controller, autofocus: true),
        actions: <Widget>[
          AppButton(
            label: 'Cancel',
            type: AppButtonType.outlined,
            compact: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          AppButton(
            label: 'Save',
            compact: true,
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.onTap});

  final Color color;
  final ValueChanged<Color> onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Tag colour',
    child: GestureDetector(
      onTap: () => onTap(color),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    ),
  );
}
