import 'dart:io';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/commands/clip_render_files.dart';
import 'package:one_second_diary/core/media/commands/convert_clip_command.dart';
import 'package:one_second_diary/core/media/commands/probe_commands.dart';
import 'package:one_second_diary/core/media/commands/save_clip_command.dart';
import 'package:one_second_diary/core/media/ffmpeg_runner.dart';
import 'package:one_second_diary/core/media/policy/keyframe_probe_parser.dart';
import 'package:one_second_diary/core/media/policy/movie_plan.dart';
import 'package:one_second_diary/core/media/policy/progress_math.dart';
import 'package:one_second_diary/core/media/policy/srt_codec.dart';
import 'package:one_second_diary/core/media/policy/stamp_font_policy.dart';
import 'package:one_second_diary/core/media/policy/stamp_text_files.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/progress_throttle.dart';
import 'package:one_second_diary/core/media/stamp_font_store.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/color_transfer.dart';
import 'package:one_second_diary/core/media/types/rendered_clip.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/ffmpeg_gateway.dart';
import 'package:one_second_diary/core/platform/ffmpeg_statistics.dart';

/// Turns a video or a photo into a day clip, or a day clip into one of
/// another format, inside one media job.
final class ClipRenderer {
  ClipRenderer({
    required this._ffmpeg,
    required this._runner,
    required this._fonts,
    required this._logger,
    required this._clock,
  });

  static const String _tag = 'ffmpeg';

  final FfmpegGateway _ffmpeg;
  final FfmpegRunner _runner;
  final StampFontStore _fonts;
  final AppLogger _logger;
  final Clock _clock;

  /// Renders [request] with [encoder] (the one for its format) into
  /// [output] (a file named `request.outputFileName`), writing its text
  /// files into [job], the job's own scratch folder.
  ///
  /// [onProgress] gets the fraction done from the session's statistics, at
  /// most 10 times a second.
  Future<RenderedClip> render(
    ClipRenderRequest request, {
    required Directory job,
    required String output,
    required VideoEncoder encoder,
    CancelToken? cancelToken,
    void Function(double fraction)? onProgress,
  }) async {
    final ClipRenderFiles files = await _prepareFiles(
      request,
      job: job,
      output: output,
    );
    // The render may fail on some devices without it.
    await _ffmpeg.setFontDirectory(files.font);
    // A request saved without sound gets a silent track whatever the
    // source has: no probe before, none after.
    final bool? sourceHasAudio = switch (request) {
      VideoRender() when !request.mute => await _galleryVideoHasAudio(request),
      VideoRender() || PhotoRender() => null,
    };
    final List<String> arguments = switch (request) {
      VideoRender() => SaveClipCommand.video(
        request,
        files: files,
        encoder: encoder,
        addSilentAudio: sourceHasAudio == false,
      ),
      PhotoRender() => SaveClipCommand.photo(
        request,
        files: files,
        encoder: encoder,
      ),
    };
    _logger.info(
      _tag,
      'Saving ${request.outputFileName} as ${request.format} with '
      '${encoder.ffmpegName}',
    );
    _logger.verbose(_tag, 'Arguments: $arguments');
    await _runner.execute(
      arguments,
      job: 'Saving ${request.outputFileName}',
      output: output,
      cancelToken: cancelToken,
      onStatistics: onProgress == null
          ? null
          : _progress(request, ProgressThrottle(clock: _clock), onProgress),
    );
    return _renderedClip(
      request.format,
      output: output,
      durationMs: switch (request) {
        VideoRender(:final int trimStartMs, :final int trimEndMs) =>
          trimEndMs - trimStartMs,
        PhotoRender(:final double durationSeconds) =>
          (durationSeconds * 1000).round(),
      },
      hasSubtitleStream: request.subtitles.isNotEmpty,
      hasAudio: switch (request) {
        // A photo always gets a silent track; so does a silent gallery
        // video, and one with audio keeps it.
        PhotoRender() => true,
        VideoRender() when request.mute || sourceHasAudio != null => true,
        VideoRender() => await _clipHasAudio(request.outputFileName, output),
      },
      keyframes: await _clipKeyframes(request.outputFileName, output),
    );
  }

  /// Re-renders the finished day clip at [sourcePath] into [format] for
  /// the profile labelled [albumLabel] (`ConvertClipCommand`), into
  /// [output] (named [outputFileName]), with [encoder] (the one for the
  /// format). [durationMs] is the clip's length and [sourceChannels] its
  /// audio channel count when known (null re-encodes the audio);
  /// [hasSubtitleStream] whether it carries subtitles (copied);
  /// [sourceColorTransfer] its probed `color_transfer` (null: SDR), which
  /// decides the range conversion (`RangeFilter`).
  Future<RenderedClip> convert({
    required String sourcePath,
    required String outputFileName,
    required String output,
    required ClipFormat format,
    required VideoEncoder encoder,
    required String albumLabel,
    required int durationMs,
    required int? sourceChannels,
    required bool hasSubtitleStream,
    String? sourceColorTransfer,
    CancelToken? cancelToken,
    void Function(double fraction)? onProgress,
  }) async {
    final List<String> arguments = ConvertClipCommand.build(
      source: sourcePath,
      output: output,
      format: format,
      encoder: encoder,
      albumLabel: albumLabel,
      durationMs: durationMs,
      sourceChannels: sourceChannels,
      sourceColorTransfer: sourceColorTransfer,
    );
    _logger.info(
      _tag,
      'Converting $outputFileName into $format with ${encoder.ffmpegName}',
    );
    _logger.verbose(_tag, 'Arguments: $arguments');
    final ProgressThrottle throttle = ProgressThrottle(clock: _clock);
    await _runner.execute(
      arguments,
      job: 'Converting $outputFileName',
      output: output,
      cancelToken: cancelToken,
      onStatistics: onProgress == null
          ? null
          : (FfmpegStatistics statistics) {
              final double? fraction = ProgressMath.saveVideo(
                timeMs: statistics.timeMs,
                trimStartMs: 0,
                trimEndMs: durationMs,
              );
              if (fraction != null && throttle.tryPass()) onProgress(fraction);
            },
    );
    return _renderedClip(
      format,
      output: output,
      durationMs: durationMs,
      hasSubtitleStream: hasSubtitleStream,
      // Every day clip the app saved has a track, but a foreign clip in the
      // profile (an import not processed yet) may have none, and the
      // concat drops a whole movie's audio over one such clip: read the
      // output once, as a save does, so the cached fact says the truth.
      hasAudio: await _clipHasAudio(outputFileName, output),
      keyframes: await _clipKeyframes(outputFileName, output),
    );
  }

  /// The stamp font, installed, and the text files the save command reads
  /// (SRT, date, place), written into [job].
  Future<ClipRenderFiles> _prepareFiles(
    ClipRenderRequest request, {
    required Directory job,
    required String output,
  }) async {
    final ClipRenderFiles files = ClipRenderFiles(
      subtitles: '${job.path}/subtitles.srt',
      font: await _fonts.install(
        StampFontPolicy.forTexts(<String>[
          request.stampText,
          if (request.location.enabled) ?request.location.text,
        ], legacy: request.legacyStampFont),
      ),
      dateText: '${job.path}/date.txt',
      locationText: '${job.path}/location.txt',
      output: output,
    );
    await File(files.subtitles).writeAsString(_srt(request));
    await File(
      files.dateText,
    ).writeAsString(StampTextFiles.date(request.stampText));
    // Only read by the place drawtext, which exists with geotagging on.
    if (request.location.enabled) {
      await File(
        files.locationText,
      ).writeAsString(StampTextFiles.location(request.location.text));
    }
    return files;
  }

  /// What the engine knows of a clip rendered in [format] into [output],
  /// without probing it: the canvas, the frame rate, the audio layout, the
  /// pixel format and the schema marker all follow from the format
  ///; so does the colour transfer: HLG for an HLG format
  /// (`ClipEncoding.outputPixelFormat` tags it), untagged (SDR) otherwise.
  static RenderedClip _renderedClip(
    ClipFormat format, {
    required String output,
    required int durationMs,
    required bool hasSubtitleStream,
    required bool? hasAudio,
    required ClipKeyframes? keyframes,
  }) => RenderedClip(
    tempPath: output,
    durationMs: durationMs,
    hasSubtitleStream: hasSubtitleStream,
    width: format.width,
    height: format.height,
    hasAudio: hasAudio,
    keyframes: keyframes,
    fps: format.fpsValue.toDouble(),
    channels: format.channelCount,
    pixelFormat: MoviePlan.pixelFormatOf(format),
    colorTransfer: format.isHdr ? ColorTransfer.hlg : null,
    schema: format.isLegacy ? ClipSchema.v15 : ClipSchema.v2,
  );

  /// Maps statistics to the fraction done of [request], passing [throttle].
  static void Function(FfmpegStatistics) _progress(
    ClipRenderRequest request,
    ProgressThrottle throttle,
    void Function(double fraction) onProgress,
  ) => (FfmpegStatistics statistics) {
    final double? fraction = switch (request) {
      VideoRender(:final int trimStartMs, :final int trimEndMs) =>
        ProgressMath.saveVideo(
          timeMs: statistics.timeMs,
          trimStartMs: trimStartMs,
          trimEndMs: trimEndMs,
        ),
      PhotoRender(:final double durationSeconds) => ProgressMath.savePhoto(
        timeMs: statistics.timeMs,
        durationSeconds: durationSeconds,
      ),
    };
    if (fraction != null && throttle.tryPass()) onProgress(fraction);
  };

  /// Whether the source of gallery video [request] has an audio stream; a
  /// silent one (a screen recording) then gets a silent track. Null when
  /// unknown.
  ///
  /// Recordings are never probed (`-map 1:a?` keeps a recording without
  /// audio working), and a failed probe adds nothing.
  Future<bool?> _galleryVideoHasAudio(VideoRender request) async {
    if (request.fromRecording) return null;
    try {
      final String output = await _runner.probe(
        ProbeCommands.audioStream(request.sourcePath),
        job: 'Audio probe of ${request.outputFileName}',
      );
      return output.trim().isNotEmpty;
    } on VideoProcessingException {
      return null;
    }
  }

  /// Whether the file [output] rendered as [outputFileName] has an audio
  /// stream; null when the probe failed. One short probe of the new clip,
  /// so its cached facts say the truth and a movie needs no probe of its
  /// own.
  Future<bool?> _clipHasAudio(String outputFileName, String output) async {
    try {
      final String probed = await _runner.probe(
        ProbeCommands.audioStream(output),
        job: 'Audio probe of the saved $outputFileName',
      );
      return probed.trim().isNotEmpty;
    } on VideoProcessingException {
      return null;
    }
  }

  /// The frame count and keyframes of the file [output] rendered as
  /// [outputFileName] (`ProbeCommands.keyframes`, no frame decoded): the
  /// save asked for one 333 ms from each end, and the probe
  /// says where they really are, so a movie with transitions needs no
  /// probe of its own. Null when the probe failed or read no packet (a
  /// clip has frames; an empty answer says nothing and is never cached as
  /// a fact).
  Future<ClipKeyframes?> _clipKeyframes(
    String outputFileName,
    String output,
  ) async {
    try {
      final ClipKeyframes keyframes = KeyframeProbeParser.parse(
        await _runner.probe(
          ProbeCommands.keyframes(output),
          job: 'Keyframe probe of the saved $outputFileName',
        ),
      );
      return keyframes.frameCount == 0 ? null : keyframes;
    } on VideoProcessingException {
      _logger.verbose(_tag, 'Could not read the keyframes of $outputFileName');
      return null;
    }
  }

  /// The SRT muxed as input 0.
  static String _srt(ClipRenderRequest request) => switch (request) {
    VideoRender(:final String subtitles) when subtitles.isEmpty =>
      SrtCodec.emptyCue,
    VideoRender(
      :final String subtitles,
      :final int trimStartMs,
      :final int trimEndMs,
    ) =>
      SrtCodec.encode(subtitles, startMs: trimStartMs, endMs: trimEndMs),
    PhotoRender(:final String subtitles, :final double durationSeconds) =>
      SrtCodec.encode(
        subtitles,
        startMs: 0,
        endMs: (durationSeconds * 1000).round(),
      ),
  };
}
