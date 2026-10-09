import 'package:one_second_diary/core/media/commands/clip_encoding.dart';
import 'package:one_second_diary/core/media/commands/save_clip_command.dart';
import 'package:one_second_diary/core/media/policy/canvas_filter.dart';
import 'package:one_second_diary/core/media/policy/encoder_catalog.dart';
import 'package:one_second_diary/core/media/policy/range_filter.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_origin.dart';

/// Normalises a clip for movies, steps A and C to F (step B is
/// `ProbeCommands.streams`).
///
/// A clip whose probed facts differ from the movie's format
/// (`MoviePlan.needsNormalising`: another codec, canvas, frame rate or
/// range, no audio, another layout) is copied into that format before a
/// stream-copy concat can take it; when only the sound differs, steps C/D
/// to F alone run on the clip itself (the video copied). The ORIGINAL is
/// never touched: every step reads one private copy and writes the next.
/// The result is kept in the normalised-copy cache.
abstract final class LegacyNormalizeCommands {
  /// Step A: re-encode the video into [format]'s canvas at its frame
  /// rate, keeping every stream (`-map 0`) and copying audio and
  /// subtitles. For the legacy format the argv is v1.7's (but for libx264's
  /// `-preset medium`); any other format also gets the output pixel format
  /// (`-pix_fmt yuv420p`, and `-tag:v hvc1` for HEVC) after the encoder's
  /// arguments.
  ///
  /// With [durationMs] (the clip's length, known after the engine's probe)
  /// the copy gets the keyframes a saved clip gets (`ClipEncoding.forcedKeyframes`), right
  /// after the encoder's arguments, so a movie with transitions can cut it; without, the argv is v1.7's.
  ///
  /// A clip whose range differs from the format's ([sourceColorTransfer],
  /// the clip's probed `color_transfer`; null is SDR) is converted in front
  /// of the canvas (`RangeFilter`): an HDR clip
  /// tone-mapped into an SDR movie (the chain ends in `format=yuv420p`,
  /// so the legacy argv, which names no pixel format, still gets 8-bit
  /// frames), an SDR clip raised into an HLG one. SDR into
  /// SDR is the argv above, byte for byte.
  static List<String> canvas({
    required String source,
    required String output,
    required ClipFormat format,
    required VideoEncoder encoder,
    int? durationMs,
    String? sourceColorTransfer,
  }) => <String>[
    '-i',
    source,
    '-vf',
    RangeFilter.prefixed(
      format,
      sourceColorTransfer: sourceColorTransfer,
      chain: CanvasFilter.scaleFilter(format),
    ),
    '-r',
    '${format.fpsValue}',
    '-map',
    '0',
    ...EncoderCatalog.argumentsFor(encoder, format),
    if (!format.isLegacy) ...ClipEncoding.outputPixelFormat(format),
    if (durationMs != null)
      ...ClipEncoding.forcedKeyframes(durationMs, fps: format.fps),
    '-c:a',
    'copy',
    '-c:s',
    'copy',
    output,
    '-y',
  ];

  /// Step C, for a copy with audio: re-encode it to 48 kHz AAC 256k in
  /// [format]'s layout (`-ac 1` for the legacy format, v1.7's argv),
  /// copying the rest.
  static List<String> audio({
    required String input,
    required String output,
    required ClipFormat format,
  }) => <String>[
    '-i',
    input,
    '-map',
    '0',
    '-c:v',
    'copy',
    '-c:a',
    'aac',
    '-ac',
    '${format.channelCount}',
    '-ar',
    '48000',
    '-b:a',
    '256k',
    '-c:s',
    'copy',
    output,
    '-y',
  ];

  /// Step D, for a copy without audio: add a silent 48 kHz AAC track in
  /// [format]'s layout [durationMs] long, the length of the copy (the
  /// concat needs audio in every clip).
  ///
  /// The silence is cut with `-t`, never `-shortest`: a clip saved by an
  /// older version carries a 1 ms placeholder subtitle, and `-shortest`
  /// would end the copy there, leaving it without video. `-map 0 -map 1:a`
  /// keeps every stream of the copy and takes the audio from the silence.
  static List<String> silentAudio({
    required String input,
    required String output,
    required int durationMs,
    required ClipFormat format,
  }) => <String>[
    '-i',
    input,
    ...ClipEncoding.silentAudioInputOf(format.channels, durationMs: durationMs),
    '-map',
    '0',
    '-map',
    '1:a',
    '-b:a',
    '256k',
    '-c:v',
    'copy',
    '-c:s',
    'copy',
    '-c:a',
    'aac',
    output,
    '-y',
  ];

  /// Step E, for a copy without subtitles: add an empty `mov_text` stream
  /// from [subtitles] (the placeholder cue, `SrtCodec.emptyCue`), so every
  /// clip of the concat has the same stream layout.
  static List<String> emptySubtitles({
    required String input,
    required String subtitles,
    required String output,
  }) => <String>[
    '-i',
    input,
    '-i',
    subtitles,
    '-c',
    'copy',
    '-c:s',
    'mov_text',
    output,
    '-y',
  ];

  /// Step F: tag the copy with the schema marker of [format]
  /// (`SaveClipCommand.artistOf`: `v1.5` for the legacy format only, `v2`
  /// otherwise), album `Default` (whatever the
  /// profile) and origin `osd_recording_old`.
  static List<String> tags({
    required String input,
    required String output,
    required ClipFormat format,
  }) => <String>[
    '-i',
    input,
    '-metadata',
    'artist=${SaveClipCommand.artistOf(format)}',
    '-metadata',
    'album=Default',
    '-metadata',
    'comment=${ClipOrigin.osdRecordingOld.comment}',
    '-c:v',
    'copy',
    '-c:a',
    'copy',
    '-c:s',
    'copy',
    output,
    '-y',
  ];
}
