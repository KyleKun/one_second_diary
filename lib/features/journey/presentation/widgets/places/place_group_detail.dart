import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/journey/domain/places_snapshot.dart';
import 'package:one_second_diary/features/journey/presentation/places_formats.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/place_actions.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/place_poster.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/place_row.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/places_sheet_title.dart';
import 'package:one_second_diary/shared/widgets/buttons/circle_icon_button.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A group of places in the sheet (a country, a stack of nearby places):
/// Play all and Make movie over all of them, their poster cards and rows.
class PlaceGroupDetail extends StatelessWidget {
  const PlaceGroupDetail({
    super.key,
    required this.title,
    required this.places,
    required this.onClose,
    required this.onPlace,
    required this.onPlayAll,
    required this.onMakeMovie,
  });

  final String title;
  final List<DiaryPlace> places;
  final VoidCallback onClose;
  final ValueChanged<DiaryPlace> onPlace;
  final VoidCallback onPlayAll;
  final VoidCallback? onMakeMovie;

  @override
  Widget build(BuildContext context) {
    final PlacesFormats formats = PlacesFormats.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: <Widget>[
        PlacesSheetTitle(
          title: title,
          subtitle: Strings.placesJoin(
            a: formats.places(places.length),
            b: formats.clips(PlacesSnapshot.clipCountOf(places)),
          ),
          trailing: CircleIconButton(
            icon: OsdIcons.close,
            tooltip: CommonLabels.of(context).close,
            onPressed: onClose,
          ),
        ),
        PlaceActions(onPlayAll: onPlayAll, onMakeMovie: onMakeMovie),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: places.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int i) => _PlaceCard(
              place: places[i],
              clips: formats.clips(places[i].clips.length),
              onTap: () => onPlace(places[i]),
            ),
          ),
        ),
        OsdCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (int i = 0; i < places.length; i++) ...<Widget>[
                if (i > 0) const OsdDivider(indent: 72),
                PlaceRow(place: places[i], onTap: () => onPlace(places[i])),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A place as a poster card: its newest clip, name and count.
class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.clips,
    required this.onTap,
  });

  final DiaryPlace place;
  final String clips;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final OsdTypography typography = context.typography;
    final BorderRadius radius = BorderRadius.circular(OsdRadius.r16);
    return OsdPressable(
      onTap: onTap,
      borderRadius: radius,
      semanticsLabel: Strings.placesMarkerSemantics(
        name: place.name,
        clips: clips,
      ),
      child: SizedBox(
        width: 104,
        child: ClipRRect(
          borderRadius: radius,
          child: PlacePoster(
            clip: place.newest,
            overlay: DecoratedBox(
              decoration: const BoxDecoration(gradient: OsdMedia.clipScrim),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typography.label14Strong.copyWith(
                        color: OsdMedia.onMedia,
                      ),
                    ),
                    Text(
                      clips,
                      style: typography.caption.copyWith(
                        color: OsdMedia.onMedia.withValues(alpha: .8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
