// The Journey tab's statistics, derived from the active profile's clip
// index and the clip metadata, recomputed on every index change, at
// midnight and once the duration backfill ends.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/journey_stats.dart';
import 'package:one_second_diary/features/clips/domain/month_progress.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/journey_cubit.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/journey_state.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../../shared/fakes/clip_index_fixture.dart';
import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../shared/fakes/fake_profiles_repository.dart';
import '../../../../support/support.dart';
import '../../../movies/support/fake_movie_repository.dart';
import '../../support/journey_fakes.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

void main() {
  late FakeClock clock;
  late FakeProfilesRepository profiles;
  late FakeClipRepository clips;
  late MapClipMetadataCache metadata;
  late ScriptedBackfill backfill;
  late FakeSavedPlaces savedPlaces;
  late FakePlaceCoordinates coordinates;
  late FakeMovieRepository movies;
  late MemoryLogSink log;
  late MidnightTicker midnight;

  setUp(() {
    clock = FakeClock(DateTime(2026, 9, 28, 10));
    profiles = FakeProfilesRepository();
    clips = FakeClipRepository();
    metadata = MapClipMetadataCache();
    backfill = ScriptedBackfill();
    savedPlaces = FakeSavedPlaces();
    coordinates = FakePlaceCoordinates();
    movies = FakeMovieRepository();
    log = MemoryLogSink();
    midnight = MidnightTicker(clock: clock);
  });

  tearDown(() => clips.close());

  JourneyCubit build() => JourneyCubit(
    profiles: profiles,
    clips: clips,
    metadata: metadata,
    backfill: backfill,
    savedPlaces: savedPlaces,
    coordinates: coordinates,
    movies: movies,
    clock: clock,
    midnight: midnight,
    logger: memoryLogger(log),
  );

  test('the first state already holds the stats of the index in memory', () {
    clips.publish(
      clipIndexOf(_default, <LocalDay>[
        for (int day = 24; day <= 28; day++) LocalDay(2026, 9, day),
      ]),
    );

    final JourneyCubit cubit = build();
    addTearDown(cubit.close);

    expect(cubit.state.status, JourneyStatus.ready);
    final JourneyStats stats = cubit.state.stats!;
    expect(stats.daysRecorded, 5);
    expect(stats.currentStreak, 5);
    expect(stats.thisMonth, const MonthProgress(recorded: 5, elapsed: 28));
    expect(cubit.state.clipCount, 5);
  });

  test('loads while the diary is read; a diary that could not be read says '
      'so instead of loading forever; each later snapshot shows its '
      'stats', () async {
    final JourneyCubit cubit = build();
    addTearDown(cubit.close);
    expect(cubit.state, const JourneyState.loading());

    clips.fail(_default, const FileSystemException('DCIM is gone'));
    await pumpEventQueue();
    expect(cubit.state.status, JourneyStatus.failed);

    clips.publish(clipIndexOf(_default, <LocalDay>[LocalDay(2026, 9, 27)]));
    await pumpEventQueue();
    expect(cubit.state.status, JourneyStatus.ready);
    expect(cubit.state.stats!.daysRecorded, 1);

    clips.publish(
      clipIndexOf(_default, <LocalDay>[
        LocalDay(2026, 9, 27),
        LocalDay(2026, 9, 28),
      ]),
    );
    await pumpEventQueue();
    expect(cubit.state.stats!.daysRecorded, 2);
    expect(cubit.state.clipCount, 2);
  });

  // The stats follow the profile switched from Today's chip.
  test("a profile switch shows that profile's stats, and only its "
      'snapshots from then on', () async {
    const ProfileKey kids = ProfileKey('Kids');
    profiles.addProfile(testProfile(key: kids));
    clips
      ..publish(clipIndexOf(_default, <LocalDay>[LocalDay(2026, 9, 28)]))
      ..publish(
        clipIndexOf(kids, <LocalDay>[
          LocalDay(2026, 9, 1),
          LocalDay(2026, 9, 2),
          LocalDay(2026, 9, 3),
        ]),
      );
    final JourneyCubit cubit = build();
    addTearDown(cubit.close);

    await profiles.activate(kids);
    await pumpEventQueue();
    expect(cubit.state.stats!.daysRecorded, 3);

    clips.publish(clipIndexOf(_default, <LocalDay>[]));
    await pumpEventQueue();
    expect(cubit.state.stats!.daysRecorded, 3, reason: 'Default is hidden');
  });

  test('at midnight the streak and "This month" move to the new day', () async {
    clips.publish(
      clipIndexOf(_default, <LocalDay>[
        LocalDay(2026, 9, 29),
        LocalDay(2026, 9, 30),
      ]),
    );
    clock.setNow(DateTime(2026, 9, 30, 23, 59));
    final JourneyCubit cubit = build();
    addTearDown(cubit.close);
    await pumpEventQueue();
    expect(cubit.state.stats!.thisMonth.recorded, 2);

    clock.setNow(DateTime(2026, 10, 2, 0, 1));
    midnight.check();
    await pumpEventQueue();

    expect(cubit.state.stats!.currentStreak, 0);
    expect(
      cubit.state.stats!.thisMonth,
      const MonthProgress(recorded: 0, elapsed: 2),
    );
  });

  // An estimate ("About …") until the backfill has probed every clip.
  test('"Your life so far" is an estimate while the backfill runs, updated '
      'as it goes, then the exact sum once it is done', () async {
    final ClipIndex index = clipIndexOf(_default, <LocalDay>[
      LocalDay(2026, 9, 26),
      LocalDay(2026, 9, 27),
      LocalDay(2026, 9, 28),
    ]);
    clips.publish(index);
    metadata.known['2026-09-28.mp4'] = const ClipMeta(durationMs: 2000);
    backfill.enqueue(index);
    final JourneyCubit cubit = build();
    addTearDown(cubit.close);
    await pumpEventQueue();
    expect(cubit.state.stats!.lifeSoFar, const Duration(seconds: 6));
    expect(cubit.state.stats!.lifeSoFarIsEstimate, isTrue);

    metadata.known['2026-09-27.mp4'] = const ClipMeta(durationMs: 4000);
    backfill.tellProgress();
    await pumpEventQueue();
    expect(cubit.state.stats!.lifeSoFar, const Duration(seconds: 9));
    expect(cubit.state.stats!.lifeSoFarIsEstimate, isTrue);

    metadata.known['2026-09-26.mp4'] = const ClipMeta(durationMs: 5000);
    backfill.finish();
    await pumpEventQueue();
    expect(cubit.state.stats!.lifeSoFar, const Duration(seconds: 11));
    expect(cubit.state.stats!.lifeSoFarIsEstimate, isFalse);
  });

  // One list of movies for every profile; the Journey counts them all.
  test('the movies are every movie in the folder, read again when asked; '
      'a folder that cannot be read keeps the last list and is '
      'logged', () async {
    clips.publish(clipIndexOf(_default, <LocalDay>[LocalDay(2026, 9, 28)]));
    movies.movies.addAll(<MovieEntry>[testMovie(1), testMovie(2)]);
    final JourneyCubit cubit = build();
    addTearDown(cubit.close);
    expect(cubit.state.movies, isNull, reason: 'not read yet');

    await pumpEventQueue();
    expect(cubit.state.movies, hasLength(2));

    movies.movies.add(testMovie(3));
    await cubit.refreshMovies();
    expect(cubit.state.movies, hasLength(3));

    movies
      ..movies.add(testMovie(4))
      ..failNextList = true;
    await cubit.refreshMovies();
    expect(cubit.state.movies, hasLength(3));
    expect(log.lines.join('\n'), contains('[JOURNEY]'));
  });
}
