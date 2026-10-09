import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/circle_icon_button.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hit_slop.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_overflow_hit_area.dart';
import 'package:one_second_diary/shared/widgets/progress/animated_count.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The month heading of the Diary: a [title] over the month's progress
/// (formatted by [progress] from [recordedDays]), then the [action].
///
/// - **Calendar**: two month arrows follow the action. The arrows and the
///   action keep their full tap targets, which overlap the padding and each
///   other (`OsdOverflowHitArea`).
/// - **[DiaryMonthHeader.feed]**: a BG fill (it is pinned), no arrows; a line
///   fades in at the bottom once content is [scrolledUnder] it.
///
/// On a month change the title and count crossfade. With [countUp] (the
/// month's first appearance) the count counts up; later changes (a delete,
/// an import) tween from the old count.
class DiaryMonthHeader extends StatelessWidget {
  const DiaryMonthHeader({
    super.key,
    required this.title,
    required this.recordedDays,
    required this.progress,
    this.action,
    required this.onPrevious,
    required this.onNext,
    required String this.previousTooltip,
    required String this.nextTooltip,
    this.countUp = true,
  }) : _feed = false,
       scrolledUnder = false;

  const DiaryMonthHeader.feed({
    super.key,
    required this.title,
    required this.recordedDays,
    required this.progress,
    this.action,
    this.scrolledUnder = false,
    this.countUp = true,
  }) : _feed = true,
       onPrevious = null,
       onNext = null,
       previousTooltip = null,
       nextTooltip = null;

  static const Key feedKey = Key('diaryMonthHeader.feed');

  static const Key lineKey = Key('diaryMonthHeader.line');

  static const Duration _crossfade = Duration(milliseconds: 200);
  static const double _row = 38;
  static const double _gap = 6;
  static const EdgeInsetsDirectional _calendarPadding =
      EdgeInsetsDirectional.fromSTEB(20, 4, 12, 10);

  /// The width the calendar variant leaves its title and count, [width]
  /// wide with an [action] [actionWidth] wide: the padding, the two arrows
  /// and the three gaps taken off (so a caller can tell when the action
  /// should shrink).
  static double titleWidth({
    required double width,
    required double actionWidth,
  }) => width - _calendarPadding.horizontal - 2 * _row - 3 * _gap - actionWidth;

  final String title;

  /// Days of the month with at least one clip.
  final int recordedDays;

  /// Formats the progress line ("25 of 28 days").
  final String Function(int recordedDays) progress;

  final Widget? action;

  /// Null on the profile's first month.
  final VoidCallback? onPrevious;

  /// Null on the current month.
  final VoidCallback? onNext;

  final String? previousTooltip;

  final String? nextTooltip;

  /// Whether the count counts up when first shown.
  final bool countUp;

  /// Whether list content is scrolled under the pinned feed header.
  final bool scrolledUnder;

  final bool _feed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final titles = AnimatedSwitcher(
      duration: OsdMotion.d(context, _crossfade),
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: <Widget>[...previous, ?current],
      ),
      child: Column(
        key: ValueKey<String>(title),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              title,
              // One line (the caller makes room: the Diary's chip goes
              // icon-only); at large text scales the month wraps rather than
              // lose its year.
              maxLines: OsdTextScale.nameLines(context),
              overflow: TextOverflow.ellipsis,
              style: typography.monthTitle.copyWith(color: colors.tx),
            ),
          ),
          AnimatedCount(
            value: recordedDays,
            format: progress,
            duration: OsdMotion.countUpShort,
            countUpOnAppear: countUp,
            style: typography.caption13.copyWith(color: colors.mu),
          ),
        ],
      ),
    );
    final action = this.action;
    final chip = action == null ? null : OsdOverflowHitArea(child: action);

    if (_feed) {
      return ColoredBox(
        key: feedKey,
        color: colors.bg,
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 12),
              child: OsdHitSlop(
                slop: const EdgeInsets.all(7),
                child: Row(
                  spacing: 6,
                  children: <Widget>[
                    Expanded(child: titles),
                    ?chip,
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 1,
              child: AnimatedOpacity(
                opacity: scrolledUnder ? 1 : 0,
                duration: OsdMotion.d(context, OsdMotion.fast),
                child: ColoredBox(key: lineKey, color: colors.ln),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: _calendarPadding,
      child: OsdHitSlop(
        slop: const EdgeInsets.all(7),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _row),
          child: Row(
            spacing: _gap,
            children: <Widget>[
              Expanded(child: titles),
              ?chip,
              OsdOverflowHitArea(
                child: CircleIconButton(
                  icon: OsdIcons.chevronLeft,
                  tooltip: previousTooltip!,
                  onPressed: onPrevious,
                ),
              ),
              OsdOverflowHitArea(
                child: CircleIconButton(
                  icon: OsdIcons.chevronRight,
                  tooltip: nextTooltip!,
                  onPressed: onNext,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
