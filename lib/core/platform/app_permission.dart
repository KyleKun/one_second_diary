/// A runtime permission the app asks for.
enum AppPermission {
  camera,
  microphone,

  /// Android ≤ 12 (SDK ≤ 32) storage (`READ/WRITE_EXTERNAL_STORAGE`).
  storageLegacy,

  /// Android ≥ 13 (SDK ≥ 33) images, requested together with [videos]; iOS
  /// photo library.
  photos,

  /// Android ≥ 13 (SDK ≥ 33) videos.
  videos,

  /// While-in-use location, for geotagging.
  location,

  /// Posting notifications (Android ≥ 13, iOS), for reminders.
  notifications,
}
