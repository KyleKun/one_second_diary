/// A hardware volume key.
enum VolumeKey { up, down }

/// The volume keys as a camera shutter.
abstract interface class VolumeKeyGateway {
  /// Each volume-key press while listened to. Android only: while someone
  /// listens the keys don't change the volume (the plugin's activity eats
  /// them), and they work as usual again when nobody does. iOS offers no
  /// supported way, so there it never emits (and never touches a plugin).
  Stream<VolumeKey> presses();
}
