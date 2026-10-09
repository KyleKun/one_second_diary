import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/tab_reselect_listener.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/saved/deleted_clip_snackbar.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_calendar.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_day_actions.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_day_panel.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_month_bar.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_title_row.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/memories_view.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/view_fade_through.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// The Diary tab: the title row, then the calendar (the month header, the
/// month grid, the selected day's player or panel and what goes with it)
/// in a body that scrolls on short screens while the title stays, or
/// Memories ([MemoriesView]); the title row's toggle switches them with a
/// fade-through ([ViewFadeThrough]).
///
/// Everything comes from the [DiaryCubit] in memory, so the first frame is
/// complete; each part selects only what it shows. Tapping the tab again
/// scrolls the view back up and returns to this month. A deleted clip is
/// confirmed here, where the snackbar outlives the day's row.
class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key});

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  final ScrollController _calendarScroll = ScrollController();
  final ScrollController _memoriesScroll = ScrollController();

  /// Memories has shown in this tab: its cards rise in only the first time.
  bool _memoriesShown = false;

  @override
  void dispose() {
    _calendarScroll.dispose();
    _memoriesScroll.dispose();
    super.dispose();
  }

  /// "Video deleted" with the day and Undo, or "Couldn't delete this
  /// video"; each delete asked says one of them.
  void _deletionChanged(BuildContext context, DiaryState state) {
    final ClipRef? clip = state.deletedClip;
    if (clip == null) return;
    switch (state.deletion) {
      case ClipDeletion.deleted:
        DeletedClipSnackbar.show(
          context,
          clip: clip,
          date: DiaryFormats.of(context).fullDate(clip.day),
        );
      case ClipDeletion.failed:
        OsdSnackbar.show(
          context,
          kind: OsdSnackKind.error,
          title: Strings.deleteVideoFailed,
        );
      case ClipDeletion.idle || ClipDeletion.deleting:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final DiaryView view = context.select(
      (DiaryCubit cubit) => cubit.state.view,
    );
    final bool memoriesEntrance = view == DiaryView.memories && !_memoriesShown;
    if (view == DiaryView.memories) _memoriesShown = true;
    return BlocListener<DiaryCubit, DiaryState>(
      listenWhen: (DiaryState before, DiaryState after) =>
          before.deletion != after.deletion,
      listener: _deletionChanged,
      child: TabReselectListener(
        tab: AppRoute.diary,
        scrollController: switch (view) {
          DiaryView.calendar => _calendarScroll,
          DiaryView.memories => _memoriesScroll,
        },
        onReselect: context.read<DiaryCubit>().showThisMonth,
        child: ColoredBox(
          color: context.colors.bg,
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const DiaryTitleRow(),
                Expanded(
                  child: ViewFadeThrough(
                    child: switch (view) {
                      DiaryView.calendar => _CalendarView(
                        key: const ValueKey<DiaryView>(DiaryView.calendar),
                        controller: _calendarScroll,
                      ),
                      DiaryView.memories => MemoriesView(
                        key: const ValueKey<DiaryView>(DiaryView.memories),
                        controller: _memoriesScroll,
                        entrance: memoriesEntrance,
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The month header, the grid, the selected day and what goes with it, in
/// a body that scrolls on short screens. On tablets it keeps to the middle,
/// and from [_twoPanes] wide the month sits beside the day
/// ([_CalendarPanes]).
class _CalendarView extends StatelessWidget {
  const _CalendarView({super.key, required this.controller});

  /// From this width the month and the day sit side by side.
  static const double _twoPanes = 840;

  final ScrollController controller;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      if (constraints.maxWidth >= _twoPanes) {
        return _CalendarPanes(controller: controller);
      }
      final Widget column = _CalendarColumn(controller: controller);
      if (constraints.maxWidth < OsdSizes.tabletShortestSide) return column;
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: OsdSizes.contentMaxWidth),
          child: column,
        ),
      );
    },
  );
}

/// The phone's calendar: one column that scrolls.
class _CalendarColumn extends StatelessWidget {
  const _CalendarColumn({required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    controller: controller,
    physics: const ClampingScrollPhysics(),
    padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DiaryMonthBar(),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: OsdSpace.pageGutter),
          child: DiaryCalendar(),
        ),
        // The day numbers sit at the bottom of their cells: the panel
        // keeps well clear of the last row.
        SizedBox(height: OsdSpace.s24),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: OsdSpace.pageGutter),
          child: DiaryDayPanel(),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: OsdSpace.pageGutter),
          child: DiaryDayActions(),
        ),
        SizedBox(height: OsdSpace.s24),
      ],
    ),
  );
}

/// A wide tablet: the month header and the grid beside the selected day
/// (its player at 16:9 of the pane).
class _CalendarPanes extends StatelessWidget {
  const _CalendarPanes({required this.controller});

  static const double _monthPane = 460;
  static const double _tallestCell = 64;
  static const double _cellRatio = .9;
  static const double _landscape = 16 / 9;

  final ScrollController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(
      OsdSpace.s24,
    ).copyWith(bottom: OsdSpace.s24 + MediaQuery.paddingOf(context).bottom),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: OsdSpace.s24,
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _monthPane),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double column =
                  (constraints.maxWidth - 6 * OsdSpace.gridGapCalendar) / 7;
              return SingleChildScrollView(
                controller: controller,
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const DiaryMonthBar(),
                    DiaryCalendar(
                      cellHeight: math.min(_tallestCell, column * _cellRatio),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) =>
                SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      DiaryDayPanel(
                        mediaHeight: constraints.maxWidth / _landscape,
                      ),
                      const DiaryDayActions(),
                    ],
                  ),
                ),
          ),
        ),
      ],
    ),
  );
}
