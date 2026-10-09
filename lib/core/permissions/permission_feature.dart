/// What the user is doing that needs a runtime permission.
///
/// A permission is asked with the user's own tap, never silently at launch:
/// on the onboarding permissions step, where each row's "Allow" asks
/// for one feature, and after that just in time, when the user starts the
/// thing that needs it. At startup code may only check
/// (`PermissionRequester.check`), which never prompts.
enum PermissionFeature {
  /// Reading and writing the diary in the phone's gallery (Android
  /// `DCIM/OneSecondDiary`). The "Photos and videos" row of O5; when that
  /// row was not tapped, asked once more as onboarding finishes, before the
  /// Default profile is created, because the answer also decides the
  /// reinstall path. The one exception to "never at launch": without it an
  /// Android diary can't list or save its clips, so once onboarded each
  /// launch asks again until it is granted (`PostFrameLaunch`). Nothing to
  /// ask on iOS.
  mediaLibrary,

  /// Recording with the in-app camera. Asked at the first record, with the
  /// rationale loop in the recording cubit (see `PermissionRequester`).
  recording,

  /// Recording with the system camera app (forced below Android 10, or the
  /// "Force native camera" preference). Asked at the first record, and by
  /// the "Camera" row of O5.
  nativeCameraRecording,

  /// Recording sound with the in-app camera: the "Microphone" row of O5,
  /// which asks it on its own (the first record asks [recording], camera
  /// and microphone together).
  microphone,

  /// Stamping the place on a clip. Asked the first time geotagging is
  /// switched on in the clip editor, and by the optional "Location" row of
  /// O5.
  geotagging,

  /// Posting the daily reminder. Asked when the user turns the reminder on,
  /// and by the "Notifications" row of O5 (Android 13+ and iOS; older
  /// Android report it granted).
  reminders,
}
