import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/journey_math.dart';
import 'package:one_second_diary/features/clips/domain/month_progress.dart';

/// The Journey tab's statistics for one profile, derived from its
/// [ClipIndex] and the clip metadata, never from stored counters.
final class JourneyStats extends Equatable {
  const JourneyStats({
    required this.today,
    required this.daysRecorded,
    required this.firstDay,
    required this.daysSinceFirstClip,
    required this.currentStreak,
    required this.streakAtRisk,
    required this.longestStreak,
    required this.thisMonth,
    required this.weekRecorded,
    required this.lifeSoFar,
    required this.lifeSoFarIsEstimate,
  });

  /// The statistics of [index] on [today]. [metaOf] returns a clip's cached
  /// metadata, or null while the backfill has not reached it. Recompute on
  /// every index change, at midnight and on resume; it costs O(clips).
  factory JourneyStats.of(
    ClipIndex index, {
    required LocalDay today,
    required ClipMeta? Function(ClipRef clip) metaOf,
  }) {
    final List<int> days = index.epochDays;
    final int todayEpoch = today.epochDay;
    int knownMs = 0;
    int known = 0;
    int unknown = 0;
    for (final ClipRef clip in index.newestFirst) {
      final int? durationMs = metaOf(clip)?.durationMs;
      if (durationMs == null) {
        unknown++;
      } else {
        knownMs += durationMs;
        known++;
      }
    }
    final int estimatePerClipMs = known == 0
        ? _nominalClipMs
        : (knownMs / known).round();
    final LocalDay? firstDay = index.firstDay;
    // 1970-01-01 was a Thursday: three days after that week's Monday.
    final int monday = todayEpoch - (todayEpoch + 3) % 7;
    return JourneyStats(
      today: today,
      daysRecorded: index.dayCount,
      firstDay: firstDay,
      daysSinceFirstClip: firstDay == null
          ? null
          : math.max(0, todayEpoch - firstDay.epochDay),
      currentStreak: JourneyMath.currentStreak(days: days, today: todayEpoch),
      streakAtRisk: JourneyMath.streakAtRisk(days: days, today: todayEpoch),
      longestStreak: JourneyMath.longestStreak(days: days, today: todayEpoch),
      thisMonth: JourneyMath.thisMonth(days: days, today: todayEpoch),
      weekRecorded: List<bool>.unmodifiable(<bool>[
        for (int day = monday; day < monday + 7; day++)
          day <= todayEpoch && index.hasDay(LocalDay.fromEpochDay(day)),
      ]),
      lifeSoFar: Duration(milliseconds: knownMs + unknown * estimatePerClipMs),
      lifeSoFarIsEstimate: unknown > 0,
    );
  }

  /// The app's nominal clip length, used for a clip of unknown duration
  /// while no clip's duration is known yet (before the backfill has probed
  /// anything).
  static const int _nominalClipMs = 1000;

  /// The day the stats were computed on.
  final LocalDay today;

  /// Distinct days with at least one clip ("Days recorded").
  final int daysRecorded;

  /// The earliest recorded day ("since March 12, 2024"); null when empty.
  final LocalDay? firstDay;

  /// Days from [firstDay] to [today]; null when empty.
  final int? daysSinceFirstClip;

  /// See [JourneyMath.currentStreak].
  final int currentStreak;

  /// See [JourneyMath.streakAtRisk].
  final bool streakAtRisk;

  /// See [JourneyMath.longestStreak].
  final int longestStreak;

  /// "This month 25 / 28".
  final MonthProgress thisMonth;

  /// Whether each day of [today]'s week has a clip, Monday first; the days
  /// after [today] are false.
  final List<bool> weekRecorded;

  /// The summed length of every clip ("Your life so far"). Clips whose
  /// duration the metadata backfill has not probed yet count as the average
  /// known clip.
  final Duration lifeSoFar;

  /// True while any clip's duration is unknown: show [lifeSoFar] as an
  /// estimate.
  final bool lifeSoFarIsEstimate;

  @override
  List<Object?> get props => <Object?>[
    today,
    daysRecorded,
    firstDay,
    daysSinceFirstClip,
    currentStreak,
    streakAtRisk,
    longestStreak,
    thisMonth,
    weekRecorded,
    lifeSoFar,
    lifeSoFarIsEstimate,
  ];
}
