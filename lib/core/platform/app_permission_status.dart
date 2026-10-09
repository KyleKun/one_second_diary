/// The state of an `AppPermission`, mapped from `permission_handler`.
enum AppPermissionStatus {
  /// Granted. Also iOS `provisional` notifications, which are delivered.
  granted,

  /// Partial access (iOS limited photos, Android 14 selected media). Not
  /// enough for the app.
  limited,

  /// Denied, but the system prompt can still be shown again.
  denied,

  /// Denied and the system no longer shows the prompt.
  permanentlyDenied,

  /// Blocked by the OS (parental controls, device policy).
  restricted;

  bool get isGranted => this == granted;

  /// Asking again is pointless; only the system Settings page can grant it.
  bool get isBlocked => this == permanentlyDenied || this == restricted;
}
