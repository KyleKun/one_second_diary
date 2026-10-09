/// The app's single notion of "now": the device's wall clock, a platform
/// boundary like the plugins next to it.
///
/// Everything that asks what day or time it is (naming a clip, Today's
/// status, reminders, stats, the midnight rollover) reads it from an injected
/// [Clock] instead of calling `DateTime.now()`, so tests can pin the time
/// with a fake clock.
abstract interface class Clock {
  /// The current local date and time.
  DateTime now();
}
