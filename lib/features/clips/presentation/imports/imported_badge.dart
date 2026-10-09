import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The small "Imported" pill on a clip the app did not make
/// (`ClipIndex.isForeign`). With [onTap] it opens the clip in the editor;
/// without, it is decorative.
class ImportedBadge extends StatelessWidget {
  const ImportedBadge({super.key, this.onTap, this.size = 14});

  static const Key pillKey = Key('importedBadge.pill');

  final VoidCallback? onTap;

  /// The glyph's size; the pill scales with it.
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget pill = DecoratedBox(
      key: pillKey,
      decoration: BoxDecoration(
        color: OsdMedia.scrim55,
        borderRadius: BorderRadius.circular(OsdRadius.full),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          size * .5,
          size * .35,
          size * .7,
          size * .35,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: size * .35,
          children: <Widget>[
            OsdIcon(
              OsdIcons.videoLibrary,
              size: size,
              fill: 1,
              color: OsdMedia.onMedia,
            ),
            Text(
              Strings.clipImported,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textScaler: OsdTextScale.scalerFor(
                context,
                OsdTextScaleRole.mediaChrome,
              ),
              style: context.typography.label13.copyWith(
                color: OsdMedia.onMedia,
              ),
            ),
          ],
        ),
      ),
    );
    final VoidCallback? tap = onTap;
    if (tap == null) return ExcludeSemantics(child: pill);
    return Semantics(
      button: true,
      label: Strings.clipImported,
      hint: Strings.processImport,
      child: OsdPressable(onTap: tap, child: pill),
    );
  }
}
