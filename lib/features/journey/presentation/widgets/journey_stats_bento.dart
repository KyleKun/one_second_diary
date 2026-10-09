import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:one_second_diary/core/l10n/display_text.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/domain/journey_stats.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/journey/domain/diary_place.dart';
import 'package:one_second_diary/features/journey/domain/geo_point.dart';
import 'package:one_second_diary/features/journey/domain/places_snapshot.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/journey_cubit.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/journey_state.dart';
import 'package:one_second_diary/features/journey/presentation/journey_formats.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/counted_number.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/earth_globe.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_entrance.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_stat_value.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/life_so_far_value.dart';
import 'package:one_second_diary/shared/widgets/controls/tag_chip.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_skeleton_block.dart';
import 'package:one_second_diary/shared/widgets/progress/mini_progress_bar.dart';
import 'package:one_second_diary/shared/widgets/surfaces/stat_label.dart';
import 'package:one_second_diary/shared/widgets/surfaces/stat_value.dart';
import 'package:one_second_diary/theme/light_hairline.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The tiles tests reach: [lifeSoFar] is Footage, [moviesMade] the My
/// movies row of the movie card.
enum JourneyTile {
  daysRecorded,
  streak,
  thisMonth,
  lifeSoFar,
  longestStreak,
  moviesMade,
}

/// The counting numbers, in the order their count-ups start.
enum _CountUp { streak, thisMonth, longest, footage, daysRecorded, sinceFirst }

/// The Journey's stats in titled groups: Habit (the streak with its week
/// beside This month and Longest), Time (Footage beside the year's
/// progress), Your diary (Days recorded and the diary's age beside Places
/// on a turning Earth), Tags (the most used tags).
///
/// Numbers count up with the page's [countUp] (0 → 1 once per session; each
/// starts `countUpStagger` after the previous one) and the groups rise in
/// with its [entrance] after the movie card. Each tile rebuilds only when
/// what it shows changes. While the diary is read the values are skeletons;
/// when it can't be read they are "—".
class JourneyStatsBento extends StatelessWidget {
  const JourneyStatsBento({
    super.key,
    required this.countUp,
    required this.entrance,
    required this.onDaysTap,
    required this.onFootageTap,
    required this.onPlacesTap,
  });

  static Key tileKey(JourneyTile tile) =>
      ValueKey<String>('journeyStats.${tile.name}');

  /// The clip count under Footage ("365 clips").
  static const Key footageClipsKey = Key('journeyStats.lifeSoFar.clips');

  /// The page's count-up, 0 → 1.
  final Animation<double> countUp;

  /// The page's entrance, 0 → 1; the groups are its items 2 to 5.
  final Animation<double> entrance;

  /// "Days recorded" and "This month" open the Diary.
  final VoidCallback onDaysTap;

  /// Footage offers the movie of all of it.
  final VoidCallback onFootageTap;

  /// Places opens the Places page.
  final VoidCallback onPlacesTap;

  static const double _gap = 10;

  /// The entrance item of the first group (the movie card and the "Stats"
  /// title come before).
  static const int _firstGroup = 2;

  @override
  Widget build(BuildContext context) {
    final List<Widget> groups = <Widget>[
      _StatGroup(
        title: Strings.journeyGroupHabit,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: _gap,
            children: <Widget>[
              Expanded(
                flex: 11,
                child: _StreakTile(countUp: _staggered(_CountUp.streak)),
              ),
              Expanded(
                flex: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: _gap,
                  children: <Widget>[
                    _ThisMonthTile(
                      countUp: _staggered(_CountUp.thisMonth),
                      onTap: onDaysTap,
                    ),
                    Expanded(
                      child: _LongestTile(
                        countUp: _staggered(_CountUp.longest),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      _StatGroup(
        title: Strings.journeyGroupTime,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: _gap,
            children: <Widget>[
              Expanded(
                child: _FootageTile(
                  countUp: _staggered(_CountUp.footage),
                  onTap: onFootageTap,
                ),
              ),
              const Expanded(child: _YearTile()),
            ],
          ),
        ),
      ),
      _StatGroup(
        title: Strings.journeyGroupYourDiary,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: _gap,
            children: <Widget>[
              Expanded(
                flex: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: _gap,
                  children: <Widget>[
                    _DaysRecordedTile(
                      countUp: _staggered(_CountUp.daysRecorded),
                      onTap: onDaysTap,
                    ),
                    Expanded(
                      child: _SinceFirstClipTile(
                        countUp: _staggered(_CountUp.sinceFirst),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(flex: 11, child: _PlacesTile(onTap: onPlacesTap)),
            ],
          ),
        ),
      ),
      _StatGroup(title: Strings.tags, child: const _TopTagsTile()),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 26,
      children: <Widget>[
        for (int i = 0; i < groups.length; i++)
          JourneyEntrance(
            animation: entrance,
            index: _firstGroup + i,
            child: groups[i],
          ),
      ],
    );
  }

  /// [countUp] for [number]: it starts `countUpStagger` after the previous
  /// one and runs `countUp` with `easeOutCubic`. Made on every rebuild, so
  /// through a CurveTween, which keeps no listener of its own.
  Animation<double> _staggered(_CountUp number) {
    final int last = _CountUp.values.length - 1;
    final int total =
        (OsdMotion.countUp + OsdMotion.countUpStagger * last).inMicroseconds;
    final double start =
        (OsdMotion.countUpStagger * number.index).inMicroseconds / total;
    final double end =
        (OsdMotion.countUpStagger * number.index + OsdMotion.countUp)
            .inMicroseconds /
        total;
    return countUp.drive(
      CurveTween(curve: Interval(start, end, curve: Curves.easeOutCubic)),
    );
  }
}

/// A small muted heading over a group of tiles.
class _StatGroup extends StatelessWidget {
  const _StatGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 8,
    children: <Widget>[
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: Semantics(
          header: true,
          child: Text(
            title,
            style: context.typography.overline.copyWith(
              color: context.colors.mu,
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

/// A bento tile: CARD with the light hairline. One semantics node,
/// [semanticsLabel]; with [onTap] it presses.
class _Tile extends StatelessWidget {
  const _Tile({
    this.tileKey,
    required this.semanticsLabel,
    this.onTap,
    this.pressScale,
    required this.child,
  });

  final Key? tileKey;
  final String semanticsLabel;
  final VoidCallback? onTap;
  final double? pressScale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(OsdRadius.r22);
    final Widget tile = LightHairline(
      radius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: radius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: ExcludeSemantics(child: child),
        ),
      ),
    );
    if (onTap == null) {
      return Semantics(
        key: tileKey,
        container: true,
        label: semanticsLabel,
        child: tile,
      );
    }
    return OsdPressable(
      key: tileKey,
      onTap: onTap,
      pressScale: pressScale,
      borderRadius: radius,
      semanticsLabel: semanticsLabel,
      child: tile,
    );
  }
}

/// What a stat tile shows of the Journey state.
typedef _Shown = ({JourneyStatus status, JourneyStats? stats});

_Shown _shownOf(JourneyState state) =>
    (status: state.status, stats: state.stats);

extension on _Shown {
  bool get ready => status == JourneyStatus.ready && stats != null;
}

/// A value's place: a skeleton while the diary is read, "—" when it can't
/// be, else [value].
class _ValueSlot extends StatelessWidget {
  const _ValueSlot({
    required this.status,
    required this.value,
    this.hero = false,
    this.alignment = AlignmentDirectional.centerStart,
  });

  final JourneyStatus status;
  final Widget value;
  final bool hero;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) => switch (status) {
    JourneyStatus.loading => Align(
      alignment: alignment,
      child: hero
          ? const OsdSkeletonBlock(width: 110, height: 64)
          : const OsdSkeletonBlock(width: 60, height: 34),
    ),
    JourneyStatus.failed => Align(
      alignment: alignment,
      child: _Unknown(hero: hero),
    ),
    JourneyStatus.ready => value,
  };
}

/// A caption's place: a skeleton while the diary is read, "—" when it
/// can't be, else [text].
class _CaptionSlot extends StatelessWidget {
  const _CaptionSlot({
    required this.status,
    required this.text,
    this.textAlign = TextAlign.start,
    this.textKey,
  });

  final JourneyStatus status;
  final String text;
  final TextAlign textAlign;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = context.typography.caption13.copyWith(
      color: context.colors.mu,
    );
    return switch (status) {
      JourneyStatus.loading => Align(
        alignment: textAlign == TextAlign.center
            ? Alignment.center
            : AlignmentDirectional.centerStart,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 3),
          child: OsdSkeletonBlock.text(width: 60),
        ),
      ),
      JourneyStatus.failed => Text('—', textAlign: textAlign, style: style),
      JourneyStatus.ready => Text(
        text,
        key: textKey,
        textAlign: textAlign,
        style: style,
      ),
    };
  }
}

/// A value the diary could not give: "—".
class _Unknown extends StatelessWidget {
  const _Unknown({this.hero = false});

  final bool hero;

  @override
  Widget build(BuildContext context) {
    final OsdTypography typography = context.typography;
    return Text(
      '—',
      maxLines: 1,
      textScaler: OsdTextScale.scalerFor(context, OsdTextScaleRole.display),
      style: (hero ? typography.displayHero : typography.displayStat).copyWith(
        color: context.colors.mu,
      ),
    );
  }
}

/// A tile's counting number with its unit, in the locale's digits.
class _Counted extends StatelessWidget {
  const _Counted({
    required this.text,
    required this.value,
    required this.countUp,
    this.hero = false,
  });

  final String text;
  final int value;
  final Animation<double> countUp;
  final bool hero;

  @override
  Widget build(BuildContext context) => JourneyStatValue(
    text: text,
    value: value,
    format: (int value) => JourneyFormats.number(context, value),
    progress: countUp,
    hero: hero,
  );
}

String _dayCount(BuildContext context, int days) => DisplayText.safe(
  Strings.dayCount(days, format: JourneyFormats.numberFormat(context)),
);

/// The streak, big, over this week: a filled dot per recorded day, the
/// others (today still open, the days to come) outlined.
class _StreakTile extends StatelessWidget {
  const _StreakTile({required this.countUp});

  final Animation<double> countUp;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final _Shown shown = context.select<JourneyCubit, _Shown>(
      (JourneyCubit cubit) => _shownOf(cubit.state),
    );
    final int days = shown.stats?.currentStreak ?? 0;
    final String text = _dayCount(context, days);
    return _Tile(
      tileKey: JourneyStatsBento.tileKey(JourneyTile.streak),
      semanticsLabel: '${Strings.journeyStreak}, ${shown.ready ? text : '—'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StatLabel(
            icon: OsdIcons.localFireDepartment,
            accent: colors.yellow,
            label: Strings.journeyStreak,
          ),
          const SizedBox(height: 10),
          _ValueSlot(
            status: shown.status,
            hero: true,
            value: _Counted(
              text: text,
              value: days,
              countUp: countUp,
              hero: true,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 14),
          _WeekDots(recorded: shown.stats?.weekRecorded),
        ],
      ),
    );
  }
}

/// This week's seven dots, from the locale's first weekday, each under its
/// narrow weekday letter.
class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.recorded});

  /// Index 0 is Monday; null while unknown (every dot open).
  final List<bool>? recorded;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    // 0 is Sunday in both.
    final int first = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final List<String> letters = LocaleFormats.of(
      context,
    ).symbols.STANDALONENARROWWEEKDAYS;
    final List<bool>? recorded = this.recorded;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        for (int i = 0; i < 7; i++)
          Builder(
            builder: (BuildContext context) {
              final int sundayBased = (first + i) % 7;
              final int mondayBased = (sundayBased + 6) % 7;
              final bool filled =
                  recorded != null &&
                  mondayBased < recorded.length &&
                  recorded[mondayBased];
              return Column(
                spacing: 4,
                children: <Widget>[
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? colors.yellow : null,
                      border: filled
                          ? null
                          : Border.all(color: colors.yellow, width: 1.5),
                    ),
                  ),
                  Text(
                    letters[sundayBased],
                    style: typography.microBadge.copyWith(color: colors.mu),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// "This month 24 / 28" over its bar; opens the Diary on this month.
class _ThisMonthTile extends StatelessWidget {
  const _ThisMonthTile({required this.countUp, required this.onTap});

  final Animation<double> countUp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final _Shown shown = context.select<JourneyCubit, _Shown>(
      (JourneyCubit cubit) => _shownOf(cubit.state),
    );
    final int recorded = shown.stats?.thisMonth.recorded ?? 0;
    final int total = shown.stats?.thisMonth.elapsed ?? 0;
    final String text = Strings.journeyThisMonthValue(
      recorded: recorded,
      total: total,
    );
    // Heard as "4 of 28 days": the drawn "4 / 28" reads as a slash.
    final String spoken = Strings.diaryMonthProgress(
      total,
      recorded: recorded,
      format: JourneyFormats.numberFormat(context),
    );
    return _Tile(
      tileKey: JourneyStatsBento.tileKey(JourneyTile.thisMonth),
      semanticsLabel: '${Strings.thisMonth}, ${shown.ready ? spoken : '—'}',
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: <Widget>[
          StatLabel(
            icon: OsdIcons.checkCircle,
            accent: colors.green,
            label: Strings.thisMonth,
          ),
          _ValueSlot(
            status: shown.status,
            value: _Counted(text: text, value: recorded, countUp: countUp),
          ),
          const SizedBox(height: 4),
          MiniProgressBar(value: shown.stats?.thisMonth.ratio ?? 0),
        ],
      ),
    );
  }
}

/// The longest streak.
class _LongestTile extends StatelessWidget {
  const _LongestTile({required this.countUp});

  final Animation<double> countUp;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final _Shown shown = context.select<JourneyCubit, _Shown>(
      (JourneyCubit cubit) => _shownOf(cubit.state),
    );
    final int days = shown.stats?.longestStreak ?? 0;
    final String text = _dayCount(context, days);
    return _Tile(
      tileKey: JourneyStatsBento.tileKey(JourneyTile.longestStreak),
      semanticsLabel: '${Strings.journeyLongest}, ${shown.ready ? text : '—'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: <Widget>[
          StatLabel(
            icon: OsdIcons.emojiEvents,
            accent: colors.yellow,
            label: Strings.journeyLongest,
          ),
          _ValueSlot(
            status: shown.status,
            value: _Counted(text: text, value: days, countUp: countUp),
          ),
        ],
      ),
    );
  }
}

/// What Footage shows of the Journey state.
typedef _Footage = ({JourneyStatus status, JourneyStats? stats, int clipCount});

/// Footage: the length of every clip together, centred, with the clip
/// count at the foot; offers the movie of all of it.
class _FootageTile extends StatelessWidget {
  const _FootageTile({required this.countUp, required this.onTap});

  final Animation<double> countUp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final _Footage shown = context.select<JourneyCubit, _Footage>(
      (JourneyCubit cubit) => (
        status: cubit.state.status,
        stats: cubit.state.stats,
        clipCount: cubit.state.clipCount,
      ),
    );
    final bool ready = shown.status == JourneyStatus.ready;
    final int seconds = shown.stats?.lifeSoFar.inSeconds ?? 0;
    final bool estimate = shown.stats?.lifeSoFarIsEstimate ?? false;
    // Heard in words: the drawn "46 s" reads as a letter.
    final String spoken = LifeSoFarValue.spokenOf(
      seconds: seconds,
      estimate: estimate,
    );
    final String clips = Strings.clipCount(
      shown.clipCount,
      format: JourneyFormats.numberFormat(context),
    );
    return _Tile(
      tileKey: JourneyStatsBento.tileKey(JourneyTile.lifeSoFar),
      semanticsLabel: ready
          ? '${Strings.journeyFootage}, $spoken, $clips'
          : '${Strings.journeyFootage}, —',
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StatLabel(
            icon: OsdIcons.movie,
            accent: colors.purple,
            label: Strings.journeyFootage,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: _ValueSlot(
                  status: shown.status,
                  alignment: Alignment.center,
                  value: LifeSoFarValue(
                    seconds: seconds,
                    estimate: estimate,
                    progress: countUp,
                  ),
                ),
              ),
            ),
          ),
          _CaptionSlot(
            status: shown.status,
            text: clips,
            textAlign: TextAlign.center,
            textKey: JourneyStatsBento.footageClipsKey,
          ),
        ],
      ),
    );
  }
}

/// How far the current year has gone (from the stats' today): the share
/// centred, then a plain bar over the days left.
class _YearTile extends StatelessWidget {
  const _YearTile();

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final _Shown shown = context.select<JourneyCubit, _Shown>(
      (JourneyCubit cubit) => _shownOf(cubit.state),
    );
    final LocalDay? today = shown.stats?.today;
    final String label = today == null ? Strings.thisYear : '${today.year}';
    double done = 0;
    int daysLeft = 0;
    if (today != null) {
      final DateTime start = DateTime.utc(today.year);
      final int yearDays = DateTime.utc(
        today.year + 1,
      ).difference(start).inDays;
      final int dayOfYear =
          DateTime.utc(
            today.year,
            today.month,
            today.day,
          ).difference(start).inDays +
          1;
      done = dayOfYear / yearDays;
      daysLeft = yearDays - dayOfYear;
    }
    final String percent = DisplayText.safe(
      LocaleFormats.of(context).percent.format(done),
    );
    final String digits = JourneyFormats.number(context, (done * 100).round());
    final String left = Strings.journeyDaysLeft(
      daysLeft,
      format: JourneyFormats.numberFormat(context),
    );
    return _Tile(
      semanticsLabel: shown.ready ? '$label, $percent, $left' : '$label, —',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          StatLabel(
            icon: OsdIcons.hourglassTop,
            accent: colors.co,
            label: label,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: _ValueSlot(
                  status: shown.status,
                  alignment: Alignment.center,
                  value: StatValue(text: percent, emphasis: digits),
                ),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(OsdRadius.full),
            child: SizedBox(
              height: 8,
              child: ColoredBox(
                color: colors.c2,
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: done,
                  child: ColoredBox(color: colors.co),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _CaptionSlot(
            status: shown.status,
            text: left,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A small stat: the accent icon in a disc, the value, the label.
class _SmallStat extends StatelessWidget {
  const _SmallStat({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color accent;
  final Widget value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 6,
    children: <Widget>[
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .16),
          shape: BoxShape.circle,
        ),
        child: Center(child: OsdIcon(icon, size: 20, color: accent)),
      ),
      value,
      Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.typography.caption.copyWith(color: context.colors.mu),
      ),
    ],
  );
}

/// A small stat's counting value, one line in displayValue; the box is as
/// wide as the final number.
class _CountedLine extends StatelessWidget {
  const _CountedLine({
    required this.text,
    required this.value,
    required this.countUp,
  });

  final String text;
  final int value;
  final Animation<double> countUp;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = context.typography.displayValue.copyWith(
      color: context.colors.tx,
    );
    final TextScaler scaler = OsdTextScale.scalerFor(
      context,
      OsdTextScaleRole.display,
    );
    String format(int value) => JourneyFormats.number(context, value);
    final String number = format(value);
    final int at = JourneyStatValue.numberAt(text, number);
    if (at < 0) {
      return Text(text, maxLines: 1, textScaler: scaler, style: style);
    }
    final String prefix = text.substring(0, at);
    final String suffix = text.substring(at + number.length);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          if (prefix.isNotEmpty)
            Text(prefix, maxLines: 1, textScaler: scaler, style: style),
          CountedNumber(
            value: value,
            format: format,
            progress: countUp,
            style: style,
            textScaler: scaler,
          ),
          if (suffix.isNotEmpty)
            Text(suffix, maxLines: 1, textScaler: scaler, style: style),
        ],
      ),
    );
  }
}

/// A small stat's value place: a skeleton while the diary is read, "—"
/// when it can't be, else [value].
class _SmallValueSlot extends StatelessWidget {
  const _SmallValueSlot({required this.status, required this.value});

  final JourneyStatus status;
  final Widget value;

  @override
  Widget build(BuildContext context) => switch (status) {
    JourneyStatus.loading => const Align(
      alignment: AlignmentDirectional.centerStart,
      child: OsdSkeletonBlock(width: 60, height: 28),
    ),
    JourneyStatus.failed => Text(
      '—',
      maxLines: 1,
      textScaler: OsdTextScale.scalerFor(context, OsdTextScaleRole.display),
      style: context.typography.displayValue.copyWith(color: context.colors.mu),
    ),
    JourneyStatus.ready => value,
  };
}

/// "Days recorded"; opens the Diary on this month.
class _DaysRecordedTile extends StatelessWidget {
  const _DaysRecordedTile({required this.countUp, required this.onTap});

  final Animation<double> countUp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final _Shown shown = context.select<JourneyCubit, _Shown>(
      (JourneyCubit cubit) => _shownOf(cubit.state),
    );
    final int days = shown.stats?.daysRecorded ?? 0;
    return _Tile(
      tileKey: JourneyStatsBento.tileKey(JourneyTile.daysRecorded),
      semanticsLabel: shown.ready
          ? Strings.daysRecorded(
              days,
              format: JourneyFormats.numberFormat(context),
            )
          : '${Strings.journeyDaysRecorded}, —',
      onTap: onTap,
      child: _SmallStat(
        icon: OsdIcons.calendarMonth,
        accent: context.colors.co,
        label: Strings.journeyDaysRecorded,
        value: _SmallValueSlot(
          status: shown.status,
          value: _CountedLine(
            text: JourneyFormats.number(context, days),
            value: days,
            countUp: countUp,
          ),
        ),
      ),
    );
  }
}

/// The diary's age: the days since the first clip, with its month; before
/// any clip, "Your first second starts today".
class _SinceFirstClipTile extends StatelessWidget {
  const _SinceFirstClipTile({required this.countUp});

  final Animation<double> countUp;

  @override
  Widget build(BuildContext context) {
    final _Shown shown = context.select<JourneyCubit, _Shown>(
      (JourneyCubit cubit) => _shownOf(cubit.state),
    );
    final int? days = shown.stats?.daysSinceFirstClip;
    final LocalDay? first = shown.stats?.firstDay;
    final String label = days == null || first == null
        ? Strings.journeyNoRecordingsYet
        : Strings.journeySinceFirstClip(
            month: LocaleFormats.of(
              context,
            ).date('yMMM').format(first.toLocalDateTime()),
          );
    final String text = _dayCount(context, days ?? 0);
    return _Tile(
      semanticsLabel: !shown.ready
          ? '$label, —'
          : days == null
          ? label
          : '$label, $text',
      child: _SmallStat(
        icon: OsdIcons.history,
        accent: context.colors.purple,
        label: label,
        value: _SmallValueSlot(
          status: shown.status,
          value: days == null
              ? const _Unknown()
              : _CountedLine(text: text, value: days, countUp: countUp),
        ),
      ),
    );
  }
}

/// What Places shows of the Journey state.
typedef _PlacesShown = ({JourneyStatus status, PlacesSnapshot? places});

/// Places on a turning Earth, a dot per place on the map; opens the Places
/// page. With no places yet it invites to add them; with names but no
/// coordinates it counts them without dots. Under the count, "Tap to see"
/// once there is anything to open.
class _PlacesTile extends StatelessWidget {
  const _PlacesTile({required this.onTap});

  final VoidCallback onTap;

  static const GeoPoint _nowhere = GeoPoint(22, -25);

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final _PlacesShown shown = context.select<JourneyCubit, _PlacesShown>(
      (JourneyCubit cubit) =>
          (status: cubit.state.status, places: cubit.state.places),
    );
    final PlacesSnapshot? places = shown.places;
    final List<DiaryPlace> mapped = places?.mapped ?? const <DiaryPlace>[];
    final GeoPoint facing = places == null || mapped.isEmpty
        ? _nowhere
        : places.framing(mapped).$1;
    final (String value, String emphasis, String? sub) = _valueOf(
      context,
      places,
    );
    final bool ready = shown.status == JourneyStatus.ready && places != null;
    final bool hasPlaces = ready && !places.isEmpty;
    return _Tile(
      semanticsLabel: ready
          ? <String>[value, ?sub].join(', ')
          : '${Strings.places}, —',
      onTap: shown.status == JourneyStatus.failed ? null : onTap,
      pressScale: OsdPressScale.button.scale,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 4,
        children: <Widget>[
          StatLabel(
            icon: OsdIcons.place,
            accent: colors.green,
            label: Strings.places,
          ),
          Center(
            child: SizedBox.square(
              dimension: 132,
              child: SpinningEarth(
                facing: facing,
                dots: <GlobeDot>[
                  for (final DiaryPlace p in mapped) GlobeDot(p.at!, size: 1.3),
                ],
                fill: .8,
              ),
            ),
          ),
          const Spacer(),
          _ValueSlot(
            status: shown.status,
            value: StatValue(text: value, emphasis: emphasis),
          ),
          if (ready && sub != null)
            Text(sub, style: typography.caption13.copyWith(color: colors.mu)),
          if (hasPlaces) ...<Widget>[
            const SizedBox(height: 6),
            Row(
              spacing: 2,
              children: <Widget>[
                Flexible(
                  child: Text(
                    Strings.journeyTapToSee,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.label13.copyWith(color: colors.co),
                  ),
                ),
                OsdIcon(OsdIcons.chevronRight, size: 16, color: colors.co),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// The value, its emphasised part and the line under it. A diary whose
  /// mapped places carry no country has no line.
  static (String, String, String?) _valueOf(
    BuildContext context,
    PlacesSnapshot? places,
  ) {
    if (places == null || places.isEmpty) {
      return (
        Strings.journeyAddPlaces,
        Strings.journeyAddPlaces,
        Strings.journeyAddPlacesHint,
      );
    }
    final int n = places.places.length;
    final String count = DisplayText.safe(
      Strings.journeyPlaceCount(
        n,
        format: JourneyFormats.numberFormat(context),
      ),
    );
    final String number = JourneyFormats.number(context, n);
    if (!places.hasMapped) {
      return (count, number, Strings.journeyPlacesNotOnMap);
    }
    final List<PlaceCountry> countries = PlacesSnapshot.countriesOf(
      places.places,
    );
    return switch (countries.length) {
      0 => (count, number, null),
      1 => (
        count,
        number,
        Strings.journeyPlacesAllIn(country: countries.single.name),
      ),
      _ => (
        count,
        number,
        Strings.journeyPlacesInCountries(
          countries.length,
          format: JourneyFormats.numberFormat(context),
        ),
      ),
    };
  }
}

/// What Top tags shows of the Journey state.
typedef _TagsShown = ({JourneyStatus status, List<TagCount> tags});

/// The most used tags: their share of tagged clips as one strip, then the
/// top five with counts; "No tags yet" without any.
class _TopTagsTile extends StatelessWidget {
  const _TopTagsTile();

  static const int _shown = 5;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final _TagsShown shown = context.select<JourneyCubit, _TagsShown>(
      (JourneyCubit cubit) =>
          (status: cubit.state.status, tags: cubit.state.tagCounts),
    );
    final List<TagCount> tags = shown.tags;
    final List<TagCount> top = tags.take(_shown).toList();
    final int total = tags.fold(0, (int sum, TagCount t) => sum + t.count);
    final int topTotal = top.fold(0, (int sum, TagCount t) => sum + t.count);
    final TagColors? tagColors = top.isEmpty ? null : context.read<TagColors>();
    final NumberFormat numbers = JourneyFormats.numberFormat(context);
    final NumberFormat percent = LocaleFormats.of(context).percent;
    final String semantics = switch (shown.status) {
      JourneyStatus.loading ||
      JourneyStatus.failed => '${Strings.journeyTopTags}, —',
      JourneyStatus.ready when top.isEmpty =>
        '${Strings.journeyTopTags}, ${Strings.tagsNoneYet}',
      JourneyStatus.ready =>
        '${Strings.journeyTopTags}, '
            '${top.map((TagCount t) => '${t.name} ${numbers.format(t.count)}').join(', ')}',
    };
    return _Tile(
      semanticsLabel: semantics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: <Widget>[
          StatLabel(
            icon: OsdIcons.sell,
            accent: colors.co,
            label: Strings.journeyTopTags,
          ),
          if (shown.status != JourneyStatus.ready || top.isEmpty)
            _CaptionSlot(status: shown.status, text: Strings.tagsNoneYet)
          else ...<Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(OsdRadius.full),
              child: SizedBox(
                height: 10,
                // The top tags, then the rest as one segment: a diary with
                // hundreds of tags would leave no room for the gaps.
                child: Row(
                  spacing: 2,
                  children: <Widget>[
                    for (final TagCount tag in top)
                      Expanded(
                        flex: math.max(1, tag.count),
                        child: ColoredBox(color: tagColors!.colorOf(tag.name)),
                      ),
                    if (total > topTotal)
                      Expanded(
                        flex: total - topTotal,
                        child: ColoredBox(color: colors.c2),
                      ),
                  ],
                ),
              ),
            ),
            Column(
              spacing: 10,
              children: <Widget>[
                for (int i = 0; i < top.length; i++)
                  Row(
                    spacing: 8,
                    children: <Widget>[
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 18),
                        child: Text(
                          numbers.format(i + 1),
                          style: typography.label13.copyWith(color: colors.mu),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TagChip(
                            label: top[i].name,
                            color: tagColors!.colorOf(top[i].name),
                            compact: true,
                          ),
                        ),
                      ),
                      Text(
                        numbers.format(top[i].count),
                        style: typography.label14Strong.copyWith(
                          color: colors.tx,
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 40),
                        child: Text(
                          percent.format(total == 0 ? 0 : top[i].count / total),
                          textAlign: TextAlign.end,
                          style: typography.caption.copyWith(color: colors.mu),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
