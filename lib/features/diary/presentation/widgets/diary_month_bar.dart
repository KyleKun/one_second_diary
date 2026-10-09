import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';
import 'package:one_second_diary/features/diary/presentation/month_progress_label.dart';
import 'package:one_second_diary/features/diary/presentation/month_title_room.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/make_movie_chip.dart';
import 'package:one_second_diary/shared/widgets/calendar/diary_month_header.dart';

/// The calendar's month header wired to the [DiaryCubit]: the month, "25
/// of 28 days" (days from the profile's first clip through today; blank
/// when none counts, "–" while the diary is read), "Make movie" and the
/// two month arrows.
///
/// "Make movie" starts a movie of the month shown with the active profile
/// (`CreateMovieArgs(source: MovieSource.month(…))`). With fewer than two
/// clips in the month it is dimmed, and a tap says why.
///
/// "Make movie" shows only its glyph where its label would cut the month
/// title ([MonthTitleRoom]).
///
/// It rebuilds only when what it shows changes, never on a day tap.
class DiaryMonthBar extends StatelessWidget {
  const DiaryMonthBar({super.key});

  static const Key makeMovieKey = Key('diaryMonthBar.makeMovie');

  @override
  Widget build(BuildContext context) {
    final (DiaryMonth month, MonthCount? count) = context.select(
      (DiaryCubit cubit) => (cubit.state.month, cubit.state.monthCount),
    );
    final (bool canShowPrevious, bool canShowNext) = context.select(
      (DiaryCubit cubit) =>
          (cubit.state.canShowPrevious, cubit.state.canShowNext),
    );
    final DiaryFormats formats = DiaryFormats.of(context);
    final CommonLabels labels = CommonLabels.of(context);
    final DiaryCubit cubit = context.read<DiaryCubit>();
    final String title = formats.monthTitle(month);
    String progress(int recorded) => MonthProgressLabel.of(
      count,
      recorded: recorded,
      numbers: formats.numbers,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          DiaryMonthHeader(
            title: title,
            recordedDays: count?.recorded ?? 0,
            progress: progress,
            action: MakeMovieChip(
              key: makeMovieKey,
              month: month,
              iconOnly: MonthTitleRoom.chipIconOnly(
                context,
                title: title,
                count: progress(count?.recorded ?? 0),
                width: constraints.maxWidth,
              ),
            ),
            onPrevious: canShowPrevious ? cubit.showPreviousMonth : null,
            onNext: canShowNext ? cubit.showNextMonth : null,
            previousTooltip: labels.previousMonth,
            nextTooltip: labels.nextMonth,
          ),
    );
  }
}
