import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/journey/domain/places_snapshot.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/places_map_cubit.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/places_map_state.dart';
import 'package:one_second_diary/features/journey/presentation/places_formats.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/country_row.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/place_row.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/places_empty.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/places_not_on_map_callout.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/places_section_title.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/places_sheet_title.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/places_stat_card.dart';
import 'package:one_second_diary/shared/widgets/buttons/tinted_pill_button.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_segmented_tabs.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The sheet's overview: the year, the stats, the top countries and places
/// of [places] (the year's), or the empty state when the diary has none.
class PlacesOverview extends StatelessWidget {
  const PlacesOverview({
    super.key,
    required this.snapshot,
    required this.places,
    required this.year,
    required this.thisYear,
    required this.locating,
    required this.lookupOutcome,
    required this.lookupMissing,
    required this.onLookUp,
    required this.onPinPlace,
    required this.onYear,
    required this.onPickYear,
    required this.onReplay,
    required this.onPlace,
    required this.onCountry,
    required this.onAllCountries,
    required this.onAllPlaces,
    required this.onRecord,
  });

  /// Rows each list shows before "All countries" / "All places".
  static const int _top = 5;

  final PlacesSnapshot snapshot;
  final List<DiaryPlace> places;
  final int? year;

  /// The calendar year today, the second tab.
  final int thisYear;
  final bool locating;
  final PlaceLookupOutcome? lookupOutcome;
  final int lookupMissing;

  /// The name lookup over the unmapped "City, Country" names.
  final VoidCallback onLookUp;

  /// An unmapped place tapped: the pin sheet.
  final ValueChanged<DiaryPlace> onPinPlace;
  final ValueChanged<int?> onYear;

  /// "Select year": opens the year sheet.
  final VoidCallback onPickYear;
  final VoidCallback onReplay;
  final ValueChanged<DiaryPlace> onPlace;
  final ValueChanged<PlaceCountry> onCountry;
  final VoidCallback onAllCountries;
  final VoidCallback onAllPlaces;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    if (snapshot.isEmpty || places.isEmpty) {
      return PlacesEmpty(onRecord: onRecord);
    }
    final OsdColors colors = context.colors;
    final PlacesFormats formats = PlacesFormats.of(context);
    final List<PlaceCountry> countries = PlacesSnapshot.countriesOf(places);
    final int clips = PlacesSnapshot.clipCountOf(places);
    final DiaryPlace? farthest = snapshot.farthest(places);
    final double? farthestKm = farthest == null
        ? null
        : snapshot.kmFromHome(farthest);
    final int mostClips = countries.isEmpty ? 1 : countries.first.clipCount;
    final List<int> years = snapshot.years;
    final bool hasThisYear = years.contains(thisYear);
    final int? shownYear = year;
    final bool onThisYear = hasThisYear && shownYear == thisYear;
    final int newYear = year ?? years.first;
    final List<DiaryPlace> fresh = snapshot.newIn(newYear);
    final List<DiaryPlace> unmapped = snapshot.unmapped;
    final bool canReplay =
        (snapshot.home?.isMapped ?? false) &&
        countries.length > 1 &&
        places.length > 2 &&
        snapshot.route(places).length >= 2;
    final DiaryPlace top = places.first;
    final String yearText = formats.year(newYear);
    final double withPlace = snapshot.diaryClipCount == 0
        ? 0
        : clips / snapshot.diaryClipCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: <Widget>[
        PlacesSheetTitle(
          title: switch ((year, countries.length)) {
            (final int y, _) => Strings.placesYourYear(year: formats.year(y)),
            (null, 1) => Strings.placesYourCountry(
              country: countries.single.name,
            ),
            _ => Strings.placesYourWorld,
          },
          subtitle: Strings.placesClipsInPlaces(
            clips: formats.clips(clips),
            places: formats.places(places.length),
          ),
          trailing: canReplay
              ? TintedPillButton(
                  label: Strings.placesReplay,
                  icon: OsdIcons.playArrow,
                  onPressed: onReplay,
                )
              : null,
        ),
        if (unmapped.isNotEmpty)
          PlacesNotOnMapCallout(
            places: unmapped,
            lookUpCount: unmapped.where(PlacesMapCubit.canLookUp).length,
            locating: locating,
            outcome: lookupOutcome,
            missing: lookupMissing,
            onPlace: onPinPlace,
            onLookUp: onLookUp,
          ),
        if (years.length > 1)
          OsdSegmentedTabs(
            segments: <OsdSegment>[
              OsdSegment(
                icon: OsdIcons.language,
                accent: colors.green,
                label: Strings.placesAllTime,
              ),
              if (hasThisYear)
                OsdSegment(
                  icon: OsdIcons.event,
                  accent: colors.co,
                  label: formats.year(thisYear),
                ),
              OsdSegment(
                icon: OsdIcons.history,
                accent: colors.purple,
                label: shownYear == null || onThisYear
                    ? Strings.placesSelectYear
                    : formats.year(shownYear),
              ),
            ],
            index: shownYear == null
                ? 0
                : onThisYear
                ? 1
                : hasThisYear
                ? 2
                : 1,
            onChanged: (int i) {
              if (i == 0) {
                onYear(null);
              } else if (i == 1 && hasThisYear) {
                onYear(thisYear);
              } else {
                onPickYear();
              }
            },
          ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: <Widget>[
              Expanded(
                child: PlacesStatCard(
                  icon: OsdIcons.place,
                  accent: colors.green,
                  label: Strings.places,
                  value: formats.number(places.length),
                  emphasis: formats.number(places.length),
                  sub: switch (countries.length) {
                    0 => formats.places(places.length),
                    1 => Strings.placesAllIn(country: countries.single.name),
                    _ => Strings.placesInCountries(
                      countries: formats.countries(countries.length),
                    ),
                  },
                ),
              ),
              Expanded(
                child: PlacesStatCard(
                  icon: OsdIcons.favorite,
                  accent: colors.co,
                  label: Strings.placesMostFilmed,
                  value: top.name,
                  emphasis: top.name,
                  sub: top.home
                      ? Strings.placesJoin(
                          a: Strings.placesHome,
                          b: formats.clips(top.clips.length),
                        )
                      : formats.clips(top.clips.length),
                  onTap: () => onPlace(top),
                ),
              ),
            ],
          ),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: <Widget>[
              Expanded(
                child: PlacesStatCard(
                  icon: OsdIcons.event,
                  accent: colors.purple,
                  label: Strings.placesNewIn(year: yearText),
                  value: formats.number(fresh.length),
                  emphasis: formats.number(fresh.length),
                  sub: fresh.isEmpty
                      ? Strings.placesNoNewPlaces
                      : fresh
                            .take(3)
                            .map((DiaryPlace p) => p.name)
                            .reduce(
                              (String a, String b) =>
                                  Strings.placesNamesJoin(a: a, b: b),
                            ),
                ),
              ),
              Expanded(
                child: year == null
                    ? PlacesStatCard(
                        icon: OsdIcons.checkCircle,
                        accent: colors.green,
                        label: Strings.placesWithPlace,
                        value: formats.percent(withPlace),
                        emphasis: formats.percent(withPlace),
                        sub: Strings.placesClipsOfTotal(
                          clips: formats.number(clips),
                          total: formats.number(snapshot.diaryClipCount),
                        ),
                      )
                    : PlacesStatCard(
                        icon: OsdIcons.videoLibrary,
                        accent: colors.green,
                        label: Strings.placesClips,
                        value: formats.number(clips),
                        emphasis: formats.number(clips),
                        sub: Strings.placesWithPlaceIn(year: yearText),
                      ),
              ),
            ],
          ),
        ),
        if (farthest != null && farthestKm != null)
          PlacesStatCard(
            icon: OsdIcons.myLocation,
            accent: colors.yellow,
            label: Strings.placesFarthest,
            value: formats.km(farthestKm),
            emphasis: formats.number(farthestKm.round()),
            sub: Strings.placesJoin(
              a: switch (farthest.country) {
                final String c => Strings.placesNameCountry(
                  name: farthest.name,
                  country: c,
                ),
                null => farthest.name,
              },
              b: formats.month(farthest.first),
            ),
            onTap: () => onPlace(farthest),
          ),
        if (countries.length > 1) ...<Widget>[
          PlacesSectionTitle(Strings.placesTopCountries),
          OsdCard(
            margin: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (
                  int i = 0;
                  i < math.min(_top, countries.length);
                  i++
                ) ...<Widget>[
                  if (i > 0) const OsdDivider(indent: 64),
                  CountryRow(
                    country: countries[i],
                    index: i,
                    share: countries[i].clipCount / mostClips,
                    onTap: () => onCountry(countries[i]),
                  ),
                ],
                if (countries.length > _top) ...<Widget>[
                  const OsdDivider(),
                  _SeeAllRow(
                    label: Strings.placesAllCountries,
                    count: formats.number(countries.length),
                    onTap: onAllCountries,
                  ),
                ],
              ],
            ),
          ),
        ],
        PlacesSectionTitle(Strings.placesTopPlaces),
        OsdCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: <Widget>[
              for (
                int i = 0;
                i < math.min(_top, places.length);
                i++
              ) ...<Widget>[
                if (i > 0) const OsdDivider(indent: 72),
                PlaceRow(place: places[i], onTap: () => onPlace(places[i])),
              ],
              if (places.length > _top) ...<Widget>[
                const OsdDivider(),
                _SeeAllRow(
                  label: Strings.placesAllPlaces,
                  count: formats.number(places.length),
                  onTap: onAllPlaces,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SeeAllRow extends StatelessWidget {
  const _SeeAllRow({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final String count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OsdListRow(
    title: label,
    titleStyle: context.typography.rowTitleStrong.copyWith(
      color: context.colors.co,
    ),
    value: count,
    trailing: const OsdRowTrailing.chevron(),
    onTap: onTap,
  );
}
