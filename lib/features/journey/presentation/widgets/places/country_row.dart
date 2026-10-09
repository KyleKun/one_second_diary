import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/journey/presentation/places_formats.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/progress/mini_progress_bar.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A country as a list row: its initials in a tinted disc, its places and
/// clips, and its share of the most filmed country's clips.
class CountryRow extends StatelessWidget {
  const CountryRow({
    super.key,
    required this.country,
    required this.index,
    required this.share,
    required this.onTap,
  });

  final PlaceCountry country;

  /// Its rank, which picks the disc's tint.
  final int index;

  /// 0..1 of the top country's clips.
  final double share;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final PlacesFormats formats = PlacesFormats.of(context);
    final Color tint =
        OsdMedia.stampSwatches[(index * 3 + 1) % OsdMedia.stampSwatches.length];
    return OsdListRow(
      title: country.name,
      subtitle: Strings.placesJoin(
        a: formats.places(country.places.length),
        b: formats.clips(country.clipCount),
      ),
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: .2),
          shape: BoxShape.circle,
        ),
        child: Text(
          country.initials,
          style: context.typography.badge12.copyWith(color: colors.tx),
        ),
      ),
      trailing: OsdRowTrailing.custom(
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: <Widget>[
            SizedBox(width: 48, child: MiniProgressBar(value: share)),
            OsdIcon(OsdIcons.chevronRight, size: 22, color: colors.mu),
          ],
        ),
      ),
      onTap: onTap,
    );
  }
}
