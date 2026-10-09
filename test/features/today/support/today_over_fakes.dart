import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_cubit.dart';

import '../../../shared/fakes/fake_clip_repository.dart';
import '../../../shared/fakes/fake_profiles_repository.dart';
import '../../../support/support.dart';
import 'today_diaries.dart';

/// A `TodayCubit` over fakes, and the fakes a test drives: the
/// [profiles] ([todayProfiles] by default: Default, active, and Travel),
/// a [FakeClipRepository] the test publishes diaries to, a [FakeClock] and
/// the midnight ticker over it.
///
/// Make it inside `fakeAsync`, so its timers (midnight, the part of the
/// day) run in fake time: move the clock with [advance], and end with
/// [dispose], which checks that no timer is left running.
final class TodayOverFakes {
  /// Today at [now]. [before] scripts the diaries before the cubit is
  /// built.
  TodayOverFakes({
    required DateTime now,
    required PrefsStore prefs,
    List<Profile>? profiles,
    void Function(FakeClipRepository clips)? before,
  }) : clock = FakeClock(now),
       clips = FakeClipRepository(),
       profilesRepository = FakeProfilesRepository(
         profiles: profiles ?? todayProfiles(),
       ) {
    before?.call(clips);
    midnight = MidnightTicker(clock: clock);
    settings = SettingsRepository(prefs: prefs);
    cubit = TodayCubit(
      clips: clips,
      profiles: profilesRepository,
      midnight: midnight,
      clock: clock,
      settings: settings,
      logger: memoryLogger(log),
    );
  }

  final FakeClock clock;
  final FakeClipRepository clips;
  final FakeProfilesRepository profilesRepository;
  final MemoryLogSink log = MemoryLogSink();
  late final MidnightTicker midnight;
  late final SettingsRepository settings;
  late final TodayCubit cubit;

  /// Moves the wall clock and fake time on by [duration], one minute at a
  /// time, as a phone that stays awake would.
  void advance(FakeAsync async, Duration duration) {
    const Duration step = Duration(minutes: 1);
    Duration left = duration;
    while (left > Duration.zero) {
      final Duration next = left < step ? left : step;
      clock.advance(next);
      async.elapse(next);
      left -= next;
    }
  }

  /// Files a new clip under [day] in [profile], as a save does (the day
  /// is the one the clip was recorded or picked for, never the moment of
  /// the save), and tells the index's watchers. Returns the clip.
  ClipRef saveClipOn(LocalDay day, {ProfileKey profile = todayDefault}) {
    final ClipIndex index =
        clips.snapshotOf(profile) ?? ClipIndex.empty(profile);
    final ClipRef clip = todayClip(
      profile,
      day,
      ordinal: index.nextOrdinal(day),
    );
    clips.publish(index.withClip(IndexedClip(ref: clip, stamp: todayStamp)));
    return clip;
  }

  /// Closes everything; the cubit must leave no timer running.
  void dispose(FakeAsync async) {
    unawaited(cubit.close());
    unawaited(clips.close());
    unawaited(profilesRepository.close());
    async.flushMicrotasks();
    expect(async.pendingTimers, isEmpty, reason: 'timers left running');
  }
}
