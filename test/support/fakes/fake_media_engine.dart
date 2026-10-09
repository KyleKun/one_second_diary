import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/device_media_check.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/policy/ffmetadata_chapters.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/device_media_check_result.dart';
import 'package:one_second_diary/core/media/types/movie_clip.dart';
import 'package:one_second_diary/core/media/types/movie_render_event.dart';
import 'package:one_second_diary/core/media/types/movie_render_request.dart';
import 'package:one_second_diary/core/media/types/rendered_clip.dart';

import '../temp_storage.dart';

/// One call to [FakeMediaEngine.remuxSubtitles].
final class RemuxRequest extends Equatable {
  const RemuxRequest({
    required this.clipPath,
    required this.text,
    required this.durationMs,
  });

  final String clipPath;
  final String text;
  final int durationMs;

  @override
  List<Object?> get props => <Object?>[clipPath, text, durationMs];
}

/// One call to [FakeMediaEngine.convertClip].
final class ConvertRequest extends Equatable {
  const ConvertRequest({
    required this.sourcePath,
    required this.outputFileName,
    required this.format,
    required this.albumLabel,
    required this.durationMs,
    this.sourceColorTransfer,
  });

  final String sourcePath;
  final String outputFileName;
  final ClipFormat format;
  final String albumLabel;
  final int durationMs;
  final String? sourceColorTransfer;

  @override
  List<Object?> get props => <Object?>[
    sourcePath,
    outputFileName,
    format,
    albumLabel,
    durationMs,
    sourceColorTransfer,
  ];
}

/// A [MediaEngine] for tests of the code above it (clip library, movies,
/// editor). It runs no ffmpeg but writes real files, so publishing, Undo and
/// cleanup can be checked on disk.
///
/// - `renderClip` records the request, reports [progress], then throws the
///   next of [renderErrors] or writes `<scratchDir>/render-<n>/<outputFileName>`
///   and describes it (duration from the trim or photo length, canvas from
///   the orientation). A cancelled token throws [CancelledException].
/// - `probe` answers [probes] by path (anything else throws a
///   [VideoProcessingException]); [probedPaths] records every call.
/// - `readSubtitles` answers [subtitles] by path (`''` when missing).
/// - `remuxSubtitles` records a [RemuxRequest], throws [remuxError] when
///   set, else writes `<scratchDir>/remux-<n>/<clip file name>`.
/// - `remuxPrivacy` records the clip and the mark in [privacyRequests],
///   throws [privacyError] when set, else writes
///   `<scratchDir>/privacy-<n>/<clip file name>`.
/// - `remuxTags` records the clip and the tags in [tagRequests], throws
///   [tagError] when set, else writes `<scratchDir>/tags-<n>/<file name>`.
/// - `renderMovie` records the request and emits a [MoviePreparing] per
///   clip, one [MovieConcatenating] at 1.0 and a [MovieCompleted] (duration
///   = sum of the clips' `durationMs`; chapters laid end to end over the
///   clips not left out, one per clip with a `chapterTitle`, as the
///   engine's), writing the output file. Fewer than
///   two clips or an existing output end the stream with an
///   [ArgumentError]. With [holdMovie] it waits before
///   completing until [releaseMovie] or the token is cancelled; a cancel
///   ends the stream with a [CancelledException], [movieError] with that
///   error, and neither writes the output. Cancelling the subscription stops
///   it too (no output). For other timings (a cancel while preparing, live
///   fractions), subclass it.
class FakeMediaEngine extends Fake implements MediaEngine {
  FakeMediaEngine({required this.scratchDir});

  final String scratchDir;

  bool initialized = false;

  final List<ClipRenderRequest> renderRequests = <ClipRenderRequest>[];
  final Queue<Object> renderErrors = Queue<Object>();
  List<double> progress = const <double>[0.5, 1.0];

  final Map<String, ClipProbe> probes = <String, ClipProbe>{};
  final List<String> probedPaths = <String>[];

  /// `probeKeyframes` answers by path; a path without an entry throws a
  /// [VideoProcessingException]. [keyframesProbedPaths] records every call.
  final Map<String, ClipKeyframes> keyframes = <String, ClipKeyframes>{};
  final List<String> keyframesProbedPaths = <String>[];

  final Map<String, String> subtitles = <String, String>{};

  final List<RemuxRequest> remuxRequests = <RemuxRequest>[];
  Object? remuxError;

  /// Every `remuxMute` and `swapMovieAudio` call; [muteError] /
  /// [swapError] make the next one throw.
  final List<({String clipPath, int durationMs, String? synopsis})>
  muteRequests = <({String clipPath, int durationMs, String? synopsis})>[];

  /// The silent track's layout of each `remuxMute` call, in call order.
  final List<AudioChannels> muteChannels = <AudioChannels>[];
  Object? muteError;
  final List<({String moviePath, String description})> swapRequests =
      <({String moviePath, String description})>[];
  Object? swapError;

  final List<({String clipPath, bool private})> privacyRequests =
      <({String clipPath, bool private})>[];
  Object? privacyError;

  /// What `remuxPrivacy` throws for one path (null: nothing), asked when
  /// [privacyError] is null; for a clip whose source's remux fails.
  Object? Function(String clipPath)? privacyErrorFor;

  final List<({String clipPath, List<String> tags})> tagRequests =
      <({String clipPath, List<String> tags})>[];
  Object? tagError;

  final List<MovieRenderRequest> movieRequests = <MovieRenderRequest>[];
  Object? movieError;

  /// The clips (indexes into the request's) a movie is made without, as the
  /// engine leaves out those it cannot read.
  List<int> movieSkipped = const <int>[];

  /// The clips (indexes into the request's) a movie is made without
  /// because the engine's probe found them private.
  List<int> movieLeftOutPrivate = const <int>[];
  bool holdMovie = false;
  final Completer<void> _movieGate = Completer<void>();

  /// Lets a held movie complete.
  void releaseMovie() {
    if (!_movieGate.isCompleted) _movieGate.complete();
  }

  @override
  Future<void> init() async {
    initialized = true;
  }

  @override
  Future<RenderedClip> renderClip(
    ClipRenderRequest request, {
    CancelToken? cancelToken,
    void Function(double fraction)? onProgress,
  }) async {
    renderRequests.add(request);
    cancelToken?.throwIfCancelled();
    if (onProgress != null) progress.forEach(onProgress);
    if (renderErrors.isNotEmpty) throw renderErrors.removeFirst();
    final File file = await _write(
      'render-${renderRequests.length}',
      request.outputFileName,
    );
    return _rendered(
      file.path,
      format: request.format,
      durationMs: switch (request) {
        VideoRender(:final int trimStartMs, :final int trimEndMs) =>
          trimEndMs - trimStartMs,
        PhotoRender(:final double durationSeconds) =>
          (durationSeconds * 1000).round(),
      },
      hasSubtitleStream: request.subtitles.isNotEmpty,
    );
  }

  /// Every `convertClip` call; [convertErrors] are thrown in order.
  final List<ConvertRequest> convertRequests = <ConvertRequest>[];
  final Queue<Object> convertErrors = Queue<Object>();

  @override
  Future<RenderedClip> convertClip({
    required String sourcePath,
    required String outputFileName,
    required ClipFormat format,
    required String albumLabel,
    required int durationMs,
    required int? sourceChannels,
    required bool hasSubtitleStream,
    String? sourceColorTransfer,
    CancelToken? cancelToken,
    void Function(double fraction)? onProgress,
  }) async {
    convertRequests.add(
      ConvertRequest(
        sourcePath: sourcePath,
        outputFileName: outputFileName,
        format: format,
        albumLabel: albumLabel,
        durationMs: durationMs,
        sourceColorTransfer: sourceColorTransfer,
      ),
    );
    cancelToken?.throwIfCancelled();
    if (onProgress != null) progress.forEach(onProgress);
    if (convertErrors.isNotEmpty) throw convertErrors.removeFirst();
    final File file = await _write(
      'convert-${convertRequests.length}',
      outputFileName,
    );
    return _rendered(
      file.path,
      format: format,
      durationMs: durationMs,
      hasSubtitleStream: hasSubtitleStream,
    );
  }

  /// What `checkDevice` answers; every call's samples are recorded in
  /// [checkedSamples]. The default: every candidate at 2× real time with
  /// the platform's software encoder, every sample decoded at 1×.
  DeviceMediaCheckResult? deviceCheck;
  final List<List<String>> checkedSamples = <List<String>>[];

  @override
  Future<DeviceMediaCheckResult> checkDevice({
    required List<String> decodeSamples,
    CancelToken? cancelToken,
    void Function(int done, int total)? onProgress,
    void Function(int index, ClipFormat format)? onEncodeStart,
    void Function(int index, String sample)? onDecodeStart,
  }) async {
    checkedSamples.add(decodeSamples);
    cancelToken?.throwIfCancelled();
    for (final (int index, ClipFormat format)
        in DeviceMediaCheck.candidates.indexed) {
      onEncodeStart?.call(index, format);
    }
    for (final (int index, String sample) in decodeSamples.indexed) {
      onDecodeStart?.call(DeviceMediaCheck.candidates.length + index, sample);
    }
    final int total = DeviceMediaCheck.candidates.length + decodeSamples.length;
    onProgress?.call(total, total);
    return deviceCheck ??
        DeviceMediaCheckResult(
          encode: <EncodeTestResult>[
            for (final ClipFormat format in DeviceMediaCheck.candidates)
              EncodeTestResult(
                format: format,
                encoder: format.codec == VideoCodec.hevc
                    ? VideoEncoder.hevcMediaCodec
                    : VideoEncoder.libx264,
                ok: true,
                realtimeFactor: 2,
              ),
          ],
          decode: <DecodeTestResult>[
            for (final String sample in decodeSamples)
              DecodeTestResult(sample: sample, ok: true, realtimeFactor: 1),
          ],
        );
  }

  /// The facts of a clip rendered in [format], as the engine reports them
  /// without a probe (canvas, rate, layout, pixel format and schema from
  /// the format); whether it has audio is left unknown, as before.
  static RenderedClip _rendered(
    String path, {
    required ClipFormat format,
    required int durationMs,
    required bool hasSubtitleStream,
  }) => RenderedClip(
    tempPath: path,
    durationMs: durationMs,
    hasSubtitleStream: hasSubtitleStream,
    width: format.width,
    height: format.height,
    fps: format.fpsValue.toDouble(),
    channels: format.channelCount,
    pixelFormat: 'yuv420p',
    schema: format.isLegacy ? ClipSchema.v15 : ClipSchema.v2,
  );

  @override
  Future<ClipProbe> probe(String path) async {
    probedPaths.add(path);
    return probes[path] ??
        (throw VideoProcessingException(
          'No probe scripted for $path',
          returnCode: 1,
          logTail: '',
        ));
  }

  @override
  Future<ClipKeyframes> probeKeyframes(String path) async {
    keyframesProbedPaths.add(path);
    return keyframes[path] ??
        (throw VideoProcessingException(
          'No keyframe probe scripted for $path',
          returnCode: 1,
          logTail: '',
        ));
  }

  @override
  Future<String> readSubtitles(String path) async => subtitles[path] ?? '';

  @override
  Future<String> remuxSubtitles({
    required String clipPath,
    required String text,
    required int durationMs,
  }) async {
    remuxRequests.add(
      RemuxRequest(clipPath: clipPath, text: text, durationMs: durationMs),
    );
    final Object? error = remuxError;
    if (error != null) throw error;
    final File file = await _write(
      'remux-${remuxRequests.length}',
      clipPath.substring(clipPath.lastIndexOf('/') + 1),
    );
    return file.path;
  }

  @override
  Future<String> remuxPrivacy({
    required String clipPath,
    required bool private,
  }) async {
    privacyRequests.add((clipPath: clipPath, private: private));
    final Object? error = privacyError ?? privacyErrorFor?.call(clipPath);
    if (error != null) throw error;
    final File file = await _write(
      'privacy-${privacyRequests.length}',
      clipPath.substring(clipPath.lastIndexOf('/') + 1),
    );
    return file.path;
  }

  @override
  Future<String> remuxMute({
    required String clipPath,
    required int durationMs,
    required String? synopsis,
    AudioChannels channels = AudioChannels.mono,
  }) async {
    muteRequests.add((
      clipPath: clipPath,
      durationMs: durationMs,
      synopsis: synopsis,
    ));
    muteChannels.add(channels);
    final Object? error = muteError;
    if (error != null) throw error;
    final File file = await _write(
      'mute-${muteRequests.length}',
      clipPath.substring(clipPath.lastIndexOf('/') + 1),
    );
    return file.path;
  }

  @override
  Future<String> swapMovieAudio({
    required String moviePath,
    required String description,
  }) async {
    swapRequests.add((moviePath: moviePath, description: description));
    final Object? error = swapError;
    if (error != null) throw error;
    final File file = await _write(
      'swap-${swapRequests.length}',
      moviePath.substring(moviePath.lastIndexOf('/') + 1),
    );
    return file.path;
  }

  @override
  Future<String> remuxTags({
    required String clipPath,
    required List<String> tags,
  }) async {
    tagRequests.add((clipPath: clipPath, tags: tags));
    final Object? error = tagError;
    if (error != null) throw error;
    final File file = await _write(
      'tags-${tagRequests.length}',
      clipPath.substring(clipPath.lastIndexOf('/') + 1),
    );
    return file.path;
  }

  @override
  Stream<MovieRenderEvent> renderMovie(
    MovieRenderRequest request, {
    CancelToken? cancelToken,
  }) async* {
    movieRequests.add(request);
    if (request.clips.length < 2) {
      throw ArgumentError.value(request.clips, 'clips', 'needs two or more');
    }
    if (File(request.outputPath).existsSync()) {
      throw ArgumentError.value(request.outputPath, 'outputPath', 'exists');
    }
    final int total = request.clips.length;
    for (int index = 0; index < total; index++) {
      yield MoviePreparing(index: index, total: total);
    }
    yield MovieConcatenating(fraction: 1, currentIndex: total - 1);
    if (holdMovie) {
      await Future.any(<Future<void>>[
        _movieGate.future,
        if (cancelToken != null) cancelToken.whenCancelled,
      ]);
    }
    cancelToken?.throwIfCancelled();
    final Object? error = movieError;
    if (error != null) throw error;
    final File output = File(request.outputPath);
    await output.parent.create(recursive: true);
    await output.writeAsBytes(fakeVideoBytes);
    final List<MovieClip> joined = <MovieClip>[
      for (final (int index, MovieClip clip) in request.clips.indexed)
        if (!movieSkipped.contains(index) &&
            !movieLeftOutPrivate.contains(index))
          clip,
    ];
    yield MovieCompleted(
      outputPath: request.outputPath,
      durationMs: request.clips.fold(
        0,
        (int sum, MovieClip clip) => sum + (clip.durationMs ?? 0),
      ),
      skipped: movieSkipped,
      leftOutPrivate: movieLeftOutPrivate,
      // Every boundary gets the transition asked for.
      transitions: request.transition == null ? 0 : joined.length - 1,
      chapters:
          FfmetadataChapters.boundaries(<({String? title, int durationMs})>[
            for (final MovieClip clip in joined)
              (title: clip.chapterTitle, durationMs: clip.durationMs ?? 0),
          ]),
    );
  }

  Future<File> _write(String job, String fileName) async {
    final File file = File('$scratchDir/$job/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(fakeVideoBytes);
    return file;
  }
}
