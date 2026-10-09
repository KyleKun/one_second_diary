import 'dart:convert';
import 'dart:io';

import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// The sidecar a conversion keeps in the NEW profile's folder, so a killed app
/// resumes where it stopped and a cancel keeps what was converted:
///
/// ```json
/// {"version": 1, "source": "Work", "format": "2160p60-hevc-stereo-sdr",
///  "done": ["Profiles/Work/2024-01-05.mp4", ...]}
/// ```
///
/// `done` lists the SOURCE clips converted (paths relative to the videos
/// folder, never absolute). The file is deleted when the run completes.
final class ConversionManifest {
  const ConversionManifest({
    required this.source,
    required this.format,
    required this.done,
  });

  static const int version = 1;

  /// The file name inside the new profile's folder: dotted, so the clip
  /// scanner (which only takes clip names) and the Files app's eye pass
  /// over it.
  static const String fileName = '.osd-conversion.json';

  /// The source profile.
  final ProfileKey source;

  /// The target format (its canonical string; the orientation is the
  /// target profile's).
  final String format;

  /// The source clips converted, by relPath, in order.
  final List<String> done;

  /// The manifest at [path], or null when there is none or it is not a
  /// manifest of this version (a run then starts over, never overwriting a
  /// clip already there: `ClipStore.saveAt` replaces, so that is safe).
  static Future<ConversionManifest?> read(String path) async {
    try {
      return decode(await File(path).readAsString());
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Writes this manifest at [path] atomically (a temp renamed over it).
  Future<void> write(String path) async {
    final File temp = File('$path.tmp');
    await temp.parent.create(recursive: true);
    await temp.writeAsString(encode(), flush: true);
    await temp.rename(path);
  }

  ConversionManifest withDone(String relPath) => ConversionManifest(
    source: source,
    format: format,
    done: List<String>.unmodifiable(<String>[...done, relPath]),
  );

  /// Whether this manifest describes a run of [source] into [format].
  bool matches({required ProfileKey source, required ClipFormat format}) =>
      this.source == source && this.format == format.toString();

  String encode() => jsonEncode(<String, Object?>{
    'version': version,
    'source': source.value,
    'format': format,
    'done': done,
  });

  /// Throws a [FormatException] for anything that is not a manifest.
  static ConversionManifest decode(String json) {
    final Object? root = jsonDecode(json);
    if (root is! Map<String, Object?> || root['version'] != version) {
      throw const FormatException('Not a conversion manifest of version 1');
    }
    final Object? source = root['source'];
    final Object? format = root['format'];
    final Object? done = root['done'];
    if (source is! String || format is! String || done is! List<Object?>) {
      throw const FormatException('A conversion manifest field is missing');
    }
    if (ClipFormat.parse(format, VideoOrientation.landscape) == null) {
      throw FormatException('Unknown format "$format"');
    }
    return ConversionManifest(
      source: ProfileKey(source),
      format: format,
      done: List<String>.unmodifiable(done.whereType<String>()),
    );
  }
}
