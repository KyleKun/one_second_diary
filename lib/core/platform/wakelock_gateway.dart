/// Keeps the screen on during long jobs such as making a movie
/// (`wakelock_plus`).
///
/// Best effort: neither call ever throws. A platform that refuses the
/// wakelock is logged by the implementation, and the job goes on without it
/// (it only keeps the screen on).
abstract interface class WakelockGateway {
  Future<void> enable();

  Future<void> disable();
}
