// The character's lines: the pools they come from, the rules that pick
// among them, and the rotation that never repeats a line before its pool
// is spent.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/today/domain/part_of_day.dart';
import 'package:one_second_diary/features/today/domain/today_lines.dart';

void main() {
  test('a rotation hands out every line of a pool once before any repeat, '
      'and keeps pools apart', () {
    final TodayLineRotation rotation = TodayLineRotation(math.Random(3));

    final List<TodayLine> firstRound = <TodayLine>[
      for (int i = 0; i < TodayLinePools.waiting.length; i++)
        rotation.next(TodayLinePools.waiting),
    ];
    expect(firstRound.toSet(), TodayLinePools.waiting.toSet());

    final List<TodayLine> secondRound = <TodayLine>[
      for (int i = 0; i < TodayLinePools.waiting.length; i++)
        rotation.next(TodayLinePools.waiting),
    ];
    expect(secondRound.toSet(), TodayLinePools.waiting.toSet());

    for (int i = 0; i < 10; i++) {
      expect(TodayLinePools.poke, contains(rotation.next(TodayLinePools.poke)));
    }
  });

  test('the idle pool follows the clip count: waiting, one clip, several', () {
    expect(TodayLinePools.idle(0), TodayLinePools.waiting);
    expect(TodayLinePools.idle(1), TodayLinePools.keptOne);
    expect(TodayLinePools.idle(2), TodayLinePools.keptSeveral);
    expect(TodayLinePools.idle(12), TodayLinePools.keptSeveral);
  });

  test('a clip gone has its pool by what the day has left', () {
    expect(TodayLinePools.deleted(0), TodayLinePools.deletedEmpty);
    expect(TodayLinePools.deleted(1), TodayLinePools.deletedKept);
    expect(TodayLinePools.deleted(3), TodayLinePools.deletedKept);
  });

  test('only 7, 30, 100 and 365 recorded days are milestones', () {
    expect(TodayLinePools.milestone(7), TodayLine.milestone7);
    expect(TodayLinePools.milestone(30), TodayLine.milestone30);
    expect(TodayLinePools.milestone(100), TodayLine.milestone100);
    expect(TodayLinePools.milestone(365), TodayLine.milestone365);
    for (final int days in <int>[0, 1, 6, 8, 31, 99, 366]) {
      expect(TodayLinePools.milestone(days), isNull, reason: '$days');
    }
  });

  test('each part of the day has its greeting', () {
    expect(TodayLinePools.partOfDay(PartOfDay.morning), TodayLine.goodMorning);
    expect(
      TodayLinePools.partOfDay(PartOfDay.afternoon),
      TodayLine.goodAfternoon,
    );
    expect(TodayLinePools.partOfDay(PartOfDay.evening), TodayLine.goodEvening);
    expect(TodayLinePools.partOfDay(PartOfDay.lateNight), TodayLine.stillUp);
  });

  test('only the lines about the record button look down', () {
    expect(
      TodayLine.values.where((TodayLine line) => line.looksDown),
      TodayLinePools.pokeWaiting,
    );
  });
}
