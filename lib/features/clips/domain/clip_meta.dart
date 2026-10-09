import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/media/types/clip_recipe.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';

/// Cached facts about one clip, so screens never run ffmpeg to show a clip.
/// Written at save time, backfilled once for clips that lack them. Every
/// field is null until known.
///
/// A movie copies [durationMs], [isOsdV15], [hasAudio], [hasSubtitleStream],
/// [width], [height] and [codec] into `MovieClip` as they are: a null stays
/// null, and the media engine probes that one clip instead of guessing.
final class ClipMeta extends Equatable {
  const ClipMeta({
    this.durationMs,
    this.hasAudio,
    this.hasSubtitleStream,
    this.subtitleText,
    this.locationText,
    this.latitude,
    this.longitude,
    this.isOsdV15,
    this.width,
    this.height,
    this.codec,
    this.origin,
    this.isPrivate,
    this.tags,
    this.keyframes,
    this.isMuted,
    this.fps,
    this.channels,
    this.pixelFormat,
    this.colorTransfer,
    this.schema,
    this.recipe,
  });

  final int? durationMs;
  final bool? hasAudio;
  final bool? hasSubtitleStream;

  /// The soft subtitle text; `''` when the clip has none.
  final String? subtitleText;

  /// The place name of the geotag.
  final String? locationText;

  final double? latitude;
  final double? longitude;

  /// Carries the app's artist tag; false means a movie must normalise it.
  final bool? isOsdV15;

  final int? width;
  final int? height;
  final String? codec;
  final ClipOrigin? origin;

  /// Carries the privacy tag (`ClipPrivacyTag`): left out of movies unless
  /// the user includes it, and blurred where clips are browsed.
  final bool? isPrivate;

  /// The clip's tags (`KeywordsTag`), normalised by `TagName`; `[]` when
  /// the clip has none, null when not read yet.
  final List<String>? tags;

  /// The clip's frame count and keyframe positions (`ClipKeyframes`), for
  /// movies with transitions; null until read. Written at save time from
  /// the engine's probe of the new file, backfilled for the clips that
  /// lack it.
  final ClipKeyframes? keyframes;

  /// Whether the clip's sound was replaced with silence (`ClipNotesTag`
  /// `muted=1`): the Edit sheets then say "Muted"; null until read.
  final bool? isMuted;

  /// The clip's frame rate, audio channel count, pixel format (`yuv420p`),
  /// colour transfer (`arib-std-b67` and `smpte2084` are HDR) and the schema
  /// its artist tag marks; null until read. Sidecar keys `fps`, `channels`,
  /// `pixelFormat`, `colorTransfer`, `schema`.
  final double? fps;
  final int? channels;
  final String? pixelFormat;
  final String? colorTransfer;
  final ClipSchema? schema;

  /// How the clip was made from its kept original recording (sidecar key
  /// `recipe`): the save's window, framing, stamp style, mute and format, for
  /// "Edit again". Null for a clip without a source, and after a reinstall.
  /// A probe never fills it; every edit of the clip's file carries it over.
  final ClipRecipe? recipe;

  /// These facts after the clip was muted (its keyframes are kept: the
  /// video is copied as it is).
  ClipMeta withMuted() => ClipMeta(
    durationMs: durationMs,
    hasAudio: true,
    hasSubtitleStream: hasSubtitleStream,
    subtitleText: subtitleText,
    locationText: locationText,
    latitude: latitude,
    longitude: longitude,
    isOsdV15: isOsdV15,
    width: width,
    height: height,
    codec: codec,
    origin: origin,
    isPrivate: isPrivate,
    tags: tags,
    keyframes: keyframes,
    isMuted: true,
    fps: fps,
    channels: channels,
    pixelFormat: pixelFormat,
    colorTransfer: colorTransfer,
    schema: schema,
    recipe: recipe,
  );

  /// These facts after the clip's keyframes were read.
  ClipMeta withKeyframes(ClipKeyframes keyframes) => ClipMeta(
    durationMs: durationMs,
    hasAudio: hasAudio,
    hasSubtitleStream: hasSubtitleStream,
    subtitleText: subtitleText,
    locationText: locationText,
    latitude: latitude,
    longitude: longitude,
    isOsdV15: isOsdV15,
    width: width,
    height: height,
    codec: codec,
    origin: origin,
    isPrivate: isPrivate,
    tags: tags,
    keyframes: keyframes,
    isMuted: isMuted,
    fps: fps,
    channels: channels,
    pixelFormat: pixelFormat,
    colorTransfer: colorTransfer,
    schema: schema,
    recipe: recipe,
  );

  /// These facts after the clip's tags were set to [tags].
  ClipMeta withTags(List<String> tags) => ClipMeta(
    durationMs: durationMs,
    hasAudio: hasAudio,
    hasSubtitleStream: hasSubtitleStream,
    subtitleText: subtitleText,
    locationText: locationText,
    latitude: latitude,
    longitude: longitude,
    isOsdV15: isOsdV15,
    width: width,
    height: height,
    codec: codec,
    origin: origin,
    isPrivate: isPrivate,
    tags: tags,
    keyframes: keyframes,
    isMuted: isMuted,
    fps: fps,
    channels: channels,
    pixelFormat: pixelFormat,
    colorTransfer: colorTransfer,
    schema: schema,
    recipe: recipe,
  );

  /// These facts after a subtitle edit left the clip with [subtitleText]
  /// (`''` for none).
  ClipMeta withSubtitle(String subtitleText) => ClipMeta(
    durationMs: durationMs,
    hasAudio: hasAudio,
    hasSubtitleStream: subtitleText.isNotEmpty,
    subtitleText: subtitleText,
    locationText: locationText,
    latitude: latitude,
    longitude: longitude,
    isOsdV15: isOsdV15,
    width: width,
    height: height,
    codec: codec,
    origin: origin,
    isPrivate: isPrivate,
    tags: tags,
    keyframes: keyframes,
    isMuted: isMuted,
    fps: fps,
    channels: channels,
    pixelFormat: pixelFormat,
    colorTransfer: colorTransfer,
    schema: schema,
    recipe: recipe,
  );

  /// These facts after the clip was marked private or public.
  ClipMeta withPrivacy({required bool isPrivate}) => ClipMeta(
    durationMs: durationMs,
    hasAudio: hasAudio,
    hasSubtitleStream: hasSubtitleStream,
    subtitleText: subtitleText,
    locationText: locationText,
    latitude: latitude,
    longitude: longitude,
    isOsdV15: isOsdV15,
    width: width,
    height: height,
    codec: codec,
    origin: origin,
    isPrivate: isPrivate,
    tags: tags,
    keyframes: keyframes,
    isMuted: isMuted,
    fps: fps,
    channels: channels,
    pixelFormat: pixelFormat,
    colorTransfer: colorTransfer,
    schema: schema,
    recipe: recipe,
  );

  @override
  List<Object?> get props => <Object?>[
    durationMs,
    hasAudio,
    hasSubtitleStream,
    subtitleText,
    locationText,
    latitude,
    longitude,
    isOsdV15,
    width,
    height,
    codec,
    origin,
    isPrivate,
    tags,
    keyframes,
    isMuted,
    fps,
    channels,
    pixelFormat,
    colorTransfer,
    schema,
    recipe,
  ];
}
