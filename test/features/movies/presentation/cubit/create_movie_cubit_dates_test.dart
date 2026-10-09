// "Choose dates" (M2b): the sheet opens on this month over the days with
// clips; a tap picks the first day, the next the last; the count and
// Continue follow; the days picked become the movie.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/movies/domain/date_choice.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_state.dart';

import '../../support/create_movie_world.dart';

/// Days [first] to [last] of [month] 2026.
List<LocalDay> _daysOf(int month, int first, int last) => <LocalDay>[
  for (int day = first; day <= last; day++) LocalDay(2026, month, day),
];

LocalDay _sep(int day) => LocalDay(2026, 9, day);

void main() {
  late CreateMovieWorld world;

  setUp(() => world = CreateMovieWorld());
  tearDown(() => world.dispose());

  CreateMovieCubit open() {
    final CreateMovieCubit cubit = world.cubit()..openDatePicker();
    addTearDown(cubit.close);
    return cubit;
  }

  test('opens on this month, offering the first recorded day through '
      'today; nothing opens before the diary is read or without a clip', () {
    final CreateMovieCubit unread = world.cubit()..openDatePicker();
    addTearDown(unread.close);
    expect(unread.state.dateChoice, isNull);

    world.record(const <LocalDay>[]);
    final CreateMovieCubit empty = open();
    expect(empty.state.status, CreateMovieStatus.ready);
    expect(empty.state.dateChoice, isNull);

    world.record(<LocalDay>[..._daysOf(8, 10, 31), ..._daysOf(9, 1, 25)]);
    final CreateMovieCubit cubit = open();
    expect(
      cubit.state.dateChoice,
      const DateChoice(shown: DiaryMonth(2026, 9)),
    );
    expect(
      cubit.state.pickableDays,
      DayRange(first: LocalDay(2026, 8, 10), last: _sep(28)),
    );
    expect(cubit.state.isPickable(LocalDay(2026, 8, 9)), isFalse);
    expect(cubit.state.isPickable(_sep(29)), isFalse);
    expect(cubit.state.canShowPreviousDateMonth, isTrue);
    expect(cubit.state.canShowNextDateMonth, isFalse);
  });

  test('the first tap picks the first day, the next the last; an earlier '
      'day becomes the first; a third tap starts over; the count follows; '
      'a day outside the days offered does nothing', () {
    world.record(<LocalDay>[..._daysOf(8, 10, 31), ..._daysOf(9, 1, 25)]);
    final CreateMovieCubit cubit = open();

    cubit.pickDay(_sep(3));
    expect(cubit.state.dateChoice!.from, _sep(3));
    expect(cubit.state.dateChoice!.to, isNull);
    expect(cubit.state.dateChoice!.next, DateEnd.to);
    expect(cubit.state.dateRangeClips, 0, reason: 'no range yet');
    expect(cubit.state.canConfirmDates, isFalse);

    cubit.pickDay(_sep(12));
    expect(cubit.state.dateChoice!.to, _sep(12));
    expect(cubit.state.dateChoice!.next, DateEnd.from);
    expect(cubit.state.dateRangeClips, 10);
    expect(cubit.state.canConfirmDates, isTrue);

    cubit.pickDay(_sep(1));
    expect(cubit.state.dateChoice!.from, _sep(1), reason: 'earlier: new from');
    expect(cubit.state.dateChoice!.to, _sep(12), reason: 'still after');
    expect(cubit.state.dateRangeClips, 12);

    cubit.pickDay(_sep(20));
    expect(cubit.state.dateChoice!.from, _sep(20), reason: 'starts over');
    expect(cubit.state.dateChoice!.to, isNull);

    cubit
      ..pickDay(_sep(29)) // tomorrow
      ..pickDay(LocalDay(2026, 8, 9)); // before the first clip
    expect(cubit.state.dateChoice!.from, _sep(20));
    expect(cubit.state.dateChoice!.to, isNull);

    cubit.pickDay(_sep(20));
    expect(
      cubit.state.dateChoice!.range,
      DayRange(first: _sep(20), last: _sep(20)),
      reason: 'the same day twice is a one-day range',
    );
    expect(cubit.state.dateRangeClips, 1);

    cubit.repickEndDate();
    expect(cubit.state.dateChoice!.to, isNull);
    expect(cubit.state.dateChoice!.from, _sep(20));
    cubit.restartDates();
    expect(cubit.state.dateChoice!.from, isNull);
    expect(cubit.state.dateChoice!.next, DateEnd.from);
  });

  test('the month pages back to the first recorded month and forward to '
      'this one, no further', () {
    world.record(<LocalDay>[..._daysOf(8, 10, 31), ..._daysOf(9, 1, 25)]);
    final CreateMovieCubit cubit = open();

    cubit.showPreviousMonth();
    expect(cubit.state.dateChoice!.shown, const DiaryMonth(2026, 8));
    expect(cubit.state.canShowPreviousDateMonth, isFalse);
    cubit.showPreviousMonth();
    expect(cubit.state.dateChoice!.shown, const DiaryMonth(2026, 8));

    cubit.showNextMonth();
    expect(cubit.state.dateChoice!.shown, const DiaryMonth(2026, 9));
    cubit.showNextMonth();
    expect(cubit.state.dateChoice!.shown, const DiaryMonth(2026, 9));
  });

  test('Continue makes the movie of the days picked once they hold two '
      'clips, never fewer; the days picked stay for the next opening, a '
      'half pick does not', () {
    world.record(<LocalDay>[_sep(3), _sep(12), _sep(20)]);
    final CreateMovieCubit cubit = open();

    cubit
      ..pickDay(_sep(3))
      ..pickDay(_sep(5))
      ..confirmDates();
    expect(cubit.state.dateRangeClips, 1);
    expect(cubit.state.source, isNull, reason: 'one clip is no movie');

    cubit
      ..pickDay(_sep(3))
      ..pickDay(_sep(12))
      ..confirmDates();
    expect(
      cubit.state.source,
      MovieSource.dateRange(DayRange(first: _sep(3), last: _sep(12))),
    );
    expect(cubit.state.draft!.clips, hasLength(2));

    cubit.openDatePicker();
    expect(
      cubit.state.dateChoice,
      DateChoice(from: _sep(3), to: _sep(12), shown: const DiaryMonth(2026, 9)),
    );

    cubit
      ..pickDay(_sep(20))
      ..openDatePicker();
    expect(cubit.state.dateChoice!.from, isNull, reason: 'half picks go');
  });

  test('the profile chip forgets the days being picked; the movie of a range '
      'stays', () {
    world.record(<LocalDay>[..._daysOf(9, 1, 25)]);
    world.record(<LocalDay>[..._daysOf(9, 1, 5)], profile: kidsProfile);
    final CreateMovieCubit cubit = open()
      ..pickDay(_sep(3))
      ..pickDay(_sep(12))
      ..confirmDates()
      ..chooseProfile(kidsProfile);

    expect(cubit.state.dateChoice, isNull);
    expect(
      cubit.state.source,
      MovieSource.dateRange(DayRange(first: _sep(3), last: _sep(12))),
    );
    expect(cubit.state.draft!.clips, hasLength(3), reason: "Kids' clips");
  });
}
