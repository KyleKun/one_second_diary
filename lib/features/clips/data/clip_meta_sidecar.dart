import 'dart:convert';

import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';
import 'package:one_second_diary/core/media/types/clip_recipe.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/features/clips/data/stamped_clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';

/// The JSON format of `clip_meta_v1.json`:
///
/// ```json
/// {"version": 1, "clips": {"trip/2024-01-05.mp4":
///   {"size": 1234, "mtime": 1700000000000, "durationMs": 2500, ...}}}
/// ```
///
/// Keys are paths relative to the videos folder, never absolute (the iOS
/// container path changes on every reinstall). Unknown facts are left out.
/// `origin` is the clip's comment tag (`gallery`, ...); `private` is true
/// for a clip that carries the privacy tag; `tags` the clip's tags (absent
/// until read, `[]` for none); `frames` and `keyframes` the clip's frame
/// count and keyframe positions (`ClipKeyframes`, both absent until read);
/// `fps`, `channels`, `pixelFormat`, `colorTransfer` and `schema` (a
/// `ClipSchema` name) the format facts, each absent until read; `recipe` (a
/// `ClipRecipe` object) how the clip was made from its kept original, present
/// only for a clip with a source. Still version 1: every key is additive and
/// an unknown key is ignored, so a sidecar an older build wrote still reads,
/// and a malformed `recipe` reads as none.
abstract final class ClipMetaSidecar {
  static const int version = 1;

  static String encode(Map<String, StampedClipMeta> entries) =>
      jsonEncode(<String, Object?>{
        'version': version,
        'clips': <String, Object?>{
          for (final MapEntry<String, StampedClipMeta> entry in entries.entries)
            entry.key: _encodeEntry(entry.value),
        },
      });

  /// The entries in [json]. Throws a [FormatException] when [json] is not
  /// a sidecar of this [version]; a single malformed entry is dropped (the
  /// backfill probes that clip again).
  static Map<String, StampedClipMeta> decode(String json) {
    final Object? root = jsonDecode(json);
    if (root is! Map<String, Object?> || root['version'] != version) {
      throw const FormatException('Not a clip metadata sidecar of version 1');
    }
    final Object? clips = root['clips'];
    if (clips is! Map<String, Object?>) {
      throw const FormatException('The sidecar has no clips');
    }
    return <String, StampedClipMeta>{
      for (final MapEntry<String, Object?> entry in clips.entries)
        if (_decodeEntry(entry.value) case final StampedClipMeta decoded)
          entry.key: decoded,
    };
  }

  static Map<String, Object?> _encodeEntry(StampedClipMeta entry) {
    final ClipMeta meta = entry.meta;
    return <String, Object?>{
      'size': entry.stamp.sizeBytes,
      'mtime': entry.stamp.modifiedMs,
      'durationMs': ?meta.durationMs,
      'hasAudio': ?meta.hasAudio,
      'hasSubtitleStream': ?meta.hasSubtitleStream,
      'subtitleText': ?meta.subtitleText,
      'locationText': ?meta.locationText,
      'latitude': ?meta.latitude,
      'longitude': ?meta.longitude,
      'isOsdV15': ?meta.isOsdV15,
      'width': ?meta.width,
      'height': ?meta.height,
      'codec': ?meta.codec,
      'origin': ?meta.origin?.tag,
      'private': ?meta.isPrivate,
      'tags': ?meta.tags,
      'muted': ?meta.isMuted,
      'frames': ?meta.keyframes?.frameCount,
      'keyframes': ?meta.keyframes?.indices,
      'fps': ?meta.fps,
      'channels': ?meta.channels,
      'pixelFormat': ?meta.pixelFormat,
      'colorTransfer': ?meta.colorTransfer,
      'schema': ?meta.schema?.name,
      'recipe': ?meta.recipe?.toJson(),
    };
  }

  static StampedClipMeta? _decodeEntry(Object? value) {
    if (value is! Map<String, Object?>) return null;
    if (value case {'size': final int size, 'mtime': final int modifiedMs}) {
      return StampedClipMeta(
        stamp: FileStamp(sizeBytes: size, modifiedMs: modifiedMs),
        meta: ClipMeta(
          durationMs: _as<int>(value['durationMs']),
          hasAudio: _as<bool>(value['hasAudio']),
          hasSubtitleStream: _as<bool>(value['hasSubtitleStream']),
          subtitleText: _as<String>(value['subtitleText']),
          locationText: _as<String>(value['locationText']),
          latitude: _as<num>(value['latitude'])?.toDouble(),
          longitude: _as<num>(value['longitude'])?.toDouble(),
          isOsdV15: _as<bool>(value['isOsdV15']),
          width: _as<int>(value['width']),
          height: _as<int>(value['height']),
          codec: _as<String>(value['codec']),
          origin: _originOf(_as<String>(value['origin'])),
          isPrivate: _as<bool>(value['private']),
          tags: _tags(value['tags']),
          isMuted: _as<bool>(value['muted']),
          keyframes: _keyframes(value['frames'], value['keyframes']),
          fps: _as<num>(value['fps'])?.toDouble(),
          channels: _as<int>(value['channels']),
          pixelFormat: _as<String>(value['pixelFormat']),
          colorTransfer: _as<String>(value['colorTransfer']),
          schema: ClipSchema.parse(_as<String>(value['schema'])),
          recipe: ClipRecipe.fromJson(value['recipe']),
        ),
      );
    }
    return null;
  }

  static T? _as<T>(Object? value) => value is T ? value : null;

  static List<String>? _tags(Object? value) => value is List<Object?>
      ? List<String>.unmodifiable(value.whereType<String>())
      : null;

  /// Both keys, well formed, or unknown: a count alone says nothing about
  /// where the clip can be cut.
  static ClipKeyframes? _keyframes(Object? frames, Object? indices) {
    if (frames is! int || indices is! List<Object?>) return null;
    if (indices.any((Object? index) => index is! int)) return null;
    return ClipKeyframes(
      frameCount: frames,
      indices: List<int>.unmodifiable(indices.cast<int>()),
    );
  }

  static ClipOrigin? _originOf(String? tag) =>
      tag == null ? null : ClipOrigin.fromComment('origin=$tag');
}
