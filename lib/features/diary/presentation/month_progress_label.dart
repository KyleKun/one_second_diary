import 'package:intl/intl.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';

/// The progress line under a month's title: "25 of 28 days" while
/// [recorded] counts up to [count]'s; blank when no day of the month counts
/// (before the profile's first clip); "–" while the diary is being read.
abstract final class MonthProgressLabel {
  /// Shown while the diary is being read.
  static const String unknown = '–';

  static String of(
    MonthCount? count, {
    required int recorded,
    required NumberFormat numbers,
  }) => switch (count) {
    null => unknown,
    (total: 0, recorded: _) => '',
    (total: final int total, recorded: _) => Strings.diaryMonthProgress(
      total,
      recorded: recorded,
      format: numbers,
    ),
  };
}
