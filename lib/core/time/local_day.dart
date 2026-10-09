/// A calendar day in the user's local time zone, with no time of day.
///
/// Years are limited to 0000-9999, the range where [fileStem] has exactly
/// four year digits, so every day's clip name parses back to that day. Every
/// constructor throws an [ArgumentError] outside it.
final class LocalDay implements Comparable<LocalDay> {
  /// The day [year]-[month]-[day]. Throws an [ArgumentError] for a date that
  /// does not exist (e.g. 2024-02-30) instead of rolling it over the way
  /// `DateTime` does.
  factory LocalDay(int year, int month, int day) =>
      _tryCreate(year, month, day) ??
      (throw ArgumentError('Not a calendar date: $year-$month-$day'));

  const LocalDay._(this.year, this.month, this.day);

  /// The local calendar date of [dateTime]. A UTC value is converted to the
  /// device's time zone first, so an instant always lands on the day the
  /// user saw on their clock.
  factory LocalDay.fromDateTime(DateTime dateTime) {
    final DateTime local = dateTime.toLocal();
    return LocalDay(local.year, local.month, local.day);
  }

  /// The day packed in [key] (`yyyymmdd`, see [LocalDay.key]). Throws an
  /// [ArgumentError] when the key is not a calendar date.
  factory LocalDay.fromKey(int key) =>
      LocalDay(key ~/ 10000, (key ~/ 100) % 100, key % 100);

  /// The day [epochDay] whole days after 1970-01-01.
  factory LocalDay.fromEpochDay(int epochDay) {
    final DateTime utc = DateTime.fromMillisecondsSinceEpoch(
      epochDay * Duration.millisecondsPerDay,
      isUtc: true,
    );
    return LocalDay(utc.year, utc.month, utc.day);
  }

  static final RegExp _stemPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Parses a `yyyy-MM-dd` [stem], or returns null when it is not exactly
  /// that shape or names a date that does not exist (`2024-02-30` is
  /// rejected, where `DateTime.parse` would silently give 2024-03-01).
  static LocalDay? tryParseStem(String stem) {
    final RegExpMatch? match = _stemPattern.firstMatch(stem);
    if (match == null) return null;
    return _tryCreate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  /// Round-trips the fields through UTC (no DST) to reject rolled-over dates,
  /// and keeps the year to four digits.
  static LocalDay? _tryCreate(int year, int month, int day) {
    if (year < 0 || year > 9999) return null;
    final DateTime utc = DateTime.utc(year, month, day);
    if (utc.year != year || utc.month != month || utc.day != day) return null;
    return LocalDay._(year, month, day);
  }

  final int year;
  final int month;
  final int day;

  /// The day packed as `yyyymmdd`, e.g. 2024-01-05 is `20240105`.
  int get key => year * 10000 + month * 100 + day;

  /// Whole days since 1970-01-01. Computed in UTC, where every day is 24 h
  /// long, so day arithmetic never drifts across a DST change.
  int get epochDay =>
      DateTime.utc(year, month, day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  /// `yyyy-MM-dd`, the stem of every clip file name. Hand-rolled on purpose:
  /// it is never localised, and it runs in hot paths where building an intl
  /// `DateFormat` per call is measurably slow.
  String get fileStem => '${_pad(year, 4)}-${_pad(month, 2)}-${_pad(day, 2)}';

  /// The day [days] calendar days later (earlier when negative).
  LocalDay addDays(int days) => LocalDay.fromEpochDay(epochDay + days);

  /// Local midnight at the start of this day (01:00 or later in the rare
  /// zones where the clocks skip midnight on a DST change).
  DateTime toLocalDateTime() => DateTime(year, month, day);

  bool isBefore(LocalDay other) => key < other.key;

  bool isAfter(LocalDay other) => key > other.key;

  @override
  int compareTo(LocalDay other) => key.compareTo(other.key);

  static String _pad(int value, int width) =>
      value.toString().padLeft(width, '0');

  @override
  bool operator ==(Object other) => other is LocalDay && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'LocalDay($fileStem)';
}
