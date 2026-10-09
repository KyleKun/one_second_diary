import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/display_text.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_cubit.dart';
import 'package:one_second_diary/features/today/presentation/today_motion.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_profile_chip.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hit_slop.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Today's header: the weekday in capitals over the big date (scaled down
/// to fit one line), and the profile chip at the end, its bottom on the
/// date's.
///
/// The dates are one heading for screen readers ("Monday, September 28")
/// and crossfade when the day rolls over at midnight.
class TodayHeader extends StatelessWidget {
  const TodayHeader({super.key});

  static const Key weekdayKey = Key('todayHeader.weekday');

  static const Key dateKey = Key('todayHeader.date');

  /// How far the chip's 48 hit area reaches below the 38 tall chip, which
  /// sits on the header's bottom: the header keeps that room inside itself,
  /// so the taps land.
  static const double chipHitOverflow = 5;

  @override
  Widget build(BuildContext context) {
    final LocalDay day = context.select((TodayCubit cubit) => cubit.state.day);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        OsdSpace.textInset,
        OsdSpace.s14,
        OsdSpace.textInset,
        chipHitOverflow,
      ),
      child: OsdHitSlop(
        slop: const EdgeInsets.only(bottom: chipHitOverflow),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: AnimatedSwitcher(
                duration: OsdMotion.d(context, TodayMotion.dayChange),
                switchInCurve: TodayMotion.dayChangeCurve,
                switchOutCurve: TodayMotion.dayChangeCurve,
                layoutBuilder: _startAligned,
                child: _DayTitle(key: ValueKey<LocalDay>(day), day: day),
              ),
            ),
            const SizedBox(width: OsdSpace.s12),
            const TodayProfileChip(),
          ],
        ),
      ),
    );
  }

  static Widget _startAligned(Widget? current, List<Widget> previous) => Stack(
    alignment: AlignmentDirectional.bottomStart,
    children: <Widget>[...previous, ?current],
  );
}

/// The weekday over the date of [day], formatted once per day and
/// language.
class _DayTitle extends StatefulWidget {
  const _DayTitle({super.key, required this.day});

  final LocalDay day;

  @override
  State<_DayTitle> createState() => _DayTitleState();
}

class _DayTitleState extends State<_DayTitle> {
  String? _language;
  late String _weekday;
  late String _date;
  late String _spoken;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String language = Localizations.localeOf(context).languageCode;
    if (language != _language) {
      _language = language;
      _format();
    }
  }

  @override
  void didUpdateWidget(_DayTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day) _format();
  }

  void _format() {
    final String language = _language!;
    // Only the date fields matter; UTC keeps a DST change out of it.
    final DateTime date = DateTime.utc(
      widget.day.year,
      widget.day.month,
      widget.day.day,
    );
    final LocaleFormats formats = LocaleFormats.forLocale(language);
    _weekday = formats.date('EEEE').format(date).toUpperCase();
    _date = DisplayText.safe(formats.date('MMMMd').format(date));
    _spoken = formats.date('MMMMEEEEd').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    return Semantics(
      header: true,
      label: _spoken,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: OsdSpace.s2,
        children: <Widget>[
          // Like the date under it, a weekday too wide for the column
          // ("FREITAG" at a large text size) scales down rather than lose
          // its end.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              _weekday,
              key: TodayHeader.weekdayKey,
              maxLines: 1,
              softWrap: false,
              style: typography.overline.copyWith(color: colors.mu),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              _date,
              key: TodayHeader.dateKey,
              maxLines: 1,
              softWrap: false,
              textScaler: OsdTextScale.scalerFor(
                context,
                OsdTextScaleRole.display,
              ),
              style: typography.title30.copyWith(color: colors.tx),
            ),
          ),
        ],
      ),
    );
  }
}
