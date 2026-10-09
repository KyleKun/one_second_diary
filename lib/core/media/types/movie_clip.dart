import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';

/// One clip of a movie: where it is now and the facts the media engine plans
/// the movie from.
///
/// The caller (`MovieBuilder`) fills the facts from the clip metadata cache
/// (`ClipMeta`), so a movie of cached clips needs no probe. A null fact
/// means UNKNOWN: the engine probes that clip once before planning and never
/// guesses a value.
///
/// The plan reads the facts, never the marker
/// (`MoviePlan.videoMatches` and `audioMatches`): [codec], [width],
/// [height], [fps], [channels], [pixelFormat] and [colorTransfer] against
/// the movie's `ClipFormat`. [isOsdV15] and [schema] say what the artist
/// tag marks and are carried for the callers (the "Imported" badge and
/// the confirmation count).
final class MovieClip extends Equatable {
  const MovieClip({
    required this.path,
    required this.durationMs,
    required this.isOsdV15,
    required this.hasAudio,
    required this.hasSubtitleStream,
    required this.width,
    required this.height,
    required this.codec,
    this.chapterTitle,
    this.keyframes,
    this.fps,
    this.channels,
    this.pixelFormat,
    this.colorTransfer,
    this.schema,
  });

  /// Absolute path for this launch (the clip's real path, sub-folders
  /// included).
  final String path;

  /// Container duration, for progress and the movie's length.
  final int? durationMs;

  /// The artist tag carries the schema marker (`osdArtist`). False means a
  /// normalised copy is used.
  final bool? isOsdV15;

  /// Has an audio stream. False means a normalised copy (the concat needs
  /// audio in every clip).
  final bool? hasAudio;

  /// Has a soft subtitle stream (decides the first-clip subtitle fix).
  final bool? hasSubtitleStream;

  /// Video size; a clip that is not the movie's canvas is normalised.
  final int? width;
  final int? height;

  /// Video codec as ffprobe names it (`h264`); anything else is normalised.
  final String? codec;

  /// The title of the chapter this clip becomes in the movie
  /// (`FfmetadataChapters`); null writes no chapter for it.
  /// A request where every clip has null writes no chapters file and
  /// joins exactly as before.
  final String? chapterTitle;

  /// Where the clip can be cut without re-encoding, for a movie with
  /// transitions; null when unknown (the engine probes it then, only for
  /// such a movie). Ignored by a movie without transitions.
  final ClipKeyframes? keyframes;

  /// The clip's frame rate, audio channel count, pixel format, colour
  /// transfer and schema, from the cache; null when unknown.
  final double? fps;
  final int? channels;
  final String? pixelFormat;
  final String? colorTransfer;
  final ClipSchema? schema;

  @override
  List<Object?> get props => <Object?>[
    path,
    durationMs,
    isOsdV15,
    hasAudio,
    hasSubtitleStream,
    width,
    height,
    codec,
    chapterTitle,
    keyframes,
    fps,
    channels,
    pixelFormat,
    colorTransfer,
    schema,
  ];
}
