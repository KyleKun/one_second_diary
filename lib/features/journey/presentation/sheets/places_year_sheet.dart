import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/journey/domain/places_snapshot.dart';
import 'package:one_second_diary/features/journey/presentation/places_formats.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/month_tile.dart';

/// Choose a year: every year with clips that have a place, newest first,
/// each with its clip count; a tap picks it.
class PlacesYearSheet extends StatelessWidget {
  const PlacesYearSheet({
    super.key,
    required this.snapshot,
    required this.selected,
  });

  static const Key bodyKey = Key('placesYearSheet.body');

  static const int _columns = 3;

  final PlacesSnapshot snapshot;

  /// The year shown now; null for all time.
  final int? selected;

  /// Opens the sheet; completes with the year picked, or null.
  static Future<int?> show(
    BuildContext context, {
    required PlacesSnapshot snapshot,
    required int? selected,
  }) => showOsdSheet<int>(
    context,
    title: Strings.placesChooseYear,
    child: PlacesYearSheet(snapshot: snapshot, selected: selected),
  );

  @override
  Widget build(BuildContext context) {
    final PlacesFormats formats = PlacesFormats.of(context);
    final List<int> years = snapshot.years;
    final List<List<int>> rows = <List<int>>[
      for (int i = 0; i < years.length; i += _columns)
        years.sublist(i, (i + _columns).clamp(0, years.length)),
    ];
    return Column(
      key: bodyKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: <Widget>[
        for (final List<int> row in rows)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: <Widget>[
                for (final int year in row)
                  Expanded(
                    child: MonthTile(
                      month: formats.year(year),
                      count: formats.clips(
                        PlacesSnapshot.clipCountOf(snapshot.inYear(year)),
                      ),
                      selected: year == selected,
                      onTap: () => Navigator.of(context).pop(year),
                    ),
                  ),
                for (int i = row.length; i < _columns; i++) const Spacer(),
              ],
            ),
          ),
      ],
    );
  }
}
