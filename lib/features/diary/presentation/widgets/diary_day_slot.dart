import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_day.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';
import 'package:one_second_diary/features/diary/presentation/diary_viewer_flow.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_day_cell.dart';

/// One day of the calendar wired to the [DiaryCubit]: it selects only its
/// own [DiaryDay] (and the grid-wide look), so selecting a day rebuilds
/// two slots, the old day and the new, and never the grid.
///
/// A long press on a recorded day opens the viewer on its first clip, which
/// flies there from the cell and back to the day the viewer shows last.
class DiaryDaySlot extends StatelessWidget {
  const DiaryDaySlot({
    super.key,
    required this.day,
    this.height = DiaryDayCell.height,
  });

  final LocalDay day;

  final double height;

  @override
  Widget build(BuildContext context) {
    final (
      DiaryDay data,
      bool alternativeColors,
      VideoOrientation orientation,
      bool flies,
    ) = context.select(
      (DiaryCubit cubit) => (
        cubit.state.dayOf(day),
        cubit.state.alternativeColors,
        cubit.state.profile.orientation,
        cubit.state.viewerOrigin == ViewerOrigin.cell,
      ),
    );
    final DiaryFormats formats = DiaryFormats.of(context);
    return DiaryDayCell(
      day: data,
      number: formats.numbers.format(day.day),
      semanticsLabel: <String>[
        formats.fullDate(day),
        ?switch (data.kind) {
          DiaryDayKind.recorded => Strings.a11yDayRecorded,
          DiaryDayKind.missed ||
          DiaryDayKind.beforeFirstClip => Strings.a11yDayMissed,
          DiaryDayKind.future => Strings.a11yDayFuture,
          DiaryDayKind.filteredOut => Strings.a11yDayFilteredOut,
          DiaryDayKind.unknown => null,
        },
        if (data.clipCount > 1)
          Strings.clipCount(data.clipCount, format: formats.numbers),
        if (data.isToday) CommonLabels.of(context).today,
      ].join(', '),
      orientation: orientation,
      alternativeColors: alternativeColors,
      onTap: () => context.read<DiaryCubit>().selectDay(day),
      onLongPress: switch ((data.kind, data.clip)) {
        (DiaryDayKind.recorded, final ClipRef clip) => () => unawaited(
          DiaryViewerFlow.open(context, clip: clip, origin: ViewerOrigin.cell),
        ),
        _ => null,
      },
      longPressLabel: Strings.playerOpenFullScreen,
      flies: flies,
      cellHeight: height,
    );
  }
}
