import 'dart:convert';

import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';

/// Reads the output of `ProbeCommands.streams` (`ffprobe -v quiet
/// -print_format json -show_format -show_streams -show_chapters`) into a
/// [ClipProbe].
abstract final class ClipProbeParser {
  /// The probe of one file. Throws a [FormatException] when [json] is not
  /// ffprobe's JSON object.
  static ClipProbe parse(String json) {
    final Object? decoded = jsonDecode(json);
    if (decoded is! Map<String, Object?>) {
      throw FormatException('ffprobe output is not a JSON object', json);
    }
    final List<Map<String, Object?>> streams = <Map<String, Object?>>[
      if (decoded['streams'] case final List<Object?> list)
        ...list.whereType<Map<String, Object?>>(),
    ];
    final Map<String, Object?> format = switch (decoded['format']) {
      final Map<String, Object?> map => map,
      _ => const <String, Object?>{},
    };
    final Map<String, Object?>? video = streams
        .where((Map<String, Object?> s) => s['codec_type'] == 'video')
        .firstOrNull;
    final Map<String, Object?>? audio = streams
        .where((Map<String, Object?> s) => s['codec_type'] == 'audio')
        .firstOrNull;
    final Map<String, String> tags = _tags(format['tags']);
    return ClipProbe(
      durationMs: _milliseconds(format['duration']),
      hasAudio: streams.any(
        (Map<String, Object?> s) => s['codec_type'] == 'audio',
      ),
      hasSubtitleStream: streams.any(
        (Map<String, Object?> s) => s['codec_type'] == 'subtitle',
      ),
      artist: tags['artist'],
      album: tags['album'],
      comment: tags['comment'],
      locationTag: tags['location'],
      title: tags['title'],
      description: tags['description'],
      keywords: tags['keywords'],
      synopsis: tags['synopsis'],
      width: video?['width'] as int?,
      height: video?['height'] as int?,
      codec: video?['codec_name'] as String?,
      fps: _rate(video?['r_frame_rate']),
      channels: audio?['channels'] as int?,
      pixelFormat: video?['pix_fmt'] as String?,
      colorTransfer: video?['color_transfer'] as String?,
      chapters: _chapters(decoded['chapters']),
    );
  }

  /// The `chapters` list (`{"start_time": "0.000000", "end_time":
  /// "1.500000", "tags": {"title": …}}`, times in seconds as strings), in
  /// its order; one without both times is dropped, one without a title has
  /// an empty one. Empty without the key (a clip, an older movie).
  static List<MovieChapter> _chapters(Object? chapters) =>
      List<MovieChapter>.unmodifiable(<MovieChapter>[
        if (chapters case final List<Object?> list)
          for (final Map<String, Object?> chapter
              in list.whereType<Map<String, Object?>>())
            if ((
                  _milliseconds(chapter['start_time']),
                  _milliseconds(chapter['end_time']),
                )
                case (final int start, final int end))
              MovieChapter(
                startMs: start,
                endMs: end,
                title: _tags(chapter['tags'])['title'] ?? '',
              ),
      ]);

  static Map<String, String> _tags(Object? tags) => <String, String>{
    if (tags case final Map<String, Object?> map)
      for (final MapEntry<String, Object?>(:String key, :Object? value)
          in map.entries)
        if (value is String) key.toLowerCase(): value,
  };

  /// ffprobe prints durations as seconds in a string (`"1.533000"`).
  static int? _milliseconds(Object? seconds) => switch (seconds) {
    final String text => switch (double.tryParse(text)) {
      final double value => (value * 1000).round(),
      null => null,
    },
    _ => null,
  };

  /// A rational rate such as `"30/1"` or `"30000/1001"`; `"0/0"` is none.
  static double? _rate(Object? rate) {
    if (rate is! String) return null;
    final List<String> parts = rate.split('/');
    if (parts.length != 2) return null;
    final int? numerator = int.tryParse(parts[0]);
    final int? denominator = int.tryParse(parts[1]);
    if (numerator == null || denominator == null || denominator == 0) {
      return null;
    }
    return numerator == 0 ? null : numerator / denominator;
  }
}
