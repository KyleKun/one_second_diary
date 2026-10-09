import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_day.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_mini_player.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_dashed_placeholder.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';

/// The block under the calendar grid: what the selected day holds.
///
/// - A recorded day plays in the [DiaryMiniPlayer], its poster from the
///   thumbnail cache in the same frame as the tap.
/// - A missed day (or one before the first clip) shows the dashed "No
///   video on Friday 25" panel, an hourglass turning while a clip is added
///   to it; today not recorded yet says "Nothing yet today" with Record,
///   which opens the Today tab; a past month without clips, where nothing
///   is selected, "No videos this month".
/// - While the diary is read, a C2 block; a diary that could not be read
///   says so ("Can't open your diary") with Try again.
///
/// A change of day crossfades, the new block scaling in; a plain crossfade
/// under reduced motion. It rebuilds only when the selected day's own
/// state changes.
class DiaryDayPanel extends StatelessWidget {
  const DiaryDayPanel({super.key, this.mediaHeight = height});

  /// The block's height.
  static const double height = 196;

  /// How tall this block is: [height], or 16:9 of a tablet's pane.
  final double mediaHeight;

  /// "Record" on today not recorded yet: to the Today tab.
  static const Key recordKey = Key('diaryDayPanel.record');

  /// "Try again" on a diary that could not be read.
  static const Key tryAgainKey = Key('diaryDayPanel.tryAgain');

  static const double _fromScale = .98;

  @override
  Widget build(BuildContext context) {
    final (DiaryDay? day, bool adding, bool unreadable) = context.select(
      (DiaryCubit cubit) => (
        switch (cubit.state.selected) {
          final LocalDay selected => cubit.state.dayOf(selected),
          null => null,
        },
        cubit.state.adding,
        cubit.state.status == DiaryStatus.failed,
      ),
    );
    final bool reduced = OsdMotion.reduced(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: mediaHeight),
      child: AnimatedSwitcher(
        duration: OsdMotion.d(context, OsdMotion.standard),
        switchInCurve: OsdMotion.curve(context, OsdMotion.standardCurve),
        switchOutCurve: OsdMotion.curve(context, OsdMotion.fastCurve),
        transitionBuilder: (Widget child, Animation<double> animation) =>
            FadeTransition(
              opacity: animation,
              child: reduced
                  ? child
                  : ScaleTransition(
                      scale: Tween<double>(
                        begin: _fromScale,
                        end: 1,
                      ).animate(animation),
                      child: child,
                    ),
            ),
        child: switch (day) {
          _ when unreadable => OsdDashedPlaceholder(
            key: const ValueKey<String>('unreadable'),
            icon: OsdIcons.error,
            title: Strings.storageUnavailableTitle,
            hint: Strings.diaryUnreadableHint,
            action: SizedBox(
              width: .infinity,
              child: NeutralButton(
                key: tryAgainKey,
                label: Strings.commonTryAgain,
                size: OsdButtonSize.compact,
                onPressed: () =>
                    unawaited(context.read<DiaryCubit>().readAgain()),
              ),
            ),
          ),
          null => OsdDashedPlaceholder(
            key: const ValueKey<String>('monthEmpty'),
            icon: OsdIcons.videoLibrary,
            title: Strings.diaryMonthEmptyTitle,
            hint: Strings.diaryMonthEmptyHint,
          ),
          DiaryDay(kind: DiaryDayKind.recorded, :final LocalDay day) =>
            DiaryMiniPlayer(
              key: ValueKey<(String, LocalDay)>(('player', day)),
              day: day,
              mediaHeight: mediaHeight,
            ),
          DiaryDay(kind: DiaryDayKind.unknown || DiaryDayKind.future) =>
            SizedBox(
              key: const ValueKey<String>('unknown'),
              height: mediaHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.colors.c2,
                  borderRadius: BorderRadius.circular(OsdRadius.r4),
                ),
              ),
            ),
          DiaryDay(isToday: true) => OsdDashedPlaceholder(
            key: const ValueKey<String>('today'),
            icon: OsdIcons.radioButtonChecked,
            title: Strings.diaryTodayEmptyTitle,
            hint: Strings.diaryTodayEmptyHint,
            action: SizedBox(
              width: .infinity,
              child: PrimaryButton(
                key: recordKey,
                label: Strings.record,
                icon: OsdIcons.videocam,
                size: OsdButtonSize.compact,
                haptic: OsdHaptic.light,
                onPressed: () => AppRoute.today.go(context),
              ),
            ),
          ),
          DiaryDay(:final LocalDay day) => OsdDashedPlaceholder(
            key: ValueKey<(String, LocalDay)>(('missed', day)),
            icon: adding ? OsdIcons.hourglassTop : OsdIcons.videocamOff,
            busy: adding,
            title: Strings.diaryNoVideoOn(
              day: Strings.diaryDayCaption(
                weekday: DiaryFormats.of(context).weekday(day),
                day: DiaryFormats.of(context).dayOfMonth(day),
              ),
            ),
            hint: Strings.diaryNoVideoHint,
          ),
        },
      ),
    );
  }
}
