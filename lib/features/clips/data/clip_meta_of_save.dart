import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_recipe.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/rendered_clip.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';

/// The [ClipMeta] of a clip the app just rendered from [request]: the same
/// facts a probe of the file would give (`clipMetaOfProbe`), known without
/// running ffprobe.
///
/// - Codec, frame rate and channels are the request's format; the artist tag
///   is the legacy `v1.5` marker or `v2`. Audio is the engine's answer
///   (`RenderedClip.hasAudio`), never assumed: a recording made without a
///   microphone has none, and a movie must normalise it. A null stays null:
///   the movie then probes that clip once.
/// - The place is the request's whenever a place is enabled: with coordinates
///   in the `location` tag, without them in the notes tag (`ClipNotesTag`,
///   `place=`). Coordinates are recorded only when both are known.
/// - It is private only when the request asked for the privacy tag, and its
///   tags are the request's.
/// - Keyframes are what the engine probed from the new file; null when that
///   probe failed.
/// - [recipe] is given only when the save kept the clip's source.
ClipMeta clipMetaOfSave({
  required RenderedClip rendered,
  required ClipRenderRequest request,
  ClipRecipe? recipe,
}) {
  final ClipLocation location = request.location;
  final bool tagged =
      location.enabled &&
      location.latitude != null &&
      location.longitude != null;
  return ClipMeta(
    durationMs: rendered.durationMs,
    hasAudio: rendered.hasAudio,
    hasSubtitleStream: rendered.hasSubtitleStream,
    subtitleText: request.subtitles,
    locationText: location.enabled ? (location.text ?? '').trim() : '',
    latitude: tagged ? location.latitude : null,
    longitude: tagged ? location.longitude : null,
    isOsdV15: true,
    width: rendered.width,
    height: rendered.height,
    codec: request.format.codec.token,
    origin: request.origin,
    isPrivate: request.isPrivate,
    tags: request.tags,
    isMuted: request.mute,
    keyframes: rendered.keyframes,
    fps: rendered.fps ?? request.format.fpsValue.toDouble(),
    channels: rendered.channels ?? request.format.channelCount,
    pixelFormat: rendered.pixelFormat,
    colorTransfer: rendered.colorTransfer,
    schema:
        rendered.schema ??
        (request.format.isLegacy ? ClipSchema.v15 : ClipSchema.v2),
    recipe: recipe,
  );
}
