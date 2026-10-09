import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_day_cell.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_day_slot.dart';
import 'package:one_second_diary/shared/widgets/calendar/calendar_month_grid.dart';
import 'package:one_second_diary/shared/widgets/calendar/month_pager.dart';

/// The month grid of the [DiaryCubit]'s month, paged with [MonthPager], in
/// a `RepaintBoundary` (the rings and thumbnails repaint alone).
///
/// It rebuilds only when the month or its bounds change: each day is a
/// [DiaryDaySlot] that follows its own state.
class DiaryCalendar extends StatelessWidget {
  const DiaryCalendar({super.key, this.cellHeight = DiaryDayCell.height});

  /// How tall a day is (taller in a tablet's two panes).
  final double cellHeight;

  @override
  Widget build(BuildContext context) {
    final (DiaryMonth month, bool canShowPrevious, bool canShowNext) = context
        .select(
          (DiaryCubit cubit) => (
            cubit.state.month,
            cubit.state.canShowPrevious,
            cubit.state.canShowNext,
          ),
        );
    final DiaryCubit cubit = context.read<DiaryCubit>();
    return RepaintBoundary(
      child: MonthPager(
        month: month,
        onPrevious: canShowPrevious ? cubit.showPreviousMonth : null,
        onNext: canShowNext ? cubit.showNextMonth : null,
        child: CalendarMonthGrid(
          month: month,
          firstWeekday: MaterialLocalizations.of(context).firstDayOfWeekIndex,
          weekdayLetters: DiaryFormats.of(context).narrowWeekdays,
          cellHeight: cellHeight,
          dayBuilder: (LocalDay day) => DiaryDaySlot(
            key: ValueKey<LocalDay>(day),
            day: day,
            height: cellHeight,
          ),
        ),
      ),
    );
  }
}
