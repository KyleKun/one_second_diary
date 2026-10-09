// The Create movie flow's shared state. The counts come from the flow
// profile's clip index at once; the flow's profile chip changes only the
// movie's source profile, never the app's.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_event.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_state.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../../shared/fakes/clip_index_fixture.dart';
import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../shared/fakes/fake_free_space_gateway.dart';
import '../../../../shared/fakes/fake_profiles_repository.dart';
import '../../../../support/support.dart';
import '../../support/pausable_backfill.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

/// Days [first] to [last] of [month] 2026.
List<LocalDay> _daysOf(int month, int first, int last) => <LocalDay>[
  for (int day = first; day <= last; day++) LocalDay(2026, month, day),
];

void main() {
  late FakeClock clock;
  late FakeProfilesRepository profiles;
  late FakeClipRepository clips;
  late FakeFreeSpaceGateway freeSpace;

  setUp(() {
    freeSpace = FakeFreeSpaceGateway();
    clock = FakeClock(DateTime(2026, 9, 28, 10));
    profiles = FakeProfilesRepository();
    clips = FakeClipRepository();
  });

  tearDown(() => clips.close());

  CreateMovieCubit build({MoviePreset? preset}) {
    final CreateMovieCubit cubit = CreateMovieCubit(
      preset: preset,
      profiles: profiles,
      clips: clips,
      clock: clock,
      freeSpace: freeSpace,
      backfill: PausableBackfill(),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  // The default moves to the first range a movie can be made of; the
  // Journey's "Your life so far" opens on All time, whatever the default.
  test('opens on the active profile with "This month" and its clips counted '
      'from the index in memory, or the first range with enough clips (Last '
      '30 days, This year, All time); a range the flow opens with stays '
      'picked', () {
    clips.publish(
      clipIndexOf(_default, <LocalDay>[
        ..._daysOf(8, 1, 31),
        ..._daysOf(9, 1, 25),
      ]),
    );
    final CreateMovieCubit cubit = build();
    expect(cubit.state.status, CreateMovieStatus.ready);
    expect(cubit.state.profile, _default);
    expect(cubit.state.preset, MoviePreset.thisMonth);
    expect(cubit.state.presetClips, 25);
    expect(cubit.state.source, isNull, reason: 'nothing chosen yet');

    final Map<List<LocalDay>, MoviePreset> defaults =
        <List<LocalDay>, MoviePreset>{
          _daysOf(8, 30, 31): MoviePreset.last30Days,
          _daysOf(3, 1, 2): MoviePreset.thisYear,
          <LocalDay>[LocalDay(2024, 1, 1), LocalDay(2024, 1, 2)]:
              MoviePreset.allTime,
          <LocalDay>[]: MoviePreset.thisMonth, // nothing fits
        };
    for (final MapEntry<List<LocalDay>, MoviePreset>(
          key: List<LocalDay> days,
          value: MoviePreset preset,
        )
        in defaults.entries) {
      clips.publish(clipIndexOf(_default, days));
      expect(build().state.preset, preset, reason: '$days');
    }

    clips.publish(clipIndexOf(_default, _daysOf(9, 1, 28)));
    final CreateMovieCubit allTime = build(preset: MoviePreset.allTime);
    expect(allTime.state.preset, MoviePreset.allTime);
    expect(allTime.state.presetClips, 28);
    expect(allTime.state.source, isNull, reason: 'M1 still asks to continue');
  });

  test('loading until the diary is read, then the count; a range the user '
      'picks counts at once and stays picked when the clips change; Continue '
      'makes the movie of the range picked; a diary that cannot be read '
      'makes no movie', () async {
    final CreateMovieCubit failing = build();
    clips.fail(_default, Exception('DCIM is gone'));
    await pumpEventQueue();
    expect(failing.state.status, CreateMovieStatus.failed);
    expect(failing.state.canContinue, isFalse);

    final CreateMovieCubit cubit = build();
    expect(cubit.state.status, CreateMovieStatus.loading);
    expect(cubit.state.canContinue, isFalse);

    clips.publish(clipIndexOf(_default, _daysOf(9, 1, 28)));
    await pumpEventQueue();
    expect(cubit.state.status, CreateMovieStatus.ready);
    expect(cubit.state.presetClips, 28);
    expect(cubit.state.canContinue, isTrue);

    cubit.choosePreset(MoviePreset.last7Days);
    expect(
      (cubit.state.preset, cubit.state.presetClips),
      (MoviePreset.last7Days, 7),
    );
    clips.publish(clipIndexOf(_default, _daysOf(8, 30, 31)));
    await pumpEventQueue();
    expect(
      (cubit.state.preset, cubit.state.presetClips),
      (MoviePreset.last7Days, 0),
    );
    expect(cubit.state.canContinue, isFalse);

    cubit
      ..choosePreset(MoviePreset.thisYear)
      ..confirmPreset();
    expect(cubit.state.source, const MovieSource.preset(MoviePreset.thisYear));
  });

  // The chip changes the movie's profile only.
  test("another profile makes the movie of its clips; the app's profile "
      'stays', () async {
    const ProfileKey kids = ProfileKey('Kids');
    profiles.addProfile(testProfile(key: kids));
    clips
      ..publish(clipIndexOf(_default, _daysOf(9, 1, 28)))
      ..publish(clipIndexOf(kids, _daysOf(9, 1, 3)));
    final CreateMovieCubit cubit = build()..confirmPreset();

    cubit.chooseProfile(kids);

    expect(cubit.state.profile, kids);
    expect(cubit.state.presetClips, 3);
    expect(cubit.state.draft!.clips, hasLength(3));
    expect(cubit.state.draft!.clips.first.profile, kids);
    expect(profiles.active.key, _default);
    clips.publish(clipIndexOf(_default, <LocalDay>[]));
    await pumpEventQueue();
    expect(cubit.state.presetClips, 3, reason: "Default's changes are not it");
  });

  group('Choose a month (M2)', () {
    test('opens on this month when a movie can be made of it, else on the '
        'latest month with enough clips, with the clips of every month of '
        'the year; months with fewer than two clips or to come are off', () {
      clips.publish(
        clipIndexOf(_default, <LocalDay>[
          ..._daysOf(1, 1, 31),
          ..._daysOf(2, 1, 1),
          ..._daysOf(9, 1, 25),
        ]),
      );
      final CreateMovieCubit cubit = build()..openMonthPicker();

      expect(cubit.state.monthChoice, const MonthChoice(year: 2026, month: 9));
      expect(cubit.state.index!.clipsPerMonth(2026), <int>[
        31,
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        25,
        0,
        0,
        0,
      ]);
      expect(cubit.state.isOpen(2026, 1), isTrue);
      expect(cubit.state.isOpen(2026, 2), isFalse, reason: 'one clip only');
      expect(cubit.state.isOpen(2026, 3), isFalse, reason: 'no clip');
      expect(cubit.state.isOpen(2026, 10), isFalse, reason: 'the future');

      clips.publish(
        clipIndexOf(_default, <LocalDay>[
          ..._daysOf(3, 1, 5),
          LocalDay(2026, 9, 28),
          LocalDay(2025, 12, 1),
          LocalDay(2025, 12, 2),
        ]),
      );
      expect(
        (build()..openMonthPicker()).state.monthChoice,
        const MonthChoice(year: 2026, month: 3),
      );
    });

    test('the years run from the first recorded year to this year; another '
        'year keeps the month when it can, else picks its latest month, or '
        'nothing; Continue makes the movie of the month picked', () {
      clips.publish(
        clipIndexOf(_default, <LocalDay>[
          ..._daysOf(1, 1, 31),
          ..._daysOf(9, 1, 25),
          LocalDay(2025, 9, 1),
          LocalDay(2024, 9, 1),
          LocalDay(2024, 9, 2),
          LocalDay(2023, 6, 1),
          LocalDay(2023, 6, 2),
        ]),
      );
      final CreateMovieCubit cubit = build()..openMonthPicker();
      expect(cubit.state.canShowNextYear, isFalse);
      expect(cubit.state.canShowPreviousYear, isTrue);

      cubit.showYear(2025);
      expect(cubit.state.monthChoice, const MonthChoice(year: 2025));
      cubit.showYear(2024);
      expect(cubit.state.monthChoice, const MonthChoice(year: 2024, month: 9));
      cubit.showYear(2023);
      expect(cubit.state.monthChoice, const MonthChoice(year: 2023, month: 6));
      expect(cubit.state.canShowPreviousYear, isFalse);
      cubit.showYear(2022);
      expect(cubit.state.monthChoice!.year, 2023, reason: 'no clips before');

      cubit
        ..showYear(2026)
        ..pickMonth(2)
        ..pickMonth(1);
      expect(cubit.state.monthChoice, const MonthChoice(year: 2026, month: 1));
      cubit.confirmMonth();
      expect(cubit.state.source, const MovieSource.month(year: 2026, month: 1));
    });
  });

  group('Pick videos myself (M3/M4)', () {
    ClipRef clipOf(LocalDay day) =>
        clipIndexOf(_default, <LocalDay>[day]).clipsOn(day).single;

    test(
      'a tap picks a clip and another unpicks it, two are needed; Select all '
      'picks every clip, then none; a clip deleted meanwhile is no longer '
      'picked; Continue makes the movie of the clips picked; another profile '
      "starts with nothing picked and drops a movie of the old profile's "
      'picks, while a range stays',
      () async {
        clips.publish(clipIndexOf(_default, _daysOf(9, 1, 5)));
        final CreateMovieCubit cubit = build();
        expect(cubit.state.picks.count, 0);

        cubit.togglePick(clipOf(LocalDay(2026, 9, 2)));
        expect(
          cubit.state.picks.contains(clipOf(LocalDay(2026, 9, 2))),
          isTrue,
        );
        expect(cubit.state.canConfirmPicks, isFalse, reason: 'one clip');
        cubit.togglePick(clipOf(LocalDay(2026, 9, 3)));
        expect(cubit.state.canConfirmPicks, isTrue);
        cubit.togglePick(clipOf(LocalDay(2026, 9, 2)));
        expect(cubit.state.picks.count, 1);
        expect(cubit.state.allPicked, isFalse);

        cubit.toggleAll();
        expect((cubit.state.picks.count, cubit.state.allPicked), (5, true));
        cubit.toggleAll();
        expect((cubit.state.picks.count, cubit.state.allPicked), (0, false));

        cubit.toggleAll();
        clips.publish(clipIndexOf(_default, _daysOf(9, 2, 5)));
        await pumpEventQueue();
        expect(cubit.state.picks.count, 4);
        expect(
          cubit.state.picks.contains(clipOf(LocalDay(2026, 9, 1))),
          isFalse,
        );

        cubit
          ..toggleAll()
          ..togglePick(clipOf(LocalDay(2026, 9, 4)))
          ..togglePick(clipOf(LocalDay(2026, 9, 2)))
          ..confirmPicks();
        expect(
          cubit.state.source,
          MovieSource.custom(<ClipRef>{
            clipOf(LocalDay(2026, 9, 2)),
            clipOf(LocalDay(2026, 9, 4)),
          }),
        );

        // The picks belong to the profile they were picked from.
        {
          const ProfileKey kids = ProfileKey('Kids');
          profiles.addProfile(testProfile(key: kids));
          clips
            ..publish(clipIndexOf(_default, _daysOf(9, 1, 5)))
            ..publish(clipIndexOf(kids, _daysOf(9, 1, 3)));
          final CreateMovieCubit cubit = build()
            ..toggleAll()
            ..confirmPicks()
            ..chooseProfile(kids);

          expect(cubit.state.picks.count, 0);
          expect(cubit.state.source, isNull);

          cubit
            ..confirmPreset()
            ..chooseProfile(_default);
          expect(
            cubit.state.source,
            const MovieSource.preset(MoviePreset.thisMonth),
          );
        }
      },
    );
  });

  group('Confirm (M5)', () {
    test('the draft follows what M1, M2 and M3 confirm, and the diary; opened '
        "with the Diary's month, the flow makes that month: its clips and the "
        'days without one', () async {
      clips.publish(clipIndexOf(_default, _daysOf(9, 1, 28)));
      final CreateMovieCubit cubit = build();
      expect(cubit.state.draft, isNull, reason: 'nothing confirmed yet');

      cubit
        ..choosePreset(MoviePreset.last7Days)
        ..confirmPreset();
      expect(cubit.state.draft!.clips, hasLength(7));

      clips.publish(clipIndexOf(_default, _daysOf(9, 25, 28)));
      await pumpEventQueue();
      expect(cubit.state.draft!.clips, hasLength(4));
      expect(cubit.state.draft!.skippedDays, hasLength(3));

      {
        clips.publish(
          clipIndexOf(_default, <LocalDay>[
            for (int day = 1; day <= 28; day++)
              if (day != 9 && day != 21) LocalDay(2026, 9, day),
          ]),
        );
        const MovieSource september = MovieSource.month(year: 2026, month: 9);

        final CreateMovieCubit cubit = CreateMovieCubit(
          source: september,
          profiles: profiles,
          clips: clips,
          clock: clock,
          freeSpace: freeSpace,
          backfill: PausableBackfill(),
        );
        addTearDown(cubit.close);

        expect(cubit.state.source, september);
        expect(cubit.state.draft!.clips, hasLength(26));
        expect(cubit.state.draft!.skippedDays, <LocalDay>[
          LocalDay(2026, 9, 9),
          LocalDay(2026, 9, 21),
        ]);
      }
    });

    test('Create movie with enough space: the free space is checked, then '
        "the movie of the draft is ready, on the profile's canvas; with too "
        'few clips it does nothing', () async {
      const ProfileKey kids = ProfileKey('Kids');
      profiles.addProfile(
        testProfile(key: kids, orientation: VideoOrientation.portrait),
      );
      clips
        ..publish(clipIndexOf(kids, _daysOf(9, 1, 3)))
        ..publish(clipIndexOf(_default, _daysOf(9, 1, 1)));
      final CreateMovieCubit tooFew = build()..confirmPreset();
      await tooFew.startMovie(title: 'September 2026');
      expect(tooFew.state.launch, MovieLaunch.idle);

      freeSpace
        ..free = 1000000
        ..hold = true;
      final CreateMovieCubit cubit = build()
        ..chooseProfile(kids)
        ..confirmPreset();

      final Future<void> starting = cubit.startMovie(title: 'September 2026');
      expect(cubit.state.launch, MovieLaunch.checking);
      freeSpace.answer();
      await starting;

      expect(cubit.state.launch, MovieLaunch.ready);
      expect(
        cubit.state.request,
        const MovieJobRequest(
          source: MovieSource.preset(MoviePreset.thisMonth),
          profile: kids,
          format: ClipFormat.legacy(VideoOrientation.portrait),
          title: 'September 2026',
          clipBytes: 24,
        ),
      );
    });

    // 3 clips of 8 bytes need 51 bytes free (2.1 × 24).
    test('Create movie on a full phone fails at once with what to free; once '
        'freed, it goes; another movie (the chip, the diary) clears the '
        'error; an unknown free space never stops a movie', () async {
      clips.publish(clipIndexOf(_default, _daysOf(9, 1, 3)));
      freeSpace.free = 20;
      final CreateMovieCubit cubit = build()..confirmPreset();

      await cubit.startMovie(title: 'September 2026');
      expect(cubit.state.launch, MovieLaunch.noSpace);
      expect(cubit.state.spaceShortfall, 51 - 20);
      expect(cubit.state.request, isNull);

      freeSpace.free = 51;
      await cubit.startMovie(title: 'September 2026');
      expect(cubit.state.launch, MovieLaunch.ready);
      expect(cubit.state.spaceShortfall, isNull);

      freeSpace.free = 0;
      final CreateMovieCubit full = build()..confirmPreset();
      await full.startMovie(title: 'September 2026');
      expect(full.state.launch, MovieLaunch.noSpace);
      clips.publish(clipIndexOf(_default, _daysOf(9, 1, 2)));
      await pumpEventQueue();
      expect(full.state.launch, MovieLaunch.idle);
      expect(full.state.spaceShortfall, isNull);

      freeSpace.free = null;
      final CreateMovieCubit unknown = build()..confirmPreset();
      await unknown.startMovie(title: 'September 2026');
      expect(unknown.state.launch, MovieLaunch.ready);
    });
  });
}
