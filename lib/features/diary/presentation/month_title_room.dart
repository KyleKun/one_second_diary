import 'package:flutter/widgets.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/make_movie_chip.dart';
import 'package:one_second_diary/shared/widgets/buttons/tinted_pill_button.dart';
import 'package:one_second_diary/shared/widgets/calendar/diary_month_header.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Whether a Diary month header's Make movie chip goes icon-only so the
/// month title keeps its line.
///
/// `TintedPillButton` collapses on its own only in a slot narrower than 110
/// or from text scale 1.6, but the header's row gives the chip its natural
/// width and the title takes the squeeze. So the header measures the title
/// and the chip's label ([TintedPillButton.labelledWidth]), at the phone's
/// text scale, and collapses the chip when the two don't fit side by side.
abstract final class MonthTitleRoom {
  /// A Memories header around its title: padding 4 + 4 and one gap of 6.
  static const double _feedChrome = 4 + 4 + 6;

  /// Whether a header [width] wide (a Memories header when [feed]) must show
  /// the chip icon-only for [title] to fit.
  ///
  /// The calendar header ([DiaryMonthHeader.titleWidth]) also collapses it
  /// when the labelled chip leaves the title column under 110 px, or
  /// narrower than the month's [count] ("25 of 28 days").
  static bool chipIconOnly(
    BuildContext context, {
    required String title,
    required double width,
    String? count,
    bool feed = false,
  }) {
    final OsdTypography typography = context.typography;
    final double chip = TintedPillButton.labelledWidth(
      context,
      MakeMovieChip.label,
    );
    if (feed) {
      return _widthOf(context, title, typography.monthTitle) >
          width - _feedChrome - chip;
    }
    final double room = DiaryMonthHeader.titleWidth(
      width: width,
      actionWidth: chip,
    );
    return room < TintedPillButton.iconOnlyBelowWidth ||
        _widthOf(context, title, typography.monthTitle) > room ||
        (count != null &&
            _widthOf(context, count, typography.caption13) > room);
  }

  static double _widthOf(BuildContext context, String text, TextStyle style) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final double width = painter.maxIntrinsicWidth;
    painter.dispose();
    return width;
  }
}
