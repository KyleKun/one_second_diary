import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';
import 'package:one_second_diary/features/diary/presentation/month_progress_label.dart';
import 'package:one_second_diary/features/diary/presentation/month_title_room.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/make_movie_chip.dart';
import 'package:one_second_diary/shared/widgets/calendar/diary_month_header.dart';

/// A Memories month header: [month], its "25 of 28 days" and Make movie
/// for it, on BG; with [scrolledUnder] (pinned over the feed) a hairline
/// fades in at its bottom. The count shows at once: the feed builds
/// headers as they scroll in, and a count-up on each would be noise. Make
/// movie shows only its glyph where its label would cut the title
/// ([MonthTitleRoom]).
class MemoriesMonthHeader extends StatelessWidget {
  const MemoriesMonthHeader({
    super.key,
    required this.month,
    this.scrolledUnder = false,
  });

  final DiaryMonth month;
  final bool scrolledUnder;

  @override
  Widget build(BuildContext context) {
    final MonthCount? count = context.select(
      (DiaryCubit cubit) => cubit.state.monthCountOf(month),
    );
    final DiaryFormats formats = DiaryFormats.of(context);
    final String title = formats.monthTitle(month);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          DiaryMonthHeader.feed(
            title: title,
            recordedDays: count?.recorded ?? 0,
            progress: (int recorded) => MonthProgressLabel.of(
              count,
              recorded: recorded,
              numbers: formats.numbers,
            ),
            action: MakeMovieChip(
              month: month,
              iconOnly: MonthTitleRoom.chipIconOnly(
                context,
                title: title,
                width: constraints.maxWidth,
                feed: true,
              ),
            ),
            scrolledUnder: scrolledUnder,
            countUp: false,
          ),
    );
  }
}
