import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/clip_renderer.dart';
import 'package:one_second_diary/core/media/commands/keywords_commands.dart';
import 'package:one_second_diary/core/media/commands/movie_audio_commands.dart';
import 'package:one_second_diary/core/media/commands/mute_commands.dart';
import 'package:one_second_diary/core/media/commands/privacy_commands.dart';
import 'package:one_second_diary/core/media/commands/probe_commands.dart';
import 'package:one_second_diary/core/media/commands/subtitle_commands.dart';
import 'package:one_second_diary/core/media/device_media_check.dart';
import 'package:one_second_diary/core/media/ffmpeg_runner.dart';
import 'package:one_second_diary/core/media/media_job_queue.dart';
import 'package:one_second_diary/core/media/movie_renderer.dart';
import 'package:one_second_diary/core/media/normalized_copy_cache.dart';
import 'package:one_second_diary/core/media/policy/clip_probe_parser.dart';
import 'package:one_second_diary/core/media/policy/encoder_catalog.dart';
import 'package:one_second_diary/core/media/policy/keyframe_probe_parser.dart';
import 'package:one_second_diary/core/media/policy/srt_codec.dart';
import 'package:one_second_diary/core/media/policy/stamp_font.dart';
import 'package:one_second_diary/core/media/stamp_font_store.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/device_media_check_result.dart';
import 'package:one_second_diary/core/media/types/movie_render_event.dart';
import 'package:one_second_diary/core/media/types/movie_render_request.dart';
import 'package:one_second_diary/core/media/types/rendered_clip.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/ffmpeg_gateway.dart';
import 'package:one_second_diary/core/platform/ffmpeg_result.dart';
import 'package:one_second_diary/core/platform/free_space_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/core/storage/storage_budget.dart';

/// Every ffmpeg/ffprobe job of the app.
///
/// Jobs run one at a time, in the order they were submitted (no priorities,
/// `MediaJobQueue`), each in its own scratch folder under
/// `AppPaths.scratchDir`, and never write into the gallery: callers publish
/// results through `MediaPublisher`. Every job waits for [init], so none
/// starts before the encoder probe. Failures throw
/// `VideoProcessingException`; cancellations throw `CancelledException`; no
/// partial output survives either.
///
/// A file a caller publishes (a rendered or remuxed clip) goes to its own
/// `out-*` folder, swept at the next launch if never published.
///
/// The engine holds no wakelock: the caller of a long job does
/// (`MovieJobBloc` around [renderMovie], through `WakelockGateway`).
///
/// Kept a plain (non-final, non-base) class so tests can use a
/// `FakeMediaEngine` that implements it.
class MediaEngine {
  /// [loadAsset] reads a bundled asset (`rootBundle.load` in the app), used to
  /// copy the stamp fonts from `assets/fonts/` into `AppPaths.fontsDir` under
  /// a versioned file name. [isIOS] picks the platform's encoder preference
  /// order and default (iOS VideoToolbox first, Android libx264 first).
  MediaEngine({
    required this._ffmpeg,
    required this._paths,
    required this._logger,
    required this._clock,
    required this._loadAsset,
    required this._isIOS,
    this._freeSpace,
  });

  final FfmpegGateway _ffmpeg;
  final AppPaths _paths;
  final AppLogger _logger;
  final Clock _clock;
  final Future<ByteData> Function(String assetKey) _loadAsset;
  final bool _isIOS;

  /// The phone's free space, which sizes the normalised-copy cache at each
  /// trim (`StorageBudget.normalizedCacheCap`); without it
  /// the cache keeps the budget's minimum.
  final FreeSpaceGateway? _freeSpace;

  static const String _tag = 'ffmpeg';

  late final MediaJobQueue _queue = MediaJobQueue(
    paths: _paths,
    logger: _logger,
  );
  late final FfmpegRunner _runner = FfmpegRunner(
    ffmpeg: _ffmpeg,
    logger: _logger,
  );
  late final StampFontStore _fonts = StampFontStore(
    paths: _paths,
    loadAsset: _loadAsset,
  );
  late final ClipRenderer _clips = ClipRenderer(
    ffmpeg: _ffmpeg,
    runner: _runner,
    fonts: _fonts,
    logger: _logger,
    clock: _clock,
  );

  late final MovieRenderer _movies = MovieRenderer(
    runner: _runner,
    cache: NormalizedCopyCache(
      directory: _paths.normalizedDir,
      capBytes: () async =>
          StorageBudget.normalizedCacheCap(await _freeSpace?.freeBytes()),
      clock: _clock,
    ),
    paths: _paths,
    logger: _logger,
    clock: _clock,
  );

  Future<void>? _ready;

  /// The encoders [init] found, one per format (`EncoderCatalog`).
  late EncoderCatalog _encoders;

  /// Probes the available video encoders (`-hide_banner -encoders`) into
  /// the catalogue that picks one per format and platform, and copies the
  /// stamp fonts. Started after the first frame; every job awaits it before
  /// running, so a job never starts with an unknown encoder.
  Future<void> init() => _ready ??= _initialize();

  /// Never throws: a job must not fail forever because of [init]. What
  /// fails here is retried or reported by the job that needs it (a missing
  /// font is copied again before each stamp).
  Future<void> _initialize() async {
    await _logFailure('Sweeping the scratch folder', _sweepScratch);
    _encoders = await _probeEncoders();
    await _logFailure('Copying the stamp fonts', () async {
      // The others (6 and 8 MB) are copied by the first clip that needs
      // them.
      await _fonts.install(StampFont.rubik);
      await _fonts.removeLegacyCopies();
    });
  }

  Future<void> _logFailure(String what, Future<void> Function() step) async {
    try {
      await step();
    } on Object catch (error, stackTrace) {
      _logger.error(_tag, '$what failed', error: error, stackTrace: stackTrace);
    }
  }

  /// The encoders of this ffmpeg build; the platform defaults when the
  /// probe fails.
  Future<EncoderCatalog> _probeEncoders() async {
    String listing = '';
    try {
      listing = await _ffmpeg.listEncoders();
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Encoder probe failed, using the platform default',
        error: error,
        stackTrace: stackTrace,
      );
    }
    final EncoderCatalog encoders = EncoderCatalog.of(listing, isIOS: _isIOS);
    _logger.info(
      _tag,
      'Encoding with ${encoders.legacyEncoder.ffmpegName}; HEVC with '
      '${encoders.hevcEncoder.ffmpegName}',
    );
    return encoders;
  }

  /// Runs [body] as one queued job, after [init], in its own scratch folder.
  ///
  /// Any other failure (a scratch file or font that could not be written,
  /// unreadable ffprobe output) becomes a [VideoProcessingException] without
  /// a return code; programming errors ([Error]) are left as they are.
  Future<T> _job<T>(String name, Future<T> Function(Directory job) body) async {
    await init();
    try {
      return await _queue.run(body);
    } on VideoProcessingException {
      rethrow;
    } on NotEnoughClipsException {
      rethrow;
    } on CancelledException {
      rethrow;
    } on Error {
      rethrow;
    } on Object catch (error, stackTrace) {
      _logger.error(_tag, '$name failed', error: error, stackTrace: stackTrace);
      Error.throwWithStackTrace(
        VideoProcessingException(
          '$name failed',
          returnCode: null,
          logTail: '',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  /// Writes [text] as one cue from 0 to [durationMs] into [job]'s folder.
  static Future<String> _writeSrt(
    Directory job,
    String text,
    int durationMs,
  ) async {
    final String path = '${job.path}/subtitles.srt';
    await File(
      path,
    ).writeAsString(SrtCodec.encode(text, startMs: 0, endMs: durationMs));
    return path;
  }

  /// A new folder in scratch for a file that outlives its job (a rendered or
  /// remuxed clip the caller publishes). Swept at the next launch.
  Future<Directory> _newOutputFolder() =>
      Directory(_paths.scratchDir).createTemp('out-');

  Future<void> _deleteFolder(Directory folder) async {
    try {
      await folder.delete(recursive: true);
    } on PathNotFoundException {
      // Never created.
    }
  }

  /// Deletes what an earlier launch left in `AppPaths.scratchDir` (its last
  /// job folder, renders never published). Runs before any job, since every
  /// job waits for [init].
  Future<void> _sweepScratch() async {
    final Directory scratch = Directory(_paths.scratchDir);
    try {
      await scratch.delete(recursive: true);
    } on PathNotFoundException {
      // First launch: nothing to sweep.
    }
    await scratch.create(recursive: true);
  }

  /// Renders [request] into a new file in private scratch, named
  /// `request.outputFileName`, and returns it. Never touches the gallery or
  /// an existing clip.
  ///
  /// [onProgress] receives the fraction done (0–1). Cancelling through
  /// [cancelToken] stops the session, deletes the partial file and throws a
  /// `CancelledException`.
  Future<RenderedClip> renderClip(
    ClipRenderRequest request, {
    CancelToken? cancelToken,
    void Function(double fraction)? onProgress,
  }) => _job('Saving ${request.outputFileName}', (Directory job) async {
    final Directory output = await _newOutputFolder();
    try {
      return await _clips.render(
        request,
        job: job,
        output: '${output.path}/${request.outputFileName}',
        encoder: _encoders.encoderFor(request.format),
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
    } on Object {
      await _deleteFolder(output);
      rethrow;
    }
  });

  /// Re-renders the finished day clip at [sourcePath] into [format] for
  /// the profile labelled [albumLabel] ("Convert into a new profile",
  /// `ConvertClipCommand`): a new file in private scratch
  /// named [outputFileName], returned like a save's. The original is never
  /// touched. [durationMs] is the clip's length (from its sidecar),
  /// [sourceChannels] its audio channel count when known (the audio is
  /// copied when it matches the format's, else re-encoded),
  /// [hasSubtitleStream] whether it carries subtitles (copied) and
  /// [sourceColorTransfer] its probed `color_transfer` (null: SDR), which
  /// decides the range conversion into the format (`RangeFilter`).
  ///
  /// [onProgress] receives the fraction done (0–1). Cancelling through
  /// [cancelToken] stops the session, deletes the partial file and throws a
  /// `CancelledException`.
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
  }) => _job('Converting $outputFileName', (Directory job) async {
    final Directory output = await _newOutputFolder();
    try {
      return await _clips.convert(
        sourcePath: sourcePath,
        outputFileName: outputFileName,
        output: '${output.path}/$outputFileName',
        format: format,
        encoder: _encoders.encoderFor(format),
        albumLabel: albumLabel,
        durationMs: durationMs,
        sourceChannels: sourceChannels,
        hasSubtitleStream: hasSubtitleStream,
        sourceColorTransfer: sourceColorTransfer,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
    } on Object {
      await _deleteFolder(output);
      rethrow;
    }
  });

  /// The ffmpeg half of the phone check (`DeviceMediaCheck`):
  /// one queued job that times a one-second
  /// encode of every candidate format in escalation order, stopping at the
  /// first that fails or runs under half real time, then the software
  /// decode of each of [decodeSamples] (bundled real-world recordings,
  /// copied to a readable path by the caller). Its temps go with the job.
  /// [onProgress] is told the tests done over the tests there would be at
  /// most; [onEncodeStart] and [onDecodeStart] each test as it starts,
  /// with its 0-based step over the run; [cancelToken] stops it between
  /// tests.
  Future<DeviceMediaCheckResult> checkDevice({
    required List<String> decodeSamples,
    CancelToken? cancelToken,
    void Function(int done, int total)? onProgress,
    void Function(int index, ClipFormat format)? onEncodeStart,
    void Function(int index, String sample)? onDecodeStart,
  }) => _job(
    'Phone check',
    (Directory job) =>
        DeviceMediaCheck(
          runner: _runner,
          encoders: _encoders,
          clock: _clock,
          logger: _logger,
        ).run(
          job: job,
          decodeSamples: decodeSamples,
          cancelToken: cancelToken,
          onProgress: onProgress,
          onEncodeStart: onEncodeStart,
          onDecodeStart: onDecodeStart,
        ),
  );

  /// ffprobe of the clip at [path] (streams, duration, size, tags).
  ///
  /// A probe is a queued job like any other. Background callers (the
  /// metadata backfill) await one probe at a time, so a user's save or movie
  /// never waits behind more than one of them.
  Future<ClipProbe> probe(String path) => _job(
    'Probe of $path',
    (Directory job) async => ClipProbeParser.parse(
      await _runner.probe(ProbeCommands.streams(path), job: 'Probe of $path'),
    ),
  );

  /// The frame count and keyframe positions of the clip at [path]
  /// (`ProbeCommands.keyframes`, no frame decoded), for movies with
  /// transitions. A queued job like [probe]; the metadata backfill fills
  /// the cache with it, so such a movie needs no probe of its own.
  Future<ClipKeyframes> probeKeyframes(String path) => _job(
    'Keyframes of $path',
    (Directory job) async => KeyframeProbeParser.parse(
      await _runner.probe(
        ProbeCommands.keyframes(path),
        job: 'Keyframes of $path',
      ),
    ),
  );

  /// The soft subtitle text of the clip at [path]; `''` when it has none.
  /// Never throws for a clip without a subtitle stream.
  ///
  /// The stream is extracted to an `.srt` in the job's own folder and
  /// decoded with `SrtCodec.decode`, which reads any cue times. The `.srt`
  /// output makes ffmpeg take only the subtitle stream, so the extraction
  /// FAILS for a clip without one: that failure means `''`.
  ///
  /// A session that got no answer from ffmpeg throws instead: a plugin error
  /// (no return code) as a `VideoProcessingException`, a cancel as a
  /// `CancelledException`. Returning `''` there would make the metadata
  /// backfill cache "no text" for a clip WITH subtitles until the clip
  /// changes; a throw makes it retry.
  Future<String> readSubtitles(String path) {
    final String name = 'Subtitles of $path';
    return _job(name, (Directory job) async {
      final String srt = '${job.path}/subtitles.srt';
      final FfmpegResult result = await _runner.attempt(
        SubtitleCommands.extract(clip: path, output: srt),
        job: name,
      );
      if (!result.success) {
        _logger.verbose(_tag, 'No subtitle stream in $path');
        return '';
      }
      return SrtCodec.decode(
        utf8.decode(await File(srt).readAsBytes(), allowMalformed: true),
      );
    });
  }

  /// Copies the clip at [clipPath] (stream copy, tags kept) into a new file
  /// in private scratch with the same file name, with [text] as its only
  /// subtitle cue spanning [durationMs]. An empty [text] removes the subtitle
  /// stream. Returns the new file's path; the original is not touched.
  ///
  /// Text with a [durationMs] below 1 is an [ArgumentError]: a zero-length
  /// cue never shows, so the text would be lost.
  Future<String> remuxSubtitles({
    required String clipPath,
    required String text,
    required int durationMs,
  }) async {
    if (text.isNotEmpty && durationMs < 1) {
      throw ArgumentError.value(durationMs, 'durationMs', 'must be positive');
    }
    final String fileName = PathNames.fileNameOf(clipPath);
    final String name = 'Subtitles of $fileName';
    return _job(name, (Directory job) async {
      final Directory folder = await _newOutputFolder();
      final String output = '${folder.path}/$fileName';
      try {
        await _runner.execute(
          text.isEmpty
              ? SubtitleCommands.remove(clip: clipPath, output: output)
              : SubtitleCommands.remux(
                  clip: clipPath,
                  subtitles: await _writeSrt(job, text, durationMs),
                  output: output,
                ),
          job: name,
          output: output,
        );
        return output;
      } on Object {
        await _deleteFolder(folder);
        rethrow;
      }
    });
  }

  /// Copies the clip at [clipPath] (stream copy, its streams and other tags
  /// kept) into a new file in private scratch with the same file name,
  /// marked private or, with [private] false, public (`ClipPrivacyTag`).
  /// Returns the new file's path; the original is not touched.
  Future<String> remuxPrivacy({
    required String clipPath,
    required bool private,
  }) {
    final String fileName = PathNames.fileNameOf(clipPath);
    final String name = 'Privacy of $fileName';
    return _job(name, (Directory job) async {
      final Directory folder = await _newOutputFolder();
      final String output = '${folder.path}/$fileName';
      try {
        await _runner.execute(
          PrivacyCommands.tag(clip: clipPath, output: output, private: private),
          job: name,
          output: output,
        );
        return output;
      } on Object {
        await _deleteFolder(folder);
        rethrow;
      }
    });
  }

  /// Copies the clip at [clipPath] into a new file in private scratch with
  /// the same file name, its sound replaced with silence [durationMs] long
  /// (`MuteCommands.silence`; video, subtitles and tags kept, the notes tag
  /// saying `muted=1` over [synopsis], the clip's own notes). The silent
  /// track is in [channels]'s layout: the profile's, mono
  /// unless given. Returns the new file's path; the original is not
  /// touched.
  Future<String> remuxMute({
    required String clipPath,
    required int durationMs,
    required String? synopsis,
    AudioChannels channels = AudioChannels.mono,
  }) {
    final String fileName = PathNames.fileNameOf(clipPath);
    final String name = 'Mute of $fileName';
    return _job(name, (Directory job) async {
      final Directory folder = await _newOutputFolder();
      final String output = '${folder.path}/$fileName';
      try {
        await _runner.execute(
          MuteCommands.silence(
            clip: clipPath,
            output: output,
            durationMs: durationMs,
            notes: MuteCommands.notesFor(synopsis),
            channels: channels,
          ),
          job: name,
          output: output,
        );
        return output;
      } on Object {
        await _deleteFolder(folder);
        rethrow;
      }
    });
  }

  /// Copies the movie at [moviePath] into a new file in private scratch
  /// with the same file name, its two audio tracks swapped so the other
  /// one plays (`MovieAudioCommands.swap`), with [description] as its
  /// `description` tag. Returns the new file's path; the original is not
  /// touched.
  Future<String> swapMovieAudio({
    required String moviePath,
    required String description,
  }) {
    final String fileName = PathNames.fileNameOf(moviePath);
    final String name = 'Audio swap of $fileName';
    return _job(name, (Directory job) async {
      final Directory folder = await _newOutputFolder();
      final String output = '${folder.path}/$fileName';
      try {
        await _runner.execute(
          MovieAudioCommands.swap(
            movie: moviePath,
            output: output,
            description: description,
          ),
          job: name,
          output: output,
        );
        return output;
      } on Object {
        await _deleteFolder(folder);
        rethrow;
      }
    });
  }

  /// Copies the clip at [clipPath] (stream copy, its streams and other tags
  /// kept) into a new file in private scratch with the same file name,
  /// with [tags] as its `keywords` tag (`KeywordsTag`; an empty list
  /// removes the tag). Returns the new file's path; the original is not
  /// touched.
  Future<String> remuxTags({
    required String clipPath,
    required List<String> tags,
  }) {
    final String fileName = PathNames.fileNameOf(clipPath);
    final String name = 'Tags of $fileName';
    return _job(name, (Directory job) async {
      final Directory folder = await _newOutputFolder();
      final String output = '${folder.path}/$fileName';
      try {
        await _runner.execute(
          KeywordsCommands.set(clip: clipPath, output: output, tags: tags),
          job: name,
          output: output,
        );
        return output;
      } on Object {
        await _deleteFolder(folder);
        rethrow;
      }
    });
  }

  /// Builds the movie described by [request] and writes it to
  /// `request.outputPath`. See [MovieRenderEvent] for the stream protocol.
  ///
  /// The whole pipeline lives here:
  /// - plans which clips need a normalised copy from the facts on each
  ///   `MovieClip`, probing once only the clips with an unknown (null) fact;
  /// - leaves out a clip ffprobe cannot open or that has no video stream
  ///   (`MovieCompleted.skipped`), and ends with a `NotEnoughClipsException`
  ///   when fewer than two are left;
  /// - keeps normalised copies in a capped LRU cache under
  ///   `AppPaths.normalizedDir`, keyed by the clip's path relative to
  ///   `AppPaths.videos` plus its size, modification time and the movie's
  ///   format, so a clip is re-encoded again only once its copy fell out
  ///   of the cap (10 % of the free space, 512 MiB to 8 GiB,
  ///   `StorageBudget.normalizedCacheCap`, `NormalizedCopyCache`);
  /// - remuxes a copy of the first clip when it has no subtitle stream and a
  ///   later clip has one (otherwise the concat drops every subtitle);
  /// - joins the clips with the concat demuxer and reports progress by
  ///   duration, at most 10 events per second.
  ///
  /// The stream ends with an `ArgumentError` (a caller bug, before any work)
  /// when [request] has fewer than two clips or `request.outputPath` already
  /// exists. Cancelling [cancelToken] or the stream subscription both stop
  /// the running session and delete the partial movie and the job's temps.
  Stream<MovieRenderEvent> renderMovie(
    MovieRenderRequest request, {
    CancelToken? cancelToken,
  }) {
    // One token for both ways to cancel: the caller's and the subscription.
    final CancelToken job = CancelToken();
    unawaited(cancelToken?.whenCancelled.then((_) => job.cancel()));
    Future<void>? running;
    bool started = false;
    // Closed by _runMovie when the job ends; never opened without a
    // listener.
    // ignore: close_sinks
    final StreamController<MovieRenderEvent> events =
        StreamController<MovieRenderEvent>();
    events
      ..onListen = () {
        running = _runMovie(
          request,
          token: job,
          events: events,
          onStart: () => started = true,
        );
      }
      ..onCancel = () {
        job.cancel();
        // A movie still waiting in the queue gives up when its turn comes.
        return started ? running : null;
      };
    return events.stream;
  }

  Future<void> _runMovie(
    MovieRenderRequest request, {
    required CancelToken token,
    required StreamController<MovieRenderEvent> events,
    required void Function() onStart,
  }) async {
    try {
      // Caller bugs, reported before any work (and before waiting in line).
      if (request.clips.length < 2) {
        throw ArgumentError.value(request.clips, 'clips', 'needs two or more');
      }
      if (await File(request.outputPath).exists()) {
        throw ArgumentError.value(
          request.outputPath,
          'outputPath',
          'already exists: movies are never overwritten',
        );
      }
      final MovieCompleted completed = await _job(
        'Movie ${request.outputPath}',
        (Directory job) {
          onStart();
          return _movies.render(
            request,
            job: job,
            encoder: _encoders.encoderFor(request.format),
            cancelToken: token,
            emit: events.add,
          );
        },
      );
      events.add(completed);
    } on Object catch (error, stackTrace) {
      events.addError(error, stackTrace);
    } finally {
      unawaited(events.close());
    }
  }
}
