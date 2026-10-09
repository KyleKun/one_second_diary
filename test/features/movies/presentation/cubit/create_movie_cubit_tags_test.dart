// The tag filter in the Create movie flow: every count follows it, the
// chosen source carries it, the Diary can open the flow with one, Select
// all picks only the clips the filter shows, and the confirmation knows
// while clips are still being read.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';

import '../../support/create_movie_world.dart';

LocalDay _day(int day) => LocalDay(2026, 9, day);

void main() {
  late CreateMovieWorld world;

  // September 1–6: 1, 2 and 4 "trip", 3 "work", 5 untagged, 6 "trip" and
  // "work".
  setUp(() {
    world = CreateMovieWorld()
      ..record(
        <LocalDay>[for (int day = 1; day <= 6; day++) _day(day)],
        tags: <LocalDay, List<String>>{
          _day(1): <String>['trip'],
          _day(2): <String>['trip'],
          _day(3): <String>['work'],
          _day(4): <String>['trip'],
          _day(6): <String>['trip', 'work'],
        },
      );
  });

  tearDown(() => world.dispose());

  ClipRef clipOn(int day) => world.indexOf().clipsOn(_day(day)).single;

  test('"only tagged" and "leave out tagged" narrow the preset count, the '
      'month grid and the days offered; the chosen source carries the '
      'filter; a tag chosen on one side leaves the other; clearing counts '
      'every clip again', () {
    final CreateMovieCubit cubit = world.cubit();
    addTearDown(cubit.close);
    expect(cubit.state.presetClips, 6);
    expect(cubit.state.index?.hasTags, isTrue);

    cubit.setOnlyTags(<String>{'Trip'});

    expect(cubit.state.presetClips, 4);
    expect(cubit.state.rangeIndex?.clipsPerMonth(2026)[8], 4);
    expect(cubit.state.isOpen(2026, 9), isTrue);
    expect(cubit.state.pickableDays?.first, _day(1));

    cubit.setWithoutTags(<String>{'work'});

    expect(cubit.state.presetClips, 3);
    expect(cubit.state.tags, TagFilter(anyOf: {'Trip'}, noneOf: {'work'}));
    cubit.confirmPreset();
    expect(
      cubit.state.source,
      MovieSource.preset(
        MoviePreset.thisMonth,
        tags: TagFilter(anyOf: {'trip'}, noneOf: {'work'}),
      ),
    );
    expect(cubit.state.draft?.clips, hasLength(3));
    expect(cubit.state.draft?.tagsLeftOut, 3);

    // "work" moves to "only tagged": it is no longer left out.
    cubit.setOnlyTags(<String>{'work'});
    expect(cubit.state.tags, TagFilter(anyOf: {'work'}));
    expect(cubit.state.presetClips, 2);
    expect(cubit.state.pickableDays?.first, _day(3));
    expect(
      cubit.state.source,
      MovieSource.preset(
        MoviePreset.thisMonth,
        tags: TagFilter(anyOf: {'work'}),
      ),
      reason: 'the chosen source follows the filter',
    );

    cubit.removeTag('work');
    expect(cubit.state.tags.isEmpty, isTrue);
    expect(cubit.state.presetClips, 6);

    cubit.setOnlyTags(<String>{'trip'});
    cubit.clearTags();
    expect(cubit.state.presetClips, 6);
    expect(cubit.state.source, const MovieSource.preset(MoviePreset.thisMonth));
  });

  test('the Diary opens the flow with its filter (and its month): the '
      'confirmation shows that movie; another profile starts without a '
      'filter', () {
    final CreateMovieCubit cubit = world.cubit(
      source: const MovieSource.month(year: 2026, month: 9),
      tags: TagFilter(anyOf: <String>{'trip'}),
    );
    addTearDown(cubit.close);

    expect(cubit.state.tags, TagFilter(anyOf: <String>{'trip'}));
    expect(
      cubit.state.source,
      MovieSource.month(year: 2026, month: 9, tags: TagFilter(anyOf: {'trip'})),
    );
    expect(cubit.state.draft?.clips, hasLength(4));

    cubit.chooseProfile(kidsProfile);
    expect(cubit.state.tags.isEmpty, isTrue);
    expect(cubit.state.source, const MovieSource.month(year: 2026, month: 9));

    // A source that carries a filter opens with it too.
    final CreateMovieCubit carried = world.cubit(
      source: MovieSource.month(
        year: 2026,
        month: 9,
        tags: TagFilter(noneOf: <String>{'work'}),
      ),
    );
    addTearDown(carried.close);
    expect(carried.state.tags, TagFilter(noneOf: <String>{'work'}));
    expect(carried.state.draft?.clips, hasLength(4));
  });

  test('the picker shows the clips the filter keeps, its grid keeping its '
      'identity across picks; Select all picks only those; a hidden clip '
      'picked before stays picked', () {
    final CreateMovieCubit cubit = world.cubit()..togglePick(clipOn(3));
    addTearDown(cubit.close);
    expect(cubit.state.pickIndex, same(cubit.state.index));

    cubit.setOnlyTags(<String>{'trip'});

    expect(cubit.state.pickIndex?.clipCount, 4);
    expect(cubit.state.pickIndex, isNot(same(cubit.state.index)));
    final Object? grid = cubit.state.pickIndex;
    cubit.togglePick(clipOn(1));
    expect(cubit.state.pickIndex, same(grid));
    expect(cubit.state.allPicked, isFalse);

    cubit.toggleAll();

    expect(cubit.state.allPicked, isTrue);
    expect(cubit.state.picks.clips, <ClipRef>{
      clipOn(1),
      clipOn(2),
      clipOn(3),
      clipOn(4),
      clipOn(6),
    });
    cubit.confirmPicks();
    expect(
      cubit.state.source,
      MovieSource.custom(cubit.state.picks.clips),
      reason: 'clips picked by hand carry no filter',
    );

    cubit.toggleAll();
    expect(cubit.state.picks.count, 0);
  });

  test('while the backfill reads clips the flow says so, and stops once '
      'it is idle; it is idle at the start', () async {
    final CreateMovieCubit cubit = world.cubit();
    addTearDown(cubit.close);
    await pumpEventQueue();
    expect(cubit.state.isReadingClips, isFalse);

    world.backfill.startReading();
    await pumpEventQueue();
    expect(cubit.state.isReadingClips, isTrue);

    world.backfill.finishReading();
    await pumpEventQueue();
    expect(cubit.state.isReadingClips, isFalse);
  });

  test('a profile without tags has no vocabulary, and a filter that keeps '
      'nothing counts nothing', () {
    world.record(<LocalDay>[_day(1), _day(2)], profile: kidsProfile);
    final CreateMovieCubit cubit = world.cubit()..chooseProfile(kidsProfile);
    addTearDown(cubit.close);
    expect(cubit.state.index?.hasTags, isFalse);
    expect(cubit.state.index?.tagCounts, isEmpty);

    cubit.setOnlyTags(<String>{'trip'});
    expect(cubit.state.presetClips, 0);
    expect(cubit.state.pickableDays, isNull);
    expect(cubit.state.canContinue, isFalse);
  });
}
