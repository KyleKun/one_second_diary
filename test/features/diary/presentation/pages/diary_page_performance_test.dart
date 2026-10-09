// Performance guards of the Diary's calendar, over a 5 000-clip diary:
// - the first frame is complete, straight from memory: the count, every
//   recorded day's picture and the selected day's poster;
// - a tap rebuilds two day cells (the old and the new selection) and
//   neither the grid nor the month header, and shows the day's poster in
//   that frame, without asking for a thumbnail;
// - the keyboard (the subtitle sheet over the Diary) rebuilds no part of
//   the calendar.

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' as widgets show debugOnRebuildDirtyWidget;
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/thumbnail_tier.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_calendar.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_day_cell.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_day_slot.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_month_bar.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/shared/widgets/calendar/calendar_month_grid.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';
import 'package:one_second_diary/shared/widgets/progress/animated_count.dart';

import '../../../../shared/harness/settle.dart';
import '../../support/diary_fixtures.dart';
import '../../support/diary_page_harness.dart';

const int _clips = 5000;

void main() {
  late DiaryPageHarness diary;

  setUp(() {
    diary = DiaryPageHarness()
      ..publish(<LocalDay, int>{
        // One clip a day for 5 000 days up to yesterday, and none today.
        for (int i = 1; i <= _clips; i++) sep(28).addDays(-i): 1,
      })
      ..cacheThumbnails(ThumbnailTier.cell)
      ..cacheThumbnails(ThumbnailTier.poster);
  });

  String poster(LocalDay day) => DiaryPageHarness.thumbnailPathOf(
    diaryClip(ProfileKey.defaultProfile, day),
    ThumbnailTier.poster,
  );

  List<String> shown(WidgetTester tester, ClipThumbnailSlot slot) => <String>[
    for (final ClipThumbnail thumbnail in tester.widgetList<ClipThumbnail>(
      find.byType(ClipThumbnail),
    ))
      if (thumbnail.slot == slot && thumbnail.image is FileImage)
        (thumbnail.image! as FileImage).file.path,
  ];

  /// Counts the builds of each widget type while [action] runs.
  Future<Map<Type, int>> buildsDuring(Future<void> Function() action) async {
    final Map<Type, int> builds = <Type, int>{};
    widgets.debugOnRebuildDirtyWidget = (Element element, bool builtOnce) {
      final Type type = element.widget.runtimeType;
      builds[type] = (builds[type] ?? 0) + 1;
    };
    try {
      await action();
    } finally {
      widgets.debugOnRebuildDirtyWidget = null;
    }
    return builds;
  }

  testWidgets('the first frame over $_clips clips is complete, from memory', (
    tester,
  ) async {
    await diary.pump(tester, disableAnimations: true);

    expect(
      tester.widget<Text>(find.byKey(AnimatedCount.valueKey)).data,
      '27 of 28 days',
    );
    expect(shown(tester, ClipThumbnailSlot.calendarCell), hasLength(27));
    expect(shown(tester, ClipThumbnailSlot.player), <String>[poster(sep(27))]);
    expect(diary.media.thumbnails.requests, isEmpty);
  });

  testWidgets('each day tap rebuilds two cells, never the grid or the header, '
      'and shows its poster in the same frame; the keyboard rebuilds '
      'nothing of the calendar', (tester) async {
    await diary.pump(tester);
    await settle(tester);

    for (final int day in <int>[16, 3, 11, 19, 26]) {
      final Map<Type, int> builds = await buildsDuring(() async {
        await tester.tap(find.byKey(ValueKey<LocalDay>(sep(day))));
        await tester.pump();
      });
      expect(builds[DiaryDaySlot], 2, reason: 'Sep $day: $builds');
      expect(builds[DiaryDayCell], 2, reason: 'Sep $day: $builds');
      expect(builds[CalendarMonthGrid], isNull, reason: 'Sep $day: $builds');
      expect(builds[DiaryCalendar], isNull, reason: 'Sep $day: $builds');
      expect(builds[DiaryMonthBar], isNull, reason: 'Sep $day: $builds');
      expect(
        shown(tester, ClipThumbnailSlot.player),
        contains(poster(sep(day))),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(diary.cubit.state.selected, sep(26));
    expect(diary.media.thumbnails.requests, isEmpty);

    // The subtitle sheet's keyboard.
    final Map<Type, int> builds = await buildsDuring(() async {
      tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
      await tester.pump();
    });
    addTearDown(tester.view.resetViewInsets);
    expect(builds[CalendarMonthGrid], isNull, reason: '$builds');
    expect(builds[DiaryCalendar], isNull, reason: '$builds');
    expect(builds[DiaryDayCell], isNull, reason: '$builds');
    expect(builds[DiaryMonthBar], isNull, reason: '$builds');
  });
}
