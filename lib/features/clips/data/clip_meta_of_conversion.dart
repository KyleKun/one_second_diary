import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/rendered_clip.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';

/// The [ClipMeta] of a clip just rendered into [format] from a clip whose
/// facts were [previous]: picture and sound facts come from the render, text
/// facts from [previous]; no probe. A null [previous] leaves those unknown,
/// for the backfill.
ClipMeta clipMetaOfConversion({
  required ClipMeta? previous,
  required RenderedClip rendered,
  required ClipFormat format,
}) => ClipMeta(
  durationMs: rendered.durationMs,
  hasAudio: rendered.hasAudio ?? previous?.hasAudio ?? true,
  hasSubtitleStream: rendered.hasSubtitleStream,
  subtitleText: previous?.subtitleText,
  locationText: previous?.locationText,
  latitude: previous?.latitude,
  longitude: previous?.longitude,
  isOsdV15: format.isLegacy,
  width: rendered.width,
  height: rendered.height,
  codec: format.codec.token,
  origin: previous?.origin,
  isPrivate: previous?.isPrivate,
  tags: previous?.tags,
  keyframes: rendered.keyframes,
  isMuted: previous?.isMuted,
  fps: rendered.fps ?? format.fpsValue.toDouble(),
  channels: rendered.channels ?? format.channelCount,
  pixelFormat: rendered.pixelFormat,
  colorTransfer: rendered.colorTransfer,
  schema: rendered.schema ?? (format.isLegacy ? ClipSchema.v15 : ClipSchema.v2),
);
