import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/journey/domain/places_snapshot.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/place_meta_chip.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/place_row.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/places/places_section_title.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_field.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_divider.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Search over the globe: a field over a frosted scrim, the recent trips
/// and the countries until something is typed, then the matching places.
class PlacesSearchLayer extends StatelessWidget {
  const PlacesSearchLayer({
    super.key,
    required this.controller,
    required this.snapshot,
    required this.onClose,
    required this.onPlace,
    required this.onCountry,
  });

  final TextEditingController controller;
  final PlacesSnapshot snapshot;
  final VoidCallback onClose;
  final ValueChanged<DiaryPlace> onPlace;
  final ValueChanged<PlaceCountry> onCountry;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: ColoredBox(
        color: colors.bg.withValues(alpha: .9),
        child: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  spacing: 4,
                  children: <Widget>[
                    Expanded(
                      child: OsdTextField(
                        controller: controller,
                        autofocus: true,
                        hint: Strings.placesSearchHint,
                        leadingIcon: OsdIcons.search,
                        textInputAction: TextInputAction.search,
                        semanticsLabel: Strings.placesSearchHint,
                        onSubmitted: (String q) {
                          final List<DiaryPlace> found = snapshot.search(q);
                          if (found.isNotEmpty) onPlace(found.first);
                        },
                      ),
                    ),
                    OsdTextButton(
                      label: CommonLabels.of(context).cancel,
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder:
                      (
                        BuildContext context,
                        TextEditingValue value,
                        Widget? _,
                      ) {
                        final String q = value.text.trim();
                        if (q.isEmpty) return _suggestions(context);
                        final List<DiaryPlace> found = snapshot.search(q);
                        if (found.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              Strings.placesNoMatch(query: q),
                              textAlign: TextAlign.center,
                              style: typography.body15.copyWith(
                                color: colors.mu,
                              ),
                            ),
                          );
                        }
                        return ListView(
                          padding: _listPadding(context),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          children: <Widget>[
                            OsdCard(
                              margin: EdgeInsets.zero,
                              child: Column(
                                children: <Widget>[
                                  for (
                                    int i = 0;
                                    i < found.length;
                                    i++
                                  ) ...<Widget>[
                                    if (i > 0) const OsdDivider(indent: 72),
                                    PlaceRow(
                                      place: found[i],
                                      onTap: () => onPlace(found[i]),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The page keeps its size under the keyboard, so the list clears it here.
  static EdgeInsets _listPadding(BuildContext context) => EdgeInsets.fromLTRB(
    16,
    8,
    16,
    24 + MediaQuery.viewInsetsOf(context).bottom,
  );

  Widget _suggestions(BuildContext context) {
    final List<DiaryPlace> recent = snapshot
        .route(snapshot.places)
        .reversed
        .take(5)
        .toList();
    final List<PlaceCountry> countries = PlacesSnapshot.countriesOf(
      snapshot.places,
    );
    return ListView(
      padding: _listPadding(context),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: <Widget>[
        if (recent.isNotEmpty) ...<Widget>[
          PlacesSectionTitle(Strings.placesRecentTrips),
          const SizedBox(height: 8),
          OsdCard(
            margin: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < recent.length; i++) ...<Widget>[
                  if (i > 0) const OsdDivider(indent: 72),
                  PlaceRow(place: recent[i], onTap: () => onPlace(recent[i])),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (countries.isNotEmpty) ...<Widget>[
          PlacesSectionTitle(Strings.placesCountries),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final PlaceCountry c in countries)
                OsdPressable(
                  onTap: () => onCountry(c),
                  borderRadius: BorderRadius.circular(OsdRadius.full),
                  semanticsLabel: c.name,
                  child: PlaceMetaChip(icon: OsdIcons.place, label: c.name),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
