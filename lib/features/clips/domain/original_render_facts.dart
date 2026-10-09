import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';

/// What a render from a clip's kept original takes from the clip's cached
/// origin (`ClipMeta.origin`): the two `VideoRender` flags that pick the
/// save's origin tag and audio path, and the ownership the editor opens the
/// original under. Shared by `EditAgainFlow` and `ProfileConverter`, so a
/// processed import's re-save stays an import and a recording's a recording.
///
/// An unknown origin is a recording.
abstract final class OriginalRenderFacts {
  /// `VideoRender.fromRecording` for [origin]: the in-app or the system
  /// camera made it (`osd_recording`, or the `osd_recording_old` of a
  /// normalised copy).
  static bool fromRecording(ClipOrigin? origin) =>
      origin == null ||
      origin == ClipOrigin.osdRecording ||
      origin == ClipOrigin.osdRecordingOld;

  /// `VideoRender.imported` for [origin]: a foreign video processed into
  /// a clip (`origin=import`).
  static bool imported(ClipOrigin? origin) => origin == ClipOrigin.import;

  /// The ownership the editor opens a kept original of [origin] under: a
  /// camera's take as a camera temp, anything the user brought in (an
  /// import, a gallery pick) as their own file. The editor never owns the
  /// original either way (`ClipSource.owned` false).
  static ClipOwnership ownership(ClipOrigin? origin) => fromRecording(origin)
      ? ClipOwnership.cameraTemp
      : ClipOwnership.userOriginal;
}
