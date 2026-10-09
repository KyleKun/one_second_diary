import 'package:one_second_diary/core/media/commands/clip_encoding.dart';
import 'package:one_second_diary/core/media/commands/save_clip_command.dart';
import 'package:one_second_diary/core/media/policy/canvas_filter.dart';
import 'package:one_second_diary/core/media/policy/range_filter.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';

/// One clip of a profile re-rendered into another profile's format
/// ("Convert into a new profile").
///
/// The clip is already a finished day clip (stamped, trimmed), so nothing
/// is cut or stamped again: it is scaled to the new canvas as a save fits
/// a source (pad or cover by orientation, `CanvasFilter.scaleFilter`; the
/// burned stamp scales along, so a 1080p clip's 40 px stamp is 80 px in
/// 4K, matching new clips), every stream kept (`-map 0`), the video at the
/// format's frame rate with its encoder and output pixel format
/// (`ClipEncoding.videoEncodeSettings`), the forced keyframes a save gets, its audio copied unless the channel layout differs
/// (then re-encoded into the format's), its subtitles copied (`-c:s
/// copy`), and its tags copied (`-map_metadata 0`: origin, location,
/// description, keywords, synopsis) with the `artist` (the marker of the
/// new format) and the `album` rewritten. The original is never
/// touched. A clip whose range differs from the new
/// format's is converted in front of the canvas (`RangeFilter`: an
/// SDR profile into an HLG one, an HLG profile into an SDR one).
abstract final class ConvertClipCommand {
  /// The argv that converts the clip at [source] into [output] in
  /// [format] for the profile whose `album` label is [albumLabel].
  /// [durationMs] is the clip's length (from its sidecar); [sourceChannels]
  /// its audio channel count, null when unknown (the audio is then
  /// re-encoded, which is always safe); [sourceColorTransfer] its probed
  /// `color_transfer` (from the sidecar), null for SDR.
  static List<String> build({
    required String source,
    required String output,
    required ClipFormat format,
    required VideoEncoder encoder,
    required String albumLabel,
    required int durationMs,
    required int? sourceChannels,
    String? sourceColorTransfer,
  }) => <String>[
    '-i',
    source,
    '-map_metadata',
    '0',
    '-metadata',
    'artist=${SaveClipCommand.artistOf(format)}',
    '-metadata',
    'album=$albumLabel',
    '-vf',
    RangeFilter.prefixed(
      format,
      sourceColorTransfer: sourceColorTransfer,
      chain: CanvasFilter.scaleFilter(format),
    ),
    '-map',
    '0',
    ...ClipEncoding.videoEncodeSettings(format, encoder),
    ...ClipEncoding.forcedKeyframes(durationMs, fps: format.fps),
    if (sourceChannels == format.channelCount) ...<String>['-c:a', 'copy'] else
      ...ClipEncoding.audioSettings(format.channels),
    '-c:s',
    'copy',
    output,
    '-y',
  ];
}
