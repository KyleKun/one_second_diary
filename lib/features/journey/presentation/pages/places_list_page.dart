import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';
import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/journey/domain/places_snapshot.dart';
import 'package:one_second_diary/features/journey/presentation/places_formats.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/country_row.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/place_row.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_segmented_tabs.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_field.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Every country or every place of the year shown, with a filter and, for
/// places, a sort. Picking one pops with it (a `DiaryPlace` or a
/// `PlaceCountry`) so the globe flies there.
class PlacesListPage extends StatefulWidget {
  const PlacesListPage({super.key, required this.args});

  final PlacesListArgs args;

  @override
  State<PlacesListPage> createState() => _PlacesListPageState();
}

enum _Sort { mostClips, recent, name }

class _PlacesListPageState extends State<PlacesListPage> {
  final TextEditingController _query = TextEditingController();
  _Sort _sort = _Sort.mostClips;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matches(String? text) =>
      text != null &&
      TagName.fold(text).contains(TagName.fold(_query.text.trim()));

  List<DiaryPlace> get _sortedPlaces {
    final List<DiaryPlace> places = <DiaryPlace>[
      for (final DiaryPlace p in widget.args.places)
        if (_matches(p.name) || _matches(p.country)) p,
    ];
    return switch (_sort) {
      _Sort.recent =>
        places..sort((DiaryPlace a, DiaryPlace b) => b.last.compareTo(a.last)),
      _Sort.name =>
        places..sort(
          (DiaryPlace a, DiaryPlace b) =>
              TagName.fold(a.name).compareTo(TagName.fold(b.name)),
        ),
      _Sort.mostClips => places,
    };
  }

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final PlacesFormats formats = PlacesFormats.of(context);
    final PlacesListArgs args = widget.args;
    final bool countries = args.kind == PlacesListKind.countries;
    final List<PlaceCountry> allCountries = PlacesSnapshot.countriesOf(
      args.places,
    );
    final int mostClips = allCountries.isEmpty
        ? 1
        : allCountries.first.clipCount;
    final String scope = switch (args.year) {
      final int y => formats.year(y),
      null => Strings.placesAllTime,
    };
    final List<Widget> rows = countries
        ? <Widget>[
            for (int i = 0; i < allCountries.length; i++)
              if (_matches(allCountries[i].name))
                CountryRow(
                  country: allCountries[i],
                  index: i,
                  share: allCountries[i].clipCount / mostClips,
                  onTap: () => Navigator.of(context).pop(allCountries[i]),
                ),
          ]
        : <Widget>[
            for (final DiaryPlace p in _sortedPlaces)
              PlaceRow(place: p, onTap: () => Navigator.of(context).pop(p)),
          ];
    return Scaffold(
      backgroundColor: colors.bg,
      body: Column(
        children: <Widget>[
          OsdAppBar(
            title: Strings.placesJoin(
              a: countries
                  ? formats.countries(allCountries.length)
                  : formats.places(args.places.length),
              b: scope,
            ),
          ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: <Widget>[
                OsdTextField(
                  controller: _query,
                  hint: countries
                      ? Strings.placesFilterCountries
                      : Strings.placesFilterPlaces,
                  leadingIcon: OsdIcons.search,
                  textInputAction: TextInputAction.search,
                  semanticsLabel: countries
                      ? Strings.placesFilterCountries
                      : Strings.placesFilterPlaces,
                  onChanged: (_) => setState(() {}),
                ),
                if (!countries) ...<Widget>[
                  const SizedBox(height: 12),
                  OsdSegmentedTabs(
                    segments: <OsdSegment>[
                      OsdSegment(
                        icon: OsdIcons.videoLibrary,
                        accent: colors.co,
                        label: Strings.placesSortMostClips,
                      ),
                      OsdSegment(
                        icon: OsdIcons.schedule,
                        accent: colors.purple,
                        label: Strings.placesSortRecent,
                      ),
                      OsdSegment(
                        icon: OsdIcons.sell,
                        accent: colors.green,
                        label: Strings.placesSortAz,
                      ),
                    ],
                    index: _sort.index,
                    onChanged: (int i) =>
                        setState(() => _sort = _Sort.values[i]),
                  ),
                ],
                const SizedBox(height: 14),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      Strings.placesNothingMatches(query: _query.text.trim()),
                      textAlign: TextAlign.center,
                      style: context.typography.body15.copyWith(
                        color: colors.mu,
                      ),
                    ),
                  )
                else
                  OsdCard(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: <Widget>[
                        for (int i = 0; i < rows.length; i++) ...<Widget>[
                          if (i > 0) OsdDivider(indent: countries ? 64 : 72),
                          rows[i],
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
