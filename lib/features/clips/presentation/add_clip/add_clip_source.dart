/// Where a new clip comes from.
enum AddClipSource {
  /// The camera: the in-app one (`/record`), or the system camera below
  /// Android 10 and with "Force native camera".
  record,

  /// A video from the gallery.
  video,

  /// A photo from the gallery, made into a still clip.
  photo,
}
