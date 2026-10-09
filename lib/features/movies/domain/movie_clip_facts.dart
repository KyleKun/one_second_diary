import 'package:one_second_diary/core/media/policy/movie_plan.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/movie_clip.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';

/// The `MovieClip` facts a clip's cached [ClipMeta] gives (`MovieBuilder` and
/// the confirmation count share them): copied as they are, a null stays null,
/// so the engine probes that one clip instead of guessing.
abstract final class MovieClipFacts {
  static MovieClip of(
    ClipMeta? meta, {
    required String path,
    String? chapterTitle,
  }) => MovieClip(
    path: path,
    durationMs: meta?.durationMs,
    isOsdV15: meta?.isOsdV15,
    hasAudio: meta?.hasAudio,
    hasSubtitleStream: meta?.hasSubtitleStream,
    width: meta?.width,
    height: meta?.height,
    codec: meta?.codec,
    keyframes: meta?.keyframes,
    chapterTitle: chapterTitle,
    fps: meta?.fps,
    channels: meta?.channels,
    pixelFormat: meta?.pixelFormat,
    colorTransfer: meta?.colorTransfer,
    schema: meta?.schema,
  );

  /// Whether a clip with cached facts [meta] is converted first when a movie of
  /// a profile in [format] is made.
  static bool needsConverting(ClipMeta? meta, {required ClipFormat format}) =>
      meta != null &&
      MoviePlan.needsNormalising(of(meta, path: ''), format: format);
}
