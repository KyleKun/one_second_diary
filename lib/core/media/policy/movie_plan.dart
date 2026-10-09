import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/color_transfer.dart';
import 'package:one_second_diary/core/media/types/movie_clip.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

/// Which clips of a movie need work before the stream-copy concat, decided
/// from each `MovieClip`'s facts against the movie's `ClipFormat`
///. The facts decide, never the artist marker: a tag can
/// lie after a remux by another tool.
abstract final class MoviePlan {
  /// Whether a fact the plan (or the progress) needs is unknown (null), so
  /// the engine probes the clip once before planning. Callers fill the facts
  /// from the metadata cache, so a movie of backfilled clips needs no probe.
  /// The channel count is needed only of a clip with audio; the pixel
  /// format and colour transfer are compared when known ([videoMatches]).
  static bool hasUnknownFacts(MovieClip clip) =>
      clip.durationMs == null ||
      clip.hasAudio == null ||
      clip.hasSubtitleStream == null ||
      clip.width == null ||
      clip.height == null ||
      clip.codec == null ||
      clip.fps == null ||
      (clip.hasAudio == true && clip.channels == null);

  /// [clip] with its unknown facts taken from [probe]; the facts it already
  /// knows are kept.
  static MovieClip withProbe(MovieClip clip, {required ClipProbe probe}) =>
      MovieClip(
        path: clip.path,
        durationMs: clip.durationMs ?? probe.durationMs,
        isOsdV15: clip.isOsdV15 ?? probe.isOsdV15,
        hasAudio: clip.hasAudio ?? probe.hasAudio,
        hasSubtitleStream: clip.hasSubtitleStream ?? probe.hasSubtitleStream,
        width: clip.width ?? probe.width,
        height: clip.height ?? probe.height,
        codec: clip.codec ?? probe.codec,
        chapterTitle: clip.chapterTitle,
        keyframes: clip.keyframes,
        fps: clip.fps ?? probe.fps,
        channels: clip.channels ?? probe.channels,
        pixelFormat: clip.pixelFormat ?? probe.pixelFormat,
        colorTransfer: clip.colorTransfer ?? probe.colorTransfer,
        schema: clip.schema ?? probe.schema,
      );

  /// Whether [clip] has a video stream, asked once its facts are known:
  /// ffprobe gives every video stream a size and a codec, so a clip with
  /// none of them (an audio-only file, a file cut short) has no picture. It
  /// is left out of the movie: it cannot be normalised, and joined as it is
  /// it would misplace every clip after it.
  static bool hasVideo(MovieClip clip) =>
      clip.width != null || clip.height != null || clip.codec != null;

  /// The colour transfers ffprobe reports for HDR video
  /// HLG and PQ (`ColorTransfer.hdr`).
  static const Set<String> hdrTransfers = ColorTransfer.hdr;

  /// Whether a stream whose `color_transfer` is [colorTransfer] is HDR. Null
  /// (not reported, as most SDR phone recordings leave it) is SDR.
  static bool isHdr(String? colorTransfer) =>
      ColorTransfer.isHdr(colorTransfer);

  /// The pixel format every clip of [format] has.
  static String pixelFormatOf(ClipFormat format) => switch (format.range) {
    DynamicRange.sdr => 'yuv420p',
    DynamicRange.hlg => 'yuv420p10le',
  };

  /// Whether [clip]'s video stream can be stream-copied into a movie of
  /// [format]: the same codec, canvas, frame rate (within a hundredth),
  /// dynamic range (an SDR movie takes any non-HDR transfer, an HLG movie
  /// takes HLG alone: a PQ clip is HDR but not HLG) and, when known, pixel
  /// format. A fact still unknown (null) counts as a mismatch: after the
  /// engine's one probe, an unknown value cannot be trusted for a stream
  /// copy.
  static bool videoMatches(MovieClip clip, ClipFormat format) {
    final double? fps = clip.fps;
    final String? pixelFormat = clip.pixelFormat;
    final bool rangeMatches = switch (format.range) {
      DynamicRange.sdr => !isHdr(clip.colorTransfer),
      DynamicRange.hlg => clip.colorTransfer == ColorTransfer.hlg,
    };
    return clip.codec == format.codec.token &&
        clip.width == format.width &&
        clip.height == format.height &&
        fps != null &&
        (fps - format.fpsValue).abs() < 0.01 &&
        (pixelFormat == null || pixelFormat == pixelFormatOf(format)) &&
        rangeMatches;
  }

  /// Whether [clip]'s audio can be stream-copied into a movie of [format]:
  /// it has an audio stream in the format's layout. Unknown is a mismatch.
  static bool audioMatches(MovieClip clip, ClipFormat format) =>
      clip.hasAudio == true && clip.channels == format.channelCount;

  /// Whether [clip] is joined through a normalised copy
  /// (`LegacyNormalizeCommands`) instead of as it is: when its video
  /// ([videoMatches]) or its audio ([audioMatches]) differs from [format].
  /// Only the sound differing takes the cheaper audio-only path (the video
  /// copied, the audio re-encoded or added).
  ///
  /// [orientation] names the legacy format on that canvas, as an alternative to [format].
  static bool needsNormalising(
    MovieClip clip, {
    ClipFormat? format,
    VideoOrientation? orientation,
  }) {
    final ClipFormat target = _target(format, orientation);
    // A foreign clip (no schema marker: an import nobody processed) is
    // always normalised on a copy: the
    // compared facts cannot see rotation side data, parameter sets or the
    // audio sample rate, any of which breaks a raw concat. Our own clips
    // go by the facts alone: a lying tag never forces a raw join.
    if (clip.schema == ClipSchema.other) return true;
    return !videoMatches(clip, target) || !audioMatches(clip, target);
  }

  /// Whether the first of [clips] is joined through a copy with an (empty)
  /// subtitle stream: it has none and a later clip has one.
  ///
  /// The concat demuxer takes the FIRST clip's stream layout, so without it
  /// every later clip's subtitles are silently dropped (a clip saved without
  /// text has no subtitle stream). A first clip that is normalised already
  /// gets an empty stream from `LegacyNormalizeCommands.emptySubtitles`.
  static bool needsFirstClipSubtitles(
    List<MovieClip> clips, {
    ClipFormat? format,
    VideoOrientation? orientation,
  }) {
    if (clips.isEmpty) return false;
    final ClipFormat target = _target(format, orientation);
    final MovieClip first = clips.first;
    return first.hasSubtitleStream != true &&
        !needsNormalising(first, format: target) &&
        clips.skip(1).any((MovieClip clip) => clip.hasSubtitleStream == true);
  }

  static ClipFormat _target(ClipFormat? format, VideoOrientation? orientation) {
    if (format != null) return format;
    if (orientation != null) return ClipFormat.legacy(orientation);
    throw ArgumentError('a format (or the legacy orientation) is needed');
  }
}
