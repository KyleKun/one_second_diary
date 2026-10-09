/// The part of the day the character greets by while today has no clip:
/// "Good morning", "Good afternoon", "Good evening" or "Still up?".
enum PartOfDay {
  /// 05:00 to 11:59.
  morning,

  /// 12:00 to 17:59.
  afternoon,

  /// 18:00 to 21:59.
  evening,

  /// 22:00 to 04:59, across midnight.
  lateNight;

  /// The hours each part starts at, in the order of the day.
  static const List<int> _startHours = <int>[5, 12, 18, 22];

  /// The part of the day [time] falls in, by its local wall-clock hour.
  static PartOfDay at(DateTime time) => switch (time.hour) {
    >= 5 && < 12 => morning,
    >= 12 && < 18 => afternoon,
    >= 18 && < 22 => evening,
    _ => lateNight,
  };

  /// The first local moment after [time] when the part of the day changes:
  /// the next 05:00, 12:00, 18:00 or 22:00.
  static DateTime nextChangeAfter(DateTime time) {
    for (final int hour in _startHours) {
      final DateTime start = DateTime(time.year, time.month, time.day, hour);
      if (start.isAfter(time)) return start;
    }
    return DateTime(time.year, time.month, time.day + 1, _startHours.first);
  }
}
