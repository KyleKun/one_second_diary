// TodayCubit: today's clips of the active profile (several per day), the
// day with its midnight rollover, the part of the day the character greets
// by, the profile's recorded days, and the active profile it follows (a
// switch made anywhere, through `ProfilesRepository`).

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/today/domain/part_of_day.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_state.dart';

import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../support/support.dart';
import '../../support/today_diaries.dart';
import '../../support/today_over_fakes.dart';

void main() {
  late PrefsStore prefs;

  setUp(() async {
    prefs = await openLegacyPrefs(legacyPrefs());
  });

  /// Runs [body] in fake time from [now], with a TodayCubit over fakes:
  /// Default (landscape, active) and Travel (portrait). [before] scripts
  /// the diaries before the cubit is built.
  void withToday(
    DateTime now,
    void Function(FakeAsync async, TodayOverFakes today) body, {
    void Function(FakeClipRepository clips)? before,
  }) {
    fakeAsync((FakeAsync async) {
      final TodayOverFakes today = TodayOverFakes(
        now: now,
        prefs: prefs,
        before: before,
      );
      body(async, today);
      today.dispose(async);
    });
  }

  group("today's clips", () {
    test('are the clips of today in the active profile, in recording order '
        '(D1), as soon as the index has them; other days and profiles do not '
        'count; an empty day is ready with no clip in view', () {
      withToday(DateTime(2026, 9, 28, 9), (async, today) {
        expect(today.cubit.state.status, TodayStatus.loading);
        expect(today.cubit.state.day, LocalDay(2026, 9, 28));

        today.clips.publish(
          todayDiary(_default, <LocalDay, int>{LocalDay(2026, 9, 27): 1}),
        );
        async.flushMicrotasks();
        expect(today.cubit.state.status, TodayStatus.ready);
        expect(today.cubit.state.clips, isEmpty);
        expect(today.cubit.state.visibleClip, isNull);

        today.clips
          ..publish(
            todayDiary(_default, <LocalDay, int>{
              LocalDay(2026, 9, 27): 1,
              LocalDay(2026, 9, 28): 3,
            }),
          )
          ..publish(
            todayDiary(_travel, <LocalDay, int>{LocalDay(2026, 9, 28): 1}),
          );
        async.flushMicrotasks();

        expect(today.cubit.state.clips, <ClipRef>[
          todayClip(_default, LocalDay(2026, 9, 28)),
          todayClip(_default, LocalDay(2026, 9, 28), ordinal: 2),
          todayClip(_default, LocalDay(2026, 9, 28), ordinal: 3),
        ]);
      });
    });

    test('a diary already read shows at once, never loading', () {
      withToday(
        DateTime(2026, 9, 28, 9),
        (async, today) {
          expect(today.cubit.state.status, TodayStatus.ready);
          expect(today.cubit.state.clips, <ClipRef>[
            todayClip(_default, LocalDay(2026, 9, 28)),
          ]);
        },
        before: (FakeClipRepository clips) => clips.publish(
          todayDiary(_default, <LocalDay, int>{LocalDay(2026, 9, 28): 1}),
        ),
      );
    });

    test('a diary that cannot be read is unavailable, not loading forever, '
        'and logged', () {
      withToday(DateTime(2026, 9, 28, 9), (async, today) {
        today.clips.fail(
          _default,
          const StorageException('The videos folder is gone'),
        );
        async.flushMicrotasks();

        expect(today.cubit.state.status, TodayStatus.unavailable);
        expect(today.cubit.state.clips, isEmpty);
        expect(
          today.log.lines,
          contains(contains('The videos folder is gone')),
        );

        // A later scan that works shows the day.
        today.clips.publish(
          todayDiary(_default, <LocalDay, int>{LocalDay(2026, 9, 28): 1}),
        );
        async.flushMicrotasks();
        expect(today.cubit.state.status, TodayStatus.ready);
      });
    });
  });

  // Edit acts on the clip in view; Add another appends a clip of the day,
  // which comes into view.
  group('the clip in view (T3, T4: Edit acts on it)', () {
    test('is the latest clip of the day; showClip brings another into view; '
        'a clip added to the day comes into view (T4.7)', () {
      withToday(
        DateTime(2026, 9, 28, 9),
        before: (FakeClipRepository clips) => clips.publish(
          todayDiary(_default, <LocalDay, int>{LocalDay(2026, 9, 28): 3}),
        ),
        (async, today) {
          expect(
            today.cubit.state.visibleClip,
            todayClip(_default, LocalDay(2026, 9, 28), ordinal: 3),
          );

          today.cubit.showClip(todayClip(_default, LocalDay(2026, 9, 28)));
          expect(
            today.cubit.state.visibleClip,
            todayClip(_default, LocalDay(2026, 9, 28)),
          );

          today.clips.publish(
            todayDiary(_default, <LocalDay, int>{LocalDay(2026, 9, 28): 4}),
          );
          async.flushMicrotasks();
          expect(
            today.cubit.state.visibleClip,
            todayClip(_default, LocalDay(2026, 9, 28), ordinal: 4),
          );
        },
      );
    });

    test('a clip in view that goes away (Undo) leaves the latest in view; '
        'one that stays, stays', () {
      withToday(
        DateTime(2026, 9, 28, 9),
        before: (FakeClipRepository clips) => clips.publish(
          todayDiary(_default, <LocalDay, int>{LocalDay(2026, 9, 28): 3}),
        ),
        (async, today) {
          today.cubit.showClip(todayClip(_default, LocalDay(2026, 9, 28)));
          today.clips.publish(
            todayDiary(_default, <LocalDay, int>{LocalDay(2026, 9, 28): 2}),
          );
          async.flushMicrotasks();

          expect(
            today.cubit.state.visibleClip,
            todayClip(_default, LocalDay(2026, 9, 28)),
          );

          today.cubit.showClip(
            todayClip(_default, LocalDay(2026, 9, 28), ordinal: 2),
          );
          today.clips.publish(
            todayDiary(_default, <LocalDay, int>{LocalDay(2026, 9, 28): 1}),
          );
          async.flushMicrotasks();

          expect(
            today.cubit.state.visibleClip,
            todayClip(_default, LocalDay(2026, 9, 28)),
          );
        },
      );
    });
  });

  group('the day', () {
    test('rolls over at local midnight: the new day waits for its clip, or '
        'shows the clips it already has (today.md A4.10)', () {
      withToday(DateTime(2026, 9, 28, 23, 59, 59), (async, today) {
        today.clips.publish(
          todayDiary(_default, <LocalDay, int>{LocalDay(2026, 9, 28): 1}),
        );
        async.flushMicrotasks();
        expect(today.cubit.state.clips, hasLength(1));

        today.advance(async, const Duration(seconds: 2));

        expect(today.cubit.state.day, LocalDay(2026, 9, 29));
        expect(today.cubit.state.clips, isEmpty);
        expect(today.cubit.state.status, TodayStatus.ready);
      });

      withToday(DateTime(2026, 9, 28, 23, 59), (async, today) {
        today.clips.publish(
          todayDiary(_default, <LocalDay, int>{LocalDay(2026, 9, 29): 2}),
        );
        async.flushMicrotasks();

        today.advance(async, const Duration(minutes: 1));

        expect(today.cubit.state.clips, <ClipRef>[
          todayClip(_default, LocalDay(2026, 9, 29)),
          todayClip(_default, LocalDay(2026, 9, 29), ordinal: 2),
        ]);

        // And on, one day per midnight.
        today.advance(async, const Duration(hours: 48));
        expect(today.cubit.state.day, LocalDay(2026, 10, 1));
      });
    });
  });

  // Today is derived from the index: only a clip filed under today's local
  // date counts.
  group('only a clip of today makes the day done (CL-36)', () {
    test('a clip recorded just before midnight and saved just after is '
        'filed under its day: the new day still waits for its clip', () {
      withToday(DateTime(2026, 9, 28, 23, 59, 50), (async, today) {
        // Record is tapped for the day Today shows.
        final LocalDay recordedFor = today.cubit.state.day;

        today.advance(async, const Duration(seconds: 30));
        final ClipRef saved = today.saveClipOn(recordedFor);
        async.flushMicrotasks();

        expect(saved.day, LocalDay(2026, 9, 28));
        expect(today.cubit.state.day, LocalDay(2026, 9, 29));
        expect(today.cubit.state.clips, isEmpty);
        expect(today.cubit.state.clips, isEmpty);
      });
    });

    test('a clip of yesterday 23:59 does not make today done at 00:01, '
        "though it is within 24 h; a clip of today's date does", () {
      withToday(
        DateTime(2026, 9, 28, 0, 1),
        (async, today) {
          expect(today.cubit.state.clips, isEmpty);
          expect(today.cubit.state.clips, isEmpty);

          today.saveClipOn(LocalDay(2026, 9, 28));
          async.flushMicrotasks();

          expect(today.cubit.state.clips, hasLength(1));
        },
        before: (FakeClipRepository clips) => clips.publish(
          todayDiary(_default, <LocalDay, int>{
            LocalDay.fromDateTime(DateTime(2026, 9, 27, 23, 59)): 1,
          }),
        ),
      );
    });

    test('a clip of a 23-hour day (a spring-forward) never makes the next '
        'day done at 00:30', () {
      // The local zone's own 23-hour day when it has one; any day works
      // elsewhere, since days are calendar dates, never 24-hour windows.
      final LocalDay short =
          _firstSpringForwardDay(2026) ?? LocalDay(2026, 3, 8);
      final DateTime after = DateTime(
        short.year,
        short.month,
        short.day + 1,
        0,
        30,
      );
      withToday(
        after,
        (async, today) {
          expect(today.cubit.state.day, isNot(short));
          expect(today.cubit.state.clips, isEmpty);
          expect(today.cubit.state.clips, isEmpty);
        },
        before: (FakeClipRepository clips) =>
            clips.publish(todayDiary(_default, <LocalDay, int>{short: 1})),
      );
    });
  });

  group('the part of the day', () {
    test('changes at 12:00, 18:00 and 22:00 while Today stays open, and at '
        '05:00 on the next day', () {
      withToday(DateTime(2026, 9, 28, 11, 59), (async, today) {
        expect(today.cubit.state.partOfDay, PartOfDay.morning);

        today.advance(async, const Duration(minutes: 1));
        expect(today.cubit.state.partOfDay, PartOfDay.afternoon);

        today.advance(async, const Duration(hours: 6));
        expect(today.cubit.state.partOfDay, PartOfDay.evening);

        today.advance(async, const Duration(hours: 4));
        expect(today.cubit.state.partOfDay, PartOfDay.lateNight);

        today.advance(async, const Duration(hours: 7));
        expect(today.cubit.state.day, LocalDay(2026, 9, 29));
        expect(today.cubit.state.partOfDay, PartOfDay.morning);
      });
    });

    test('refreshTime() catches up after the phone slept: a suspended '
        'timer fires late, the wall clock does not', () {
      withToday(DateTime(2026, 9, 28, 11), (async, today) {
        // Suspended for 32 hours: the wall clock moved, the timers did not.
        today.clock.advance(const Duration(hours: 32));

        today.cubit.refreshTime();

        expect(today.cubit.state.day, LocalDay(2026, 9, 29));
        expect(today.cubit.state.partOfDay, PartOfDay.evening);
      });
    });
  });

  test("the empty frame previews the date stamp in the user's V3 format", () {
    withToday(DateTime(2026, 9, 28, 9), (async, today) {
      expect(today.cubit.state.stampFormat, StampFormat.numeric);

      unawaited(
        today.settings.stampStyle.set(
          const StampStyle(
            format: StampFormat.written,
            rgb: 0xFFFFFF,
            outline: true,
          ),
        ),
      );
      async.flushMicrotasks();

      expect(today.cubit.state.stampFormat, StampFormat.written);
    });
  });

  group('recorded days', () {
    test('count the days with a clip and name the latest: none while the '
        'diary loads or is empty, then as published', () {
      withToday(DateTime(2026, 9, 28, 9), (async, today) {
        expect(today.cubit.state.recordedDays, 0);
        expect(today.cubit.state.lastRecordedDay, isNull);

        today.clips.publish(todayDiary(_default, <LocalDay, int>{}));
        async.flushMicrotasks();
        expect(today.cubit.state.recordedDays, 0);
        expect(today.cubit.state.lastRecordedDay, isNull);

        today.clips.publish(
          todayDiary(_default, <LocalDay, int>{
            LocalDay(2026, 9, 20): 2,
            LocalDay(2026, 9, 27): 1,
          }),
        );
        async.flushMicrotasks();
        expect(today.cubit.state.recordedDays, 2);
        expect(today.cubit.state.lastRecordedDay, LocalDay(2026, 9, 27));

        today.saveClipOn(LocalDay(2026, 9, 28));
        async.flushMicrotasks();
        expect(today.cubit.state.recordedDays, 3);
        expect(today.cubit.state.lastRecordedDay, LocalDay(2026, 9, 28));
      });
    });

    test('reset on a switch to a profile whose diary is not read yet', () {
      withToday(
        DateTime(2026, 9, 28, 9),
        before: (FakeClipRepository clips) => clips.publish(
          todayDiary(_default, <LocalDay, int>{LocalDay(2026, 9, 27): 1}),
        ),
        (async, today) {
          expect(today.cubit.state.recordedDays, 1);

          unawaited(today.profilesRepository.activate(_travel));
          async.flushMicrotasks();

          expect(today.cubit.state.recordedDays, 0);
          expect(today.cubit.state.lastRecordedDay, isNull);
        },
      );
    });
  });

  group('profiles', () {
    void publishBoth(FakeClipRepository clips) => clips
      ..publish(todayDiary(_default, <LocalDay, int>{LocalDay(2026, 9, 28): 1}))
      ..publish(todayDiary(_travel, <LocalDay, int>{LocalDay(2026, 9, 28): 2}));

    test('a switch made anywhere (T6, S4) shows the new profile, its shape '
        'and its clips', () {
      withToday(DateTime(2026, 9, 28, 9), before: publishBoth, (async, today) {
        expect(today.cubit.state.profile, today.profilesRepository.active);
        unawaited(today.profilesRepository.activate(_travel));
        async.flushMicrotasks();

        expect(today.cubit.state.profile.key, _travel);
        expect(
          today.cubit.state.profile.orientation,
          VideoOrientation.portrait,
        );
        expect(today.cubit.state.clips, <ClipRef>[
          todayClip(_travel, LocalDay(2026, 9, 28)),
          todayClip(_travel, LocalDay(2026, 9, 28), ordinal: 2),
        ]);

        // The old profile's diary does not count.
        today.clips.publish(
          todayDiary(_default, <LocalDay, int>{LocalDay(2026, 9, 28): 3}),
        );
        async.flushMicrotasks();
        expect(today.cubit.state.clips, hasLength(2));
      });
    });

    test('a profile whose diary is not read yet is loading, never the old '
        "profile's clips", () {
      withToday(
        DateTime(2026, 9, 28, 9),
        before: (FakeClipRepository clips) => clips.publish(
          todayDiary(_default, <LocalDay, int>{LocalDay(2026, 9, 28): 1}),
        ),
        (async, today) {
          unawaited(today.profilesRepository.activate(_travel));
          async.flushMicrotasks();

          expect(today.cubit.state.status, TodayStatus.loading);
          expect(today.cubit.state.clips, isEmpty);
        },
      );
    });
  });
}

const ProfileKey _default = todayDefault;
const ProfileKey _travel = todayTravel;

/// The first day of [year] that lasts 23 hours in the local zone (a
/// one-hour spring-forward), or null when the zone has none.
LocalDay? _firstSpringForwardDay(int year) {
  for (
    DateTime day = DateTime(year);
    day.year == year;
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    final DateTime next = DateTime(day.year, day.month, day.day + 1);
    if (next.difference(day) == const Duration(hours: 23)) {
      return LocalDay.fromDateTime(day);
    }
  }
  return null;
}
