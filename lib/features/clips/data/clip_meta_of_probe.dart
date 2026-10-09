import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/clip_notes_tag.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/location_tag.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';

/// The [ClipMeta] of a probed clip: every fact is known afterwards.
///
/// [subtitleText] is what `MediaEngine.readSubtitles` returned, `''` for a
/// clip without a subtitle stream. The `location` tag is decoded only by
/// [LocationTag] (never by hand); a clip without a readable geotag gets
/// `locationText: ''` (known: no place) and null coordinates, and a "Null
/// Island" tag (`+0+0/<typed place>`) keeps its place without coordinates.
/// A clip without a `location` tag may still name its place in the notes
/// tag (`ClipNotesTag`, `place=`: a place typed or picked without a fix).
/// [keyframes] is the keyframe probe's answer (`MediaEngine.probeKeyframes`),
/// null when it failed: the clip is read, its cuts are not.
ClipMeta clipMetaOfProbe(
  ClipProbe probe, {
  required String subtitleText,
  ClipKeyframes? keyframes,
}) {
  final LocationTag? location = LocationTag.parse(probe.locationTag);
  return ClipMeta(
    durationMs: probe.durationMs,
    hasAudio: probe.hasAudio,
    hasSubtitleStream: probe.hasSubtitleStream,
    subtitleText: subtitleText,
    locationText:
        location?.place ?? ClipNotesTag.parse(probe.synopsis)['place'] ?? '',
    latitude: location?.latitude,
    longitude: location?.longitude,
    isOsdV15: probe.isOsdV15,
    width: probe.width,
    height: probe.height,
    codec: probe.codec,
    origin: probe.origin,
    isPrivate: probe.isPrivate,
    tags: TagName.normalize(probe.tags),
    isMuted: ClipNotesTag.isMuted(probe.synopsis),
    keyframes: keyframes,
    fps: probe.fps,
    channels: probe.channels,
    pixelFormat: probe.pixelFormat,
    colorTransfer: probe.colorTransfer,
    schema: probe.schema,
  );
}
