import 'package:equatable/equatable.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';

/// The file a new clip is made from.
sealed class ClipSource extends Equatable {
  const ClipSource({
    required this.path,
    required this.ownership,
    this.owned = true,
  });

  /// Absolute path of the source file. Never one of the app's own clip
  /// folders, and never the destination clip itself.
  final String path;

  /// Decides whether [path] is deleted after a successful save.
  final ClipOwnership ownership;

  /// Whether the editor owns [path]: a camera temp (true) is deleted after a
  /// save or a discard; a kept original opened with "Edit again" (false) never
  /// is. Nothing reads it yet.
  final bool owned;
}

/// A video: a camera recording or a gallery import.
final class VideoSource extends ClipSource {
  const VideoSource({
    required super.path,
    required super.ownership,
    super.owned,
  });

  /// Recorded by the in-app or the system camera (tagged `osd_recording`),
  /// as opposed to imported from the gallery (tagged `gallery`). Derived
  /// from [ownership]: only a camera writes a `cameraTemp` file.
  bool get fromRecording => ownership == ClipOwnership.cameraTemp;

  @override
  List<Object?> get props => <Object?>[path, ownership, owned];
}

/// A still photo turned into a clip.
final class PhotoSource extends ClipSource {
  const PhotoSource({
    required super.path,
    required super.ownership,
    super.owned,
  });

  @override
  List<Object?> get props => <Object?>[path, ownership, owned];
}
