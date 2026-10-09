import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';

/// A clip the media engine finished rendering into its private scratch
/// folder, ready to publish. The file name equals the request's
/// `outputFileName`.
final class RenderedClip extends Equatable {
  const RenderedClip({
    required this.tempPath,
    required this.durationMs,
    required this.hasSubtitleStream,
    required this.width,
    required this.height,
    this.hasAudio,
    this.keyframes,
    this.fps,
    this.channels,
    this.pixelFormat,
    this.colorTransfer,
    this.schema,
  });

  /// Absolute path of the rendered file in scratch. The caller publishes it
  /// (which moves it) or deletes it.
  final String tempPath;

  final int durationMs;
  final bool hasSubtitleStream;

  /// The profile canvas (`ClipFormat.width` × `height`).
  final int width;
  final int height;

  /// Whether the clip has an audio stream; null when the engine could not
  /// tell (a movie then probes the clip once).
  ///
  /// Not always true: the save keeps a recording's own audio with
  /// `-map 1:a?` and never probes recordings, so a recording made without a
  /// microphone stays silent. A movie must normalise such a clip, or the
  /// concat drops the audio of the whole movie.
  final bool? hasAudio;

  /// The frame count and keyframes the engine probed after the render
  /// (`ProbeCommands.keyframes`); null when the probe failed (a movie with
  /// transitions then probes the clip once).
  final ClipKeyframes? keyframes;

  /// The facts of the format the clip was rendered in:
  /// frame rate, audio channels, pixel format (`yuv420p`), colour transfer
  /// and the schema its artist tag marks. Null when the engine did not
  /// say (an older caller): the facts are then read by a probe.
  final double? fps;
  final int? channels;
  final String? pixelFormat;
  final String? colorTransfer;
  final ClipSchema? schema;

  @override
  List<Object?> get props => <Object?>[
    tempPath,
    durationMs,
    hasSubtitleStream,
    width,
    height,
    hasAudio,
    keyframes,
    fps,
    channels,
    pixelFormat,
    colorTransfer,
    schema,
  ];
}
