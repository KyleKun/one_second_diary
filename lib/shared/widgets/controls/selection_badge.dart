import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pop_switcher.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';

/// How a selected media tile is marked: clips in coral, movies in ink.
enum SelectionBadgeStyle {
  /// CO with a white check.
  coral,

  /// TX with a BG check and no shadow.
  ink,
}

/// The selection mark at the top-end of a selectable media tile, placed by
/// the tile. Unselected, it is an empty white ring.
///
/// Decorative: the tile is the semantics node.
class SelectionBadge extends StatelessWidget {
  const SelectionBadge({
    super.key,
    required this.selected,
    this.style = SelectionBadgeStyle.coral,
  });

  /// The badge circle (in each state).
  static const Key badgeKey = Key('selectionBadge.badge');

  static const double _size = 26;

  final bool selected;

  final SelectionBadgeStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = style == SelectionBadgeStyle.ink;
    final badge = selected
        ? DecoratedBox(
            key: badgeKey,
            decoration: BoxDecoration(
              color: ink ? colors.tx : colors.co,
              shape: BoxShape.circle,
              boxShadow: ink ? null : const <BoxShadow>[OsdMedia.badgeShadow],
            ),
            child: SizedBox.square(
              dimension: _size,
              child: Center(
                child: OsdIcon(
                  OsdIcons.check,
                  size: 18,
                  color: ink ? colors.bg : OsdMedia.onMedia,
                ),
              ),
            ),
          )
        : const DecoratedBox(
            key: badgeKey,
            decoration: BoxDecoration(
              color: OsdMedia.emptyBadgeFill,
              shape: BoxShape.circle,
              border: Border.fromBorderSide(
                BorderSide(color: OsdMedia.onMedia, width: 2),
              ),
              boxShadow: <BoxShadow>[OsdMedia.badgeShadow],
            ),
            child: SizedBox.square(dimension: _size),
          );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: _size,
        child: OsdPopSwitcher(
          child: KeyedSubtree(
            key: ValueKey<(bool, SelectionBadgeStyle)>((selected, style)),
            child: badge,
          ),
        ),
      ),
    );
  }
}
