import 'package:flutter/material.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/shared/widgets/calendar/weekday_header_row.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hit_slop.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// The calendar's month grid: the weekday letters from the locale's
/// [firstWeekday], then one row per week the [month] needs (4, 5 or 6) of 7
/// equal columns, blanks outside the month. RTL flows right to left.
///
/// Each day comes from [dayBuilder]. The weeks let taps 3 px into the row
/// gaps through (the day cells' hit areas). Nothing is clipped: the rings
/// reach outside a day.
///
/// The grid has no state of its own: it rebuilds only when its month or
/// locale does, and each day scopes its own rebuilds.
class CalendarMonthGrid extends StatelessWidget {
  const CalendarMonthGrid({
    super.key,
    required this.month,
    required this.firstWeekday,
    required this.weekdayLetters,
    required this.dayBuilder,
    this.cellHeight = _cellHeight,
  });

  static const Key weekdaysKey = Key('calendarMonthGrid.weekdays');

  static const double _cellHeight = 42;

  final DiaryMonth month;

  /// The week's first day: 0 is Sunday (`firstDayOfWeekIndex`).
  final int firstWeekday;

  /// The narrow weekday names, Sunday first.
  final List<String> weekdayLetters;

  /// Builds the day of [LocalDay] ([cellHeight] tall).
  final Widget Function(LocalDay day) dayBuilder;

  /// How tall a day is; taller in a tablet's two panes.
  final double cellHeight;

  @override
  Widget build(BuildContext context) {
    final int blanks = month.leadingBlanks(firstWeekday: firstWeekday);
    final int weeks = month.weekCount(firstWeekday: firstWeekday);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: OsdSpace.gridGapCalendar,
      children: <Widget>[
        WeekdayHeaderRow(
          key: weekdaysKey,
          letters: <String>[
            for (int column = 0; column < 7; column++)
              weekdayLetters[(firstWeekday + column) % 7],
          ],
        ),
        for (int week = 0; week < weeks; week++)
          OsdHitSlop(
            slop: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              spacing: OsdSpace.gridGapCalendar,
              children: <Widget>[
                for (int column = 0; column < 7; column++)
                  Expanded(
                    child: switch (week * 7 + column - blanks + 1) {
                      final int day when day >= 1 && day <= month.dayCount =>
                        dayBuilder(LocalDay(month.year, month.month, day)),
                      _ => SizedBox(height: cellHeight),
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
