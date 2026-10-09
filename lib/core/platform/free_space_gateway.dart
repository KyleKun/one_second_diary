/// How much space the phone has free where movies are made, checked before
/// any work.
abstract interface class FreeSpaceGateway {
  /// The free bytes on the storage that holds the diary and the app's
  /// scratch folders; null when that cannot be known (never throws).
  Future<int?> freeBytes();
}
