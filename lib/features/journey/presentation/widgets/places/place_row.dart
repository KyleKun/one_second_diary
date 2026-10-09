import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/journey/presentation/places_formats.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/place_poster.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_radius.dart';

/// A place as a list row: its newest poster, name, country, Home and clip
/// count, and the month it was first filmed.
class PlaceRow extends StatelessWidget {
  const PlaceRow({super.key, required this.place, required this.onTap});

  final DiaryPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PlacesFormats formats = PlacesFormats.of(context);
    final String clips = formats.clips(place.clips.length);
    final String facts = place.home
        ? Strings.placesJoin(a: Strings.placesHome, b: clips)
        : clips;
    final String? country = place.country;
    return OsdListRow(
      title: place.name,
      subtitle: country == null
          ? facts
          : Strings.placesJoin(a: country, b: facts),
      value: place.home ? null : formats.month(place.first),
      leading: SizedBox(
        width: 40,
        height: 48,
        child: PlacePoster(clip: place.newest, radius: OsdRadius.r8),
      ),
      trailing: const OsdRowTrailing.chevron(),
      onTap: onTap,
    );
  }
}
