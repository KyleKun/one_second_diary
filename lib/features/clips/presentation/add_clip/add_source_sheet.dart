import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_clip_source.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The add-source sheet: an `OsdSheet` titled "Add another second" with a
/// row per source.
///
/// Open it with [show]; `AddClipFlow.choose` does, then goes on with the
/// source picked.
class AddSourceSheet extends StatelessWidget {
  const AddSourceSheet({super.key, required this.sources});

  static const Key bodyKey = Key('addSourceSheet.body');

  static Key rowKey(AddClipSource source) =>
      ValueKey<String>('addSourceSheet.${source.name}');

  static const double _rowHeight = 56;
  static const double _circle = 40;

  /// The rows, in this order.
  final List<AddClipSource> sources;

  /// Opens the sheet (titled [title], "Add another second" by default) with
  /// [sources]; completes with the source tapped, or null when closed.
  static Future<AddClipSource?> show(
    BuildContext context, {
    String? title,
    List<AddClipSource> sources = AddClipSource.values,
  }) => showOsdSheet<AddClipSource>(
    context,
    title: title ?? Strings.todayAddAnotherTitle,
    child: AddSourceSheet(sources: sources),
  );

  @override
  Widget build(BuildContext context) => Column(
    key: bodyKey,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    spacing: 8,
    children: <Widget>[
      for (final AddClipSource source in sources)
        _SourceRow(
          key: rowKey(source),
          source: source,
          onTap: () => Navigator.of(context).pop(source),
        ),
    ],
  );
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({super.key, required this.source, required this.onTap});

  final AddClipSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final BorderRadius radius = BorderRadius.circular(OsdRadius.r18);
    final (
      String label,
      IconData icon,
      Color fill,
      Color ink,
      double iconFill,
    ) = switch (source) {
      AddClipSource.record => (
        Strings.record,
        OsdIcons.videocam,
        colors.coFill,
        colors.onCo,
        1.0,
      ),
      AddClipSource.video => (
        Strings.addVideo,
        OsdIcons.videoLibrary,
        colors.off,
        colors.d2,
        0.0,
      ),
      AddClipSource.photo => (
        Strings.addPhotoAsVideo,
        OsdIcons.image,
        colors.off,
        colors.d2,
        0.0,
      ),
    };
    return OsdPressable(
      onTap: onTap,
      haptic: OsdHaptic.selection,
      pressScale: OsdPressScale.row.scale,
      borderRadius: radius,
      semanticsLabel: label,
      excludeChildSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: AddSourceSheet._rowHeight),
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 14, 8),
        decoration: BoxDecoration(color: colors.c2, borderRadius: radius),
        child: Row(
          spacing: 14,
          children: <Widget>[
            Container(
              width: AddSourceSheet._circle,
              height: AddSourceSheet._circle,
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: OsdIcon(icon, size: 22, fill: iconFill, color: ink),
            ),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.typography.buttonNeutral.copyWith(
                  color: colors.tx,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
