import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show toBeginningOfSentenceCase;
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/movies/domain/date_choice.dart';
import 'package:one_second_diary/features/movies/domain/movie_rules.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_state.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/count_tick_text.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/date_field_pair.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/range_day_cell.dart';
import 'package:one_second_diary/shared/widgets/buttons/circle_icon_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/calendar/calendar_month_grid.dart';
import 'package:one_second_diary/shared/widgets/calendar/month_pager.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_overflow_hit_area.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Choose dates: the From and To fields, a month of days (paged between the
/// first recorded day's month and this one), the clips the days picked hold,
/// and Continue.
class ChooseDatesSheet extends StatelessWidget {
  const ChooseDatesSheet({super.key});

  static const Key bodyKey = Key('chooseDatesSheet.body');
  static const Key monthTitleKey = Key('chooseDatesSheet.monthTitle');
  static const Key previousMonthKey = Key('chooseDatesSheet.previousMonth');
  static const Key nextMonthKey = Key('chooseDatesSheet.nextMonth');
  static const Key countKey = Key('chooseDatesSheet.count');
  static const Key continueKey = Key('chooseDatesSheet.continue');

  /// Opens the sheet on the month of the days picked before, or this month.
  static Future<bool> show(BuildContext context) async {
    final CreateMovieCubit flow = context.read<CreateMovieCubit>()
      ..openDatePicker();
    if (flow.state.dateChoice == null) return false;
    final bool? chosen = await showOsdSheet<bool>(
      context,
      title: Strings.movieChooseDates,
      child: BlocProvider<CreateMovieCubit>.value(
        value: flow,
        child: const ChooseDatesSheet(),
      ),
    );
    return chosen ?? false;
  }

  @override
  Widget build(BuildContext context) => const Column(
    key: bodyKey,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: OsdSpace.sheetGap,
    children: <Widget>[_Fields(), _MonthHeader(), _Grid(), _Footer()],
  );
}

/// From and To, following the days picked.
class _Fields extends StatelessWidget {
  const _Fields();

  @override
  Widget build(BuildContext context) {
    final (LocalDay? from, LocalDay? to, DateEnd next) = context
        .select<CreateMovieCubit, (LocalDay?, LocalDay?, DateEnd)>((
          CreateMovieCubit flow,
        ) {
          final DateChoice? choice = flow.state.dateChoice;
          return (choice?.from, choice?.to, choice?.next ?? DateEnd.from);
        });
    final CreateMovieCubit flow = context.read<CreateMovieCubit>();
    return DateFieldPair(
      from: from == null ? null : MovieLabels.dateWithYear(context, from),
      to: to == null ? null : MovieLabels.dateWithYear(context, to),
      active: next,
      onFromTap: flow.restartDates,
      onToTap: flow.repickEndDate,
    );
  }
}

/// The month shown and its arrows.
class _MonthHeader extends StatelessWidget {
  const _MonthHeader();

  @override
  Widget build(BuildContext context) {
    final (DiaryMonth? month, bool previous, bool next) = context
        .select<CreateMovieCubit, (DiaryMonth?, bool, bool)>(
          (CreateMovieCubit flow) => (
            flow.state.dateChoice?.shown,
            flow.state.canShowPreviousDateMonth,
            flow.state.canShowNextDateMonth,
          ),
        );
    if (month == null) return const SizedBox.shrink();
    final CreateMovieCubit flow = context.read<CreateMovieCubit>();
    final CommonLabels labels = CommonLabels.of(context);
    final String title = toBeginningOfSentenceCase(
      MovieLabels.monthYear(context, month.year, month.month),
      Localizations.localeOf(context).toLanguageTag(),
    );
    return Row(
      spacing: OsdSpace.s6,
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              title,
              key: ChooseDatesSheet.monthTitleKey,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.typography.titleSmall.copyWith(
                color: context.colors.tx,
              ),
            ),
          ),
        ),
        OsdOverflowHitArea(
          child: CircleIconButton(
            key: ChooseDatesSheet.previousMonthKey,
            icon: OsdIcons.chevronLeft,
            tooltip: labels.previousMonth,
            onPressed: previous ? flow.showPreviousMonth : null,
          ),
        ),
        OsdOverflowHitArea(
          child: CircleIconButton(
            key: ChooseDatesSheet.nextMonthKey,
            icon: OsdIcons.chevronRight,
            tooltip: labels.nextMonth,
            onPressed: next ? flow.showNextMonth : null,
          ),
        ),
      ],
    );
  }
}

/// The month's days, paged; each day follows its own state.
class _Grid extends StatelessWidget {
  const _Grid();

  @override
  Widget build(BuildContext context) {
    final (DiaryMonth? month, bool previous, bool next) = context
        .select<CreateMovieCubit, (DiaryMonth?, bool, bool)>(
          (CreateMovieCubit flow) => (
            flow.state.dateChoice?.shown,
            flow.state.canShowPreviousDateMonth,
            flow.state.canShowNextDateMonth,
          ),
        );
    if (month == null) return const SizedBox.shrink();
    final CreateMovieCubit flow = context.read<CreateMovieCubit>();
    return MonthPager(
      month: month,
      onPrevious: previous ? flow.showPreviousMonth : null,
      onNext: next ? flow.showNextMonth : null,
      child: CalendarMonthGrid(
        month: month,
        firstWeekday: MaterialLocalizations.of(context).firstDayOfWeekIndex,
        weekdayLetters: LocaleFormats.of(
          context,
        ).symbols.STANDALONENARROWWEEKDAYS,
        cellHeight: RangeDayCell.height,
        dayBuilder: (LocalDay day) =>
            _Day(key: ValueKey<LocalDay>(day), day: day),
      ),
    );
  }
}

/// One day: rebuilds when its own part, clip or bounds change.
class _Day extends StatelessWidget {
  const _Day({super.key, required this.day});

  final LocalDay day;

  @override
  Widget build(BuildContext context) {
    final (
      RangeDayPart part,
      bool hasClip,
      bool enabled,
      bool isToday,
    ) = context.select<CreateMovieCubit, (RangeDayPart, bool, bool, bool)>(
      (CreateMovieCubit flow) => (
        _partOf(flow.state.dateChoice, day),
        flow.state.rangeIndex?.hasDay(day) ?? false,
        flow.state.isPickable(day),
        flow.state.today == day,
      ),
    );
    final String date = MovieLabels.fullDate(context, day);
    final String label = switch (part) {
      RangeDayPart.start => '$date, ${Strings.movieDateFrom}',
      RangeDayPart.end => '$date, ${Strings.movieDateTo}',
      RangeDayPart.between || RangeDayPart.none => date,
    };
    return RangeDayCell(
      key: RangeDayCell.cellKey(day),
      day: day,
      number: MovieLabels.numberFormat(context).format(day.day),
      part: part,
      hasClip: hasClip,
      enabled: enabled,
      isToday: isToday,
      semanticsLabel: label,
      onTap: () => context.read<CreateMovieCubit>().pickDay(day),
    );
  }

  static RangeDayPart _partOf(DateChoice? choice, LocalDay day) {
    final LocalDay? from = choice?.from;
    final LocalDay? to = choice?.to;
    if (from == null) return RangeDayPart.none;
    if (day == from) return RangeDayPart.start;
    if (to == null) return RangeDayPart.none;
    if (day == to) return RangeDayPart.end;
    return day.isAfter(from) && day.isBefore(to)
        ? RangeDayPart.between
        : RangeDayPart.none;
  }
}

/// The clips the days picked hold (or what to pick next), and Continue.
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final (bool fromPicked, bool toPicked, int clips, bool canConfirm) = context
        .select<CreateMovieCubit, (bool, bool, int, bool)>((
          CreateMovieCubit flow,
        ) {
          final CreateMovieState state = flow.state;
          return (
            state.dateChoice?.from != null,
            state.dateChoice?.to != null,
            state.dateRangeClips,
            state.canConfirmDates,
          );
        });
    final OsdColors colors = context.colors;
    final String text = switch ((fromPicked, toPicked)) {
      (false, _) => '',
      (true, false) => Strings.movieDatePickEnd,
      (true, true) when clips == 0 => Strings.movieNoClipsFound,
      (true, true) when clips < MovieRules.minClips =>
        Strings.movieNeedMoreClips(
          MovieRules.minClips,
          format: MovieLabels.numberFormat(context),
        ),
      (true, true) => Strings.movieClipsFound(
        clips,
        format: MovieLabels.numberFormat(context),
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: OsdSpace.s12,
      children: <Widget>[
        CountTickText(
          text: text,
          textKey: ChooseDatesSheet.countKey,
          textAlign: TextAlign.center,
          style: context.typography.titleSmall.copyWith(
            color: canConfirm ? colors.tx : colors.mu,
          ),
        ),
        PrimaryButton(
          key: ChooseDatesSheet.continueKey,
          label: CommonLabels.of(context).continueAction,
          size: OsdButtonSize.standard,
          haptic: OsdHaptic.light,
          onPressed: canConfirm
              ? () {
                  context.read<CreateMovieCubit>().confirmDates();
                  Navigator.of(context).pop(true);
                }
              : null,
        ),
      ],
    );
  }
}
