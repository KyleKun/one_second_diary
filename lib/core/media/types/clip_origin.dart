/// Where a clip came from, as written into its `comment` metadata
/// (`comment=origin=<tag>`). The tags are part of the clip format contract.
enum ClipOrigin {
  /// Recorded with the in-app or the system camera.
  osdRecording('osd_recording'),

  /// Imported from a gallery video.
  gallery('gallery'),

  /// Made from a gallery photo.
  galleryPhoto('gallery_photo'),

  /// A clip normalised for a movie (only ever on temporary copies).
  osdRecordingOld('osd_recording_old'),

  /// A foreign video found in the diary folder and processed into a clip
  /// (`comment=origin=import`). Its original
  /// is moved beside the diary, never deleted.
  import('import');

  const ClipOrigin(this.tag);

  final String tag;

  /// The full `comment` metadata value, e.g. `origin=gallery`.
  String get comment => 'origin=$tag';

  /// The origin in a clip's `comment` metadata, or null when it is absent or
  /// not one of ours.
  static ClipOrigin? fromComment(String? comment) {
    for (final ClipOrigin origin in values) {
      if (comment == origin.comment) return origin;
    }
    return null;
  }
}
