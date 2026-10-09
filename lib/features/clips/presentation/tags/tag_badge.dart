import 'package:flutter/widgets.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_radius.dart';

/// The small tag glyph in a scrim pill at the top end corner of a tagged
/// clip's picture (`ClipThumbnailView`): says the clip has tags without
/// naming them. Decorative: the picture's owner carries the semantics.
class TagBadge extends StatelessWidget {
  const TagBadge({super.key, required this.size});

  static const Key pillKey = Key('tagBadge.pill');

  /// The glyph's size (`ClipThumbnailSlot.tagBadgeSize`).
  final double size;

  @override
  Widget build(BuildContext context) => PositionedDirectional(
    top: size / 2,
    end: size / 2,
    child: IgnorePointer(
      child: Container(
        key: pillKey,
        padding: EdgeInsets.all(size * .35),
        decoration: BoxDecoration(
          color: OsdMedia.scrim45,
          borderRadius: BorderRadius.circular(OsdRadius.full),
        ),
        child: OsdIcon(
          OsdIcons.sell,
          size: size,
          fill: 1,
          color: OsdMedia.onMedia,
        ),
      ),
    ),
  );
}
