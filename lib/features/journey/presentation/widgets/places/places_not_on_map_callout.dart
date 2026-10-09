import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/places_map_state.dart';
import 'package:one_second_diary/features/journey/presentation/places_formats.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/place_row.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/places_icon_disc.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Places with names but no coordinates: each row opens the pin sheet, and
/// the "City, Country" names among them can be looked up in one go.
class PlacesNotOnMapCallout extends StatefulWidget {
  const PlacesNotOnMapCallout({
    super.key,
    required this.places,
    required this.lookUpCount,
    required this.locating,
    required this.outcome,
    required this.missing,
    required this.onPlace,
    required this.onLookUp,
  });

  /// Rows shown before "Show all".
  static const int collapsed = 4;

  /// Most clips first.
  final List<DiaryPlace> places;

  /// How many of [places] the lookup can ask about; the button is hidden
  /// at 0.
  final int lookUpCount;
  final bool locating;
  final PlaceLookupOutcome? outcome;

  /// Names the last lookup could not find.
  final int missing;
  final ValueChanged<DiaryPlace> onPlace;
  final VoidCallback onLookUp;

  @override
  State<PlacesNotOnMapCallout> createState() => _PlacesNotOnMapCalloutState();
}

class _PlacesNotOnMapCalloutState extends State<PlacesNotOnMapCallout> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final PlacesFormats formats = PlacesFormats.of(context);
    final List<DiaryPlace> places = widget.places;
    final bool overflow = places.length > PlacesNotOnMapCallout.collapsed;
    final List<DiaryPlace> shown = overflow && !_expanded
        ? places.sublist(0, PlacesNotOnMapCallout.collapsed)
        : places;
    final String? note = switch (widget.outcome) {
      PlaceLookupOutcome.partial => Strings.placesLookupPartial(
        widget.missing,
        format: formats.numbers,
      ),
      PlaceLookupOutcome.none => Strings.placesLookupNone,
      PlaceLookupOutcome.offline => Strings.placesLookupOffline,
      PlaceLookupOutcome.found || null => null,
    };
    return OsdCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: <Widget>[
              PlacesIconDisc(icon: OsdIcons.place, accent: colors.green),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: <Widget>[
                    Text(
                      Strings.placesNotOnMapCount(
                        places.length,
                        format: formats.numbers,
                      ),
                      style: typography.rowTitleStrong.copyWith(
                        color: colors.tx,
                      ),
                    ),
                    Text(
                      Strings.placesNotOnMapBody,
                      style: typography.rowSubtitle.copyWith(color: colors.mu),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (final DiaryPlace place in shown)
                PlaceRow(place: place, onTap: () => widget.onPlace(place)),
            ],
          ),
          if (overflow)
            OsdTextButton(
              label: _expanded
                  ? Strings.placesNotOnMapShowFewer
                  : Strings.placesNotOnMapShowAll(
                      count: formats.number(places.length),
                    ),
              icon: _expanded ? OsdIcons.closeFullscreen : OsdIcons.expandMore,
              tone: OsdTextButtonTone.muted,
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          if (note != null)
            Text(note, style: typography.caption13.copyWith(color: colors.mu)),
          if (widget.lookUpCount > 0)
            PrimaryButton(
              label: Strings.placesLookUpNames(
                widget.lookUpCount,
                format: formats.numbers,
              ),
              loadingLabel: Strings.placesFinding(
                widget.lookUpCount,
                format: formats.numbers,
              ),
              icon: OsdIcons.search,
              loading: widget.locating,
              onPressed: widget.onLookUp,
            ),
        ],
      ),
    );
  }
}
