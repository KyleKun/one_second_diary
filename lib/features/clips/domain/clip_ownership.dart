/// Who owns a clip's source file, which decides whether the app may delete
/// it once the clip is saved.
enum ClipOwnership {
  /// Written by the in-app camera or the system camera into the app's temp
  /// folder.
  cameraTemp,

  /// A copy the system picker (`image_picker`) made in the app's cache.
  pickerCopy,

  /// The user's own gallery file (Android gallery picker). Never deleted.
  userOriginal,

  /// A temporary export the platform made for the app (iOS picker exports).
  platformExport;

  /// Whether the source file may be deleted after a successful save. Only
  /// [userOriginal] may not.
  bool get deletableAfterSave => this != userOriginal;
}
