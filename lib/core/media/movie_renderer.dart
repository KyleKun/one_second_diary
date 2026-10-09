import 'dart:io';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/commands/concat_command.dart';
import 'package:one_second_diary/core/media/commands/legacy_normalize_commands.dart';
import 'package:one_second_diary/core/media/commands/music_commands.dart';
import 'package:one_second_diary/core/media/commands/probe_commands.dart';
import 'package:one_second_diary/core/media/commands/subtitle_commands.dart';
import 'package:one_second_diary/core/media/commands/transition_commands.dart';
import 'package:one_second_diary/core/media/ffmpeg_runner.dart';
import 'package:one_second_diary/core/media/normalized_copy_cache.dart';
import 'package:one_second_diary/core/media/policy/clip_probe_parser.dart';
import 'package:one_second_diary/core/media/policy/concat_list.dart';
import 'package:one_second_diary/core/media/policy/ffmetadata_chapters.dart';
import 'package:one_second_diary/core/media/policy/keyframe_probe_parser.dart';
import 'package:one_second_diary/core/media/policy/movie_plan.dart';
import 'package:one_second_diary/core/media/policy/progress_math.dart';
import 'package:one_second_diary/core/media/policy/srt_codec.dart';
import 'package:one_second_diary/core/media/policy/transition_plan.dart';
import 'package:one_second_diary/core/media/policy/transition_policy.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/progress_throttle.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';
import 'package:one_second_diary/core/media/types/movie_clip.dart';
import 'package:one_second_diary/core/media/types/movie_music.dart';
import 'package:one_second_diary/core/media/types/movie_render_event.dart';
import 'package:one_second_diary/core/media/types/movie_render_request.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/ffmpeg_statistics.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

/// The whole movie pipeline of `MediaEngine.renderMovie`, run inside one
/// media job. Every clip joined is in the request's `ClipFormat`
///: one whose probed facts differ is normalised on a copy.
final class MovieRenderer {
  MovieRenderer({
    required this._runner,
    required this._cache,
    required this._paths,
    required this._logger,
    required this._clock,
  });

  static const String _tag = 'ffmpeg';

  final FfmpegRunner _runner;
  final NormalizedCopyCache _cache;
  final AppPaths _paths;
  final AppLogger _logger;
  final Clock _clock;

  /// Builds [request] using [job] (the job's scratch folder) for its temps
  /// and [encoder] (the one for the request's format) for every re-encode,
  /// reporting progress to [emit] at most 10 times a second, and returns
  /// the completion event.
  ///
  /// When it ends, however it ends, the normalised-copy cache is trimmed to
  /// its cap: no concat reads the copies any more.
  Future<MovieCompleted> render(
    MovieRenderRequest request, {
    required Directory job,
    required VideoEncoder encoder,
    required CancelToken cancelToken,
    required void Function(MovieRenderEvent event) emit,
  }) async {
    try {
      return await _render(
        request,
        job: job,
        encoder: encoder,
        cancelToken: cancelToken,
        emit: emit,
      );
    } finally {
      await _trimCache();
    }
  }

  Future<void> _trimCache() async {
    try {
      await _cache.trim();
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not trim the normalised copies',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<MovieCompleted> _render(
    MovieRenderRequest request, {
    required Directory job,
    required VideoEncoder encoder,
    required CancelToken cancelToken,
    required void Function(MovieRenderEvent event) emit,
  }) async {
    final ProgressThrottle throttle = ProgressThrottle(clock: _clock);
    void report(MovieRenderEvent event) {
      if (throttle.tryPass()) emit(event);
    }

    await _requireMusicFiles(request.music);
    final ClipFormat format = request.format;
    final int total = request.clips.length;
    final List<MovieClip> clips = <MovieClip>[];
    final List<String> inputs = <String>[];
    // The request's index of each clip joined, and of each clip left out.
    final List<int> joined = <int>[];
    final List<int> skipped = <int>[];
    final List<int> leftOutPrivate = <int>[];
    // Per clip joined, what the transition plan reads (empty without one).
    final List<({int? durationMs, ClipKeyframes? keyframes})> cutFacts =
        <({int? durationMs, ClipKeyframes? keyframes})>[];
    for (final (int index, MovieClip clip) in request.clips.indexed) {
      report(MoviePreparing(index: index, total: total));
      cancelToken.throwIfCancelled();
      try {
        final MovieClip known = await _withKnownFacts(
          clip,
          excludePrivate: request.excludePrivate,
        );
        String input = MoviePlan.needsNormalising(known, format: format)
            ? await _normalised(
                known,
                index: index,
                job: job,
                format: format,
                encoder: encoder,
                forTransition: request.transition != null,
                cancelToken: cancelToken,
              )
            : known.path;
        // With a transition, where this clip can be cut,
        // read in the same pass so the progress never runs backwards.
        if (request.transition != null) {
          final (:String path, :ClipKeyframes? keyframes) = await _cutFacts(
            known,
            input: input,
            index: index,
            request: request,
            job: job,
            encoder: encoder,
            cancelToken: cancelToken,
          );
          input = path;
          cutFacts.add((durationMs: known.durationMs, keyframes: keyframes));
        }
        clips.add(known);
        inputs.add(input);
        joined.add(index);
      } on _UnreadableClip catch (unreadable) {
        // One clip that cannot be read never costs the whole movie.
        _logger.warning(
          _tag,
          'Leaving ${clip.path} out of the movie: ${unreadable.why}',
        );
        skipped.add(index);
      } on _PrivateClip {
        _logger.info(
          _tag,
          'Leaving ${clip.path} out of the movie: its file says it is private',
        );
        leftOutPrivate.add(index);
      }
    }
    if (clips.length < 2) {
      throw NotEnoughClipsException(
        'Only ${clips.length} of $total clips can be read',
        skipped: skipped.length,
      );
    }
    // The cut facts were read before the first-clip subtitle fix, so an
    // older clip re-encoded for the transition is the file that fix copies.
    final TransitionPlan? plan = request.transition == null
        ? null
        : _planTransitions(cutFacts, clipCount: clips.length, fps: format.fps);
    if (MoviePlan.needsFirstClipSubtitles(clips, format: format)) {
      // A remux keeps every video packet, so the plan's keyframes hold.
      inputs[0] = await _withEmptySubtitles(
        inputs[0],
        job: job,
        cancelToken: cancelToken,
      );
    }
    final _Outcome outcome = (
      skipped: skipped,
      leftOutPrivate: leftOutPrivate,
      joined: joined,
    );
    if (plan != null && plan.transitionCount > 0) {
      return _joinWithTransitions(
        request,
        plan: plan,
        transition: request.transition!,
        clips: clips,
        inputs: inputs,
        outcome: outcome,
        job: job,
        encoder: encoder,
        cancelToken: cancelToken,
        report: report,
      );
    }
    return _join(
      request,
      clips: clips,
      inputs: inputs,
      outcome: outcome,
      hardCuts: plan == null ? 0 : plan.hardCuts,
      job: job,
      cancelToken: cancelToken,
      report: report,
    );
  }

  /// The stream-copy join of every version: the clips as they are, laid
  /// end to end, with the request's tags and one chapter per clip. With
  /// music the videos' own sound is made in one pass first
  /// (`TransitionCommands.audio`, plain joins) and the music mixed over
  /// it, and the concat takes both tracks; the join itself is the same.
  Future<MovieCompleted> _join(
    MovieRenderRequest request, {
    required List<MovieClip> clips,
    required List<String> inputs,
    required _Outcome outcome,
    required int hardCuts,
    required Directory job,
    required CancelToken cancelToken,
    required void Function(MovieRenderEvent event) report,
  }) async {
    final FrameRate fps = request.format.fps;
    final List<int> durations = <int>[
      for (final MovieClip clip in clips) clip.durationMs ?? 0,
    ];
    // One chapter per clip that made it, with a title, laid
    // end to end over the planned durations: the stream copy may land a
    // boundary a few milliseconds off the frame, which no player shows.
    // A clip left out above has no chapter. The file goes with the job's
    // folder like every other scratch file.
    final List<MovieChapter> chapters = _chaptersOf(clips, durations);
    final int totalMs = durations.fold(0, (int sum, int ms) => sum + ms);
    final MovieMusic? music = request.music;
    String? mix;
    String? clipsTrack;
    // Without music the concat alone reports its progress by time; with
    // it the audio passes come first and the work is counted in units.
    void Function(FfmpegStatistics statistics) onStatistics =
        (FfmpegStatistics statistics) {
          final (:double fraction, :int currentIndex) = ProgressMath.movie(
            timeMs: statistics.timeMs,
            clipDurationsMs: durations,
          );
          report(
            MovieConcatenating(
              fraction: fraction,
              currentIndex: outcome.joined[currentIndex],
            ),
          );
        };
    if (music != null) {
      // A plan of hard cuts alone: the audio pass reads each clip's length
      // from it and joins with `concat` everywhere.
      final TransitionPlan plain =
          TransitionPlan.of(<({int? durationMs, ClipKeyframes? keyframes})>[
            for (final MovieClip clip in clips)
              (durationMs: clip.durationMs, keyframes: null),
          ], fps: fps);
      final List<List<int>> chunks = _audioChunks(clips.length);
      final int audioPasses = chunks.length + (chunks.length > 1 ? 1 : 0);
      final int concatUnits = ProgressMath.concatUnitsFor(clips.length);
      final int totalUnits =
          audioPasses * ProgressMath.audioPassUnits +
          ProgressMath.musicUnits +
          concatUnits;
      double unitsDone = 0;
      void progress(int index) => report(
        MovieConcatenating(
          fraction: ProgressMath.transitionMovie(
            unitsDone: unitsDone,
            totalUnits: totalUnits,
          ),
          currentIndex: outcome.joined[index],
        ),
      );
      clipsTrack = await _audioTrack(
        plain,
        format: request.format,
        clips: clips,
        inputs: inputs,
        chunks: chunks,
        job: job,
        cancelToken: cancelToken,
        onPass: (int index) {
          unitsDone += ProgressMath.audioPassUnits;
          progress(index);
        },
      );
      mix = await _musicTrack(
        music,
        clips: clipsTrack,
        durationMs: totalMs,
        job: job,
        cancelToken: cancelToken,
        onStep: (int units) {
          unitsDone += units;
          progress(clips.length - 1);
        },
      );
      final double unitsBeforeConcat = unitsDone;
      onStatistics = (FfmpegStatistics statistics) {
        final (:double fraction, :int currentIndex) = ProgressMath.movie(
          timeMs: statistics.timeMs,
          clipDurationsMs: durations,
        );
        unitsDone = unitsBeforeConcat + concatUnits * fraction;
        progress(currentIndex);
      };
    }
    await _concat(
      request,
      list: ConcatList.content(inputs),
      chapters: chapters,
      audioPath: mix,
      secondAudioPath: clipsTrack,
      skipped: outcome.skipped,
      leftOutPrivate: outcome.leftOutPrivate,
      job: job,
      cancelToken: cancelToken,
      onStatistics: onStatistics,
    );
    return MovieCompleted(
      outputPath: request.outputPath,
      durationMs: totalMs,
      skipped: outcome.skipped,
      leftOutPrivate: outcome.leftOutPrivate,
      chapters: chapters,
      hardCuts: hardCuts,
    );
  }

  /// The plan of the request's transition over [facts] at [fps], logged.
  TransitionPlan _planTransitions(
    List<({int? durationMs, ClipKeyframes? keyframes})> facts, {
    required int clipCount,
    required FrameRate fps,
  }) {
    final TransitionPlan plan = TransitionPlan.of(facts, fps: fps);
    _logger.info(
      _tag,
      '${plan.transitionCount} transitions and ${plan.hardCuts} hard cuts '
      'planned for $clipCount clips',
    );
    return plan;
  }

  /// Where [clip] can be cut for the request's transition, and the file
  /// the movie takes it from: its keyframes come from the request when it
  /// knows them and [input] is the clip itself, else from one probe (a
  /// copy is always probed; a failed probe leaves the clip uncut, with
  /// hard cuts). With `upgradeOlderClips`, a clip that cannot be cut is
  /// re-encoded into a cut-able copy first (`_upgraded`), which replaces
  /// [input].
  Future<({String path, ClipKeyframes? keyframes})> _cutFacts(
    MovieClip clip, {
    required String input,
    required int index,
    required MovieRenderRequest request,
    required Directory job,
    required VideoEncoder encoder,
    required CancelToken cancelToken,
  }) async {
    final bool original = input == clip.path;
    ClipKeyframes? keyframes = original ? clip.keyframes : null;
    keyframes ??= await _keyframesOf(input);
    if (request.upgradeOlderClips &&
        original &&
        keyframes != null &&
        !TransitionPolicy.isReady(keyframes, fps: request.format.fps)) {
      input = await _upgraded(
        clip,
        index: index,
        job: job,
        format: request.format,
        encoder: encoder,
        cancelToken: cancelToken,
      );
      keyframes = await _keyframesOf(input);
    }
    return (path: input, keyframes: keyframes);
  }

  /// The join of a movie with at least one transition: the
  /// clips the plan cuts are stream-copied between their keyframes into
  /// body files (an uncut clip joins as it is), every transition is
  /// rendered from the frames outside those keyframes, the audio is made
  /// in one pass from the clips' own audio, and the concat takes the
  /// bodies and segments with exact `duration` lines, the audio track and
  /// the chapters at the fades' starts.
  Future<MovieCompleted> _joinWithTransitions(
    MovieRenderRequest request, {
    required TransitionPlan plan,
    required MovieTransition transition,
    required List<MovieClip> clips,
    required List<String> inputs,
    required _Outcome outcome,
    required Directory job,
    required VideoEncoder encoder,
    required CancelToken cancelToken,
    required void Function(MovieRenderEvent event) report,
  }) async {
    final ClipFormat format = request.format;
    final FrameRate fps = format.fps;
    final MovieMusic? music = request.music;
    final List<List<int>> chunks = _audioChunks(clips.length);
    final int audioPasses = chunks.length + (chunks.length > 1 ? 1 : 0);
    final int concatUnits = ProgressMath.concatUnitsFor(clips.length);
    final int totalUnits =
        plan.clips.where((PlannedClip clip) => clip.needsBody).length *
            ProgressMath.bodyUnits +
        plan.transitionCount * ProgressMath.segmentUnits +
        audioPasses * ProgressMath.audioPassUnits +
        (music == null ? 0 : ProgressMath.musicUnits) +
        concatUnits;
    double unitsDone = 0;
    void progress(int index) => report(
      MovieConcatenating(
        fraction: ProgressMath.transitionMovie(
          unitsDone: unitsDone,
          totalUnits: totalUnits,
        ),
        currentIndex: outcome.joined[index],
      ),
    );

    final String emptySubtitles = await _emptySubtitles(job);
    final List<String> files = <String>[];
    final List<String> durations = <String>[];
    for (final (int index, PlannedClip planned) in plan.clips.indexed) {
      cancelToken.throwIfCancelled();
      String file = inputs[index];
      if (planned.needsBody) {
        file = '${job.path}/body-$index.mp4';
        await _runner.execute(
          TransitionCommands.body(
            input: inputs[index],
            output: file,
            headCut: planned.headCut,
            tailCut: planned.tailCut,
            fps: fps,
          ),
          job: 'Body of ${clips[index].path}',
          output: file,
          cancelToken: cancelToken,
        );
        unitsDone += ProgressMath.bodyUnits;
        progress(index);
      }
      files.add(file);
      durations.add(_secondsOf(planned.bodyFrames, planned.durationMs, fps));
      if (!planned.transitionAfter) continue;
      final PlannedClip next = plan.clips[index + 1];
      final String segment = '${job.path}/segment-$index.mp4';
      _logger.info(
        _tag,
        'Rendering the ${transition.name} between ${clips[index].path} and '
        '${clips[index + 1].path} with ${encoder.ffmpegName}',
      );
      await _runner.execute(
        TransitionCommands.segment(
          before: inputs[index],
          beforeFrameCount: planned.frameCount!,
          beforeTailCut: planned.tailCut!,
          after: inputs[index + 1],
          afterHeadCut: next.headCut,
          emptySubtitles: emptySubtitles,
          transition: transition,
          format: format,
          encoder: encoder,
          output: segment,
        ),
        job: 'Transition after ${clips[index].path}',
        output: segment,
        cancelToken: cancelToken,
      );
      unitsDone += ProgressMath.segmentUnits;
      progress(index);
      files.add(segment);
      durations.add(
        TransitionPolicy.seconds(
          planned.tailFrames + next.headCut - TransitionPolicy.frames(fps),
          fps: fps,
        ),
      );
    }

    final String audio = await _audioTrack(
      plan,
      format: format,
      clips: clips,
      inputs: inputs,
      chunks: chunks,
      job: job,
      cancelToken: cancelToken,
      onPass: (int index) {
        unitsDone += ProgressMath.audioPassUnits;
        progress(index);
      },
    );

    // With music the mix is the first track and the
    // videos' own sound the second.
    final String? mix = music == null
        ? null
        : await _musicTrack(
            music,
            clips: audio,
            durationMs: plan.totalMs,
            job: job,
            cancelToken: cancelToken,
            onStep: (int units) {
              unitsDone += units;
              progress(clips.length - 1);
            },
          );
    final List<int> chapterDurations = plan.chapterDurationsMs;
    final List<MovieChapter> chapters = _chaptersOf(clips, chapterDurations);
    final double unitsBeforeConcat = unitsDone;
    await _concat(
      request,
      list: ConcatList.content(files, durations: durations),
      chapters: chapters,
      audioPath: mix ?? audio,
      secondAudioPath: mix == null ? null : audio,
      transition: transition,
      skipped: outcome.skipped,
      leftOutPrivate: outcome.leftOutPrivate,
      job: job,
      cancelToken: cancelToken,
      onStatistics: (FfmpegStatistics statistics) {
        final (:double fraction, :int currentIndex) = ProgressMath.movie(
          timeMs: statistics.timeMs,
          clipDurationsMs: chapterDurations,
        );
        unitsDone = unitsBeforeConcat + concatUnits * fraction;
        progress(currentIndex);
      },
    );
    return MovieCompleted(
      outputPath: request.outputPath,
      durationMs: plan.totalMs,
      skipped: outcome.skipped,
      leftOutPrivate: outcome.leftOutPrivate,
      chapters: chapters,
      transitions: plan.transitionCount,
      hardCuts: plan.hardCuts,
    );
  }

  /// The movie's audio track, `audio.m4a` in [job]'s folder: one pass over
  /// every clip, or one PCM pass per chunk of
  /// `TransitionPolicy.audioChunkClips` clips and a last pass over the
  /// chunks, joined the same way (`TransitionCommands.audio`), in
  /// [format]'s layout. [onPass] is told the index of the last clip of
  /// each pass that ended.
  Future<String> _audioTrack(
    TransitionPlan plan, {
    required ClipFormat format,
    required List<MovieClip> clips,
    required List<String> inputs,
    required List<List<int>> chunks,
    required Directory job,
    required CancelToken cancelToken,
    required void Function(int index) onPass,
  }) async {
    final FrameRate fps = format.fps;
    final String track = '${job.path}/audio.m4a';
    Future<void> pass(
      List<AudioInput> audioInputs,
      List<bool> crossfades,
      String output,
      int index,
    ) async {
      cancelToken.throwIfCancelled();
      await _runner.execute(
        TransitionCommands.audio(
          inputs: audioInputs,
          crossfades: crossfades,
          output: output,
          toAac: output == track,
          format: format,
        ),
        job: 'Audio of ${clips.length} clips',
        output: output,
        cancelToken: cancelToken,
      );
      onPass(index);
    }

    AudioInput inputOf(int index) => (
      path: inputs[index],
      seconds: _secondsOf(
        plan.clips[index].frameCount,
        plan.clips[index].durationMs,
        fps,
      ),
    );
    if (chunks.length == 1) {
      await pass(
        <AudioInput>[for (int i = 0; i < clips.length; i++) inputOf(i)],
        plan.transitions,
        track,
        clips.length - 1,
      );
      return track;
    }
    final List<AudioInput> chunkInputs = <AudioInput>[];
    for (final (int at, List<int> chunk) in chunks.indexed) {
      final String output = '${job.path}/audio-$at.wav';
      double seconds = 0;
      for (final int index in chunk) {
        seconds += _secondsValue(
          plan.clips[index].frameCount,
          plan.clips[index].durationMs,
          fps,
        );
        if (index != chunk.last && plan.isTransition(index)) {
          seconds -= TransitionPolicy.frames(fps) / fps.value;
        }
      }
      await pass(
        <AudioInput>[for (final int index in chunk) inputOf(index)],
        <bool>[
          for (final int index in chunk)
            if (index != chunk.last) plan.isTransition(index),
        ],
        output,
        chunk.last,
      );
      chunkInputs.add((path: output, seconds: seconds.toStringAsFixed(6)));
    }
    await pass(
      chunkInputs,
      <bool>[
        for (final List<int> chunk in chunks)
          if (chunk != chunks.last) plan.isTransition(chunk.last),
      ],
      track,
      clips.length - 1,
    );
    return track;
  }

  /// Fails the movie before any work when a music file is gone: the
  /// picker's copies live under scratch, which a launch sweeps.
  Future<void> _requireMusicFiles(MovieMusic? music) async {
    if (music == null) return;
    for (final String track in music.tracks) {
      if (!await File(track).exists()) {
        throw VideoProcessingException(
          'Music file not found: $track',
          returnCode: null,
          logTail: '',
        );
      }
    }
  }

  /// The movie's mixed audio track, `mix.m4a` in [job]'s folder (`MusicCommands`): [music]'s tracks joined (`sequence.wav`), repeated to
  /// [durationMs] (`loop.wav`) and mixed at its volume over [clips], the
  /// videos' own track, or alone when the music plays in its place
  /// (`MusicCommands`). [onStep] is told each step's units as it ends.
  Future<String> _musicTrack(
    MovieMusic music, {
    required String clips,
    required int durationMs,
    required Directory job,
    required CancelToken cancelToken,
    required void Function(int units) onStep,
  }) async {
    final String sequence = '${job.path}/sequence.wav';
    final String loop = '${job.path}/loop.wav';
    final String mix = '${job.path}/mix.m4a';
    _logger.info(
      _tag,
      'Mixing ${music.tracks.length} music tracks at '
      '${(music.volume * 100).round()}% '
      '${music.keepClipSound ? 'over' : 'in place of'} the videos\' sound',
    );
    cancelToken.throwIfCancelled();
    await _runner.execute(
      MusicCommands.sequence(tracks: music.tracks, output: sequence),
      job: 'Music sequence',
      output: sequence,
      cancelToken: cancelToken,
    );
    onStep(ProgressMath.musicSequenceUnits);
    await _runner.execute(
      MusicCommands.loop(
        sequence: sequence,
        durationMs: durationMs,
        output: loop,
      ),
      job: 'Music loop',
      output: loop,
      cancelToken: cancelToken,
    );
    onStep(ProgressMath.musicLoopUnits);
    await _runner.execute(
      MusicCommands.mix(
        music: loop,
        clips: music.keepClipSound ? clips : null,
        volume: music.volume,
        durationMs: durationMs,
        output: mix,
      ),
      job: 'Music mix',
      output: mix,
      cancelToken: cancelToken,
    );
    onStep(ProgressMath.musicMixUnits);
    return mix;
  }

  /// The clips' indices in runs of at most `TransitionPolicy.audioChunkClips`.
  static List<List<int>> _audioChunks(int count) => <List<int>>[
    for (
      int start = 0;
      start < count;
      start += TransitionPolicy.audioChunkClips
    )
      <int>[
        for (
          int index = start;
          index < count && index < start + TransitionPolicy.audioChunkClips;
          index++
        )
          index,
      ],
  ];

  /// [frames] at [fps] as seconds with 6 decimals, or [durationMs] when
  /// the frames are unknown; `0.000000` when neither is.
  static String _secondsOf(int? frames, int? durationMs, FrameRate fps) =>
      _secondsValue(frames, durationMs, fps).toStringAsFixed(6);

  static double _secondsValue(int? frames, int? durationMs, FrameRate fps) =>
      switch ((frames, durationMs)) {
        (final int frames, _) => frames / fps.value,
        (null, final int ms) => ms / 1000,
        (null, null) => 0,
      };

  /// The keyframes of the file at [path] from one probe; null, logged,
  /// when ffprobe cannot read them (the clip then joins with hard cuts).
  Future<ClipKeyframes?> _keyframesOf(String path) async {
    try {
      return KeyframeProbeParser.parse(
        await _runner.probe(
          ProbeCommands.keyframes(path),
          job: 'Keyframes of $path',
        ),
      );
    } on VideoProcessingException catch (error) {
      if (error.returnCode == null) rethrow;
      _logger.warning(_tag, 'Could not read the keyframes of $path');
      return null;
    }
  }

  /// One chapter per clip with a title, laid end to end over [durations].
  static List<MovieChapter> _chaptersOf(
    List<MovieClip> clips,
    List<int> durations,
  ) => FfmetadataChapters.boundaries(<({String? title, int durationMs})>[
    for (final (int at, MovieClip clip) in clips.indexed)
      (title: clip.chapterTitle, durationMs: durations[at]),
  ]);

  /// Runs the concat of [list] into the request's output with its tags,
  /// [chapters] (none writes no file) and [audioPath], deleting the
  /// partial movie when it fails.
  /// The movie's `description`: the request's, which counts every clip
  /// asked for, so with one left out (unreadable, or private to a request
  /// that leaves those out) the movie carries none (as older movies do);
  /// plus the [transition]'s part when the join made at least one
  /// (`MovieTransition.descriptionPart`), on its own when the count is
  /// dropped.
  static String? _description(
    MovieRenderRequest request, {
    required List<int> skipped,
    required List<int> leftOutPrivate,
    required MovieTransition? transition,
  }) {
    final String? counts = skipped.isEmpty && leftOutPrivate.isEmpty
        ? request.description
        : null;
    final String? part = transition?.descriptionPart;
    if (part == null) return counts;
    return counts == null ? part : '$counts;$part';
  }

  Future<void> _concat(
    MovieRenderRequest request, {
    required String list,
    required List<MovieChapter> chapters,
    required List<int> skipped,
    required List<int> leftOutPrivate,
    required Directory job,
    required CancelToken cancelToken,
    required void Function(FfmpegStatistics statistics) onStatistics,
    String? audioPath,
    String? secondAudioPath,
    MovieTransition? transition,
  }) async {
    final String listPath = '${job.path}/videos.txt';
    await File(listPath).writeAsString(list);
    String? chaptersPath;
    if (chapters.isNotEmpty) {
      chaptersPath = '${job.path}/${FfmetadataChapters.fileName}';
      await File(
        chaptersPath,
      ).writeAsString(FfmetadataChapters.encode(chapters));
    }
    // ffmpeg never creates the folder of its output. MovieBuilder renders
    // into a scratch folder of its own that does not exist yet; made here,
    // inside the job, so init()'s scratch sweep cannot remove it.
    await File(request.outputPath).parent.create(recursive: true);
    _logger.info(
      _tag,
      'Joining '
      '${request.clips.length - skipped.length - leftOutPrivate.length} '
      'clips into ${request.outputPath}',
    );
    try {
      await _runner.execute(
        ConcatCommand.build(
          listPath: listPath,
          outputPath: request.outputPath,
          fps: request.format.fps,
          title: request.title,
          comment: request.comment,
          description: _description(
            request,
            skipped: skipped,
            leftOutPrivate: leftOutPrivate,
            transition: transition,
          ),
          chaptersPath: chaptersPath,
          audioPath: audioPath,
          secondAudioPath: secondAudioPath,
        ),
        job: 'Movie ${request.outputPath}',
        output: request.outputPath,
        cancelToken: cancelToken,
        onStatistics: onStatistics,
      );
    } on Object {
      // The engine refused an existing output before the job, so whatever
      // is there now is this concat's partial movie.
      await _deleteIfThere(File(request.outputPath));
      rethrow;
    }
  }

  /// [clip] with its unknown facts read from one probe (a null fact means
  /// unknown; the engine probes once and never guesses).
  ///
  /// Throws an [_UnreadableClip] when ffprobe cannot open the file (cut
  /// short, no `moov` atom) or finds no video stream in it: the clip is left
  /// out. A probe that never ran (no return code) says nothing about the
  /// clip and fails the movie like any other step.
  ///
  /// With [excludePrivate], a probed clip whose file says it is private
  /// throws a [_PrivateClip]: nobody had read it, so nobody could leave it
  /// out before.
  Future<MovieClip> _withKnownFacts(
    MovieClip clip, {
    required bool excludePrivate,
  }) async {
    if (!MoviePlan.hasUnknownFacts(clip)) return clip;
    final String output;
    try {
      output = await _runner.probe(
        ProbeCommands.streams(clip.path),
        job: 'Probe of ${clip.path}',
      );
    } on VideoProcessingException catch (error) {
      if (error.returnCode == null) rethrow;
      throw const _UnreadableClip('ffprobe cannot open it');
    }
    final ClipProbe probe = ClipProbeParser.parse(output);
    if (excludePrivate && probe.isPrivate) throw const _PrivateClip();
    final MovieClip known = MoviePlan.withProbe(clip, probe: probe);
    if (!MoviePlan.hasVideo(known)) {
      throw const _UnreadableClip('it has no video stream');
    }
    return known;
  }

  /// The normalised copy of [clip] in [format], from the cache or made now
  /// in [job]'s folder, then kept. A failed step fails the movie; a copy
  /// without audio whose length nobody knows cannot get its silent track
  /// and is left out ([_UnreadableClip]).
  ///
  /// When the video differs (`MoviePlan.videoMatches`): steps A to F, as
  /// every version did (the canvas re-encode, a probe of the copy, the
  /// audio, the empty subtitle stream, the tags). When only the sound
  /// differs: steps C/D to F alone on the clip itself, the
  /// video copied, from the facts already known.
  ///
  /// The audio-only copy carries the clip's own keyframes, whatever they
  /// are (the video is stream-copied), so it is cached without the `-kf`
  /// promise; [forTransition], a clip whose own file
  /// lacks the cut keyframes goes through the full path instead, whose
  /// step A writes them, so the boundary beside it fades rather than
  /// cuts.
  Future<String> _normalised(
    MovieClip clip, {
    required int index,
    required Directory job,
    required ClipFormat format,
    required VideoEncoder encoder,
    required bool forTransition,
    required CancelToken cancelToken,
  }) async {
    final bool audioOnly =
        MoviePlan.videoMatches(clip, format) &&
        (!forTransition || await _canBeCut(clip, fps: format.fps));
    final String key = await _cacheKey(
      clip.path,
      format: format,
      keyframes: !audioOnly && clip.durationMs != null,
    );
    final String? cached = await _cache.lookup(key);
    if (cached != null) {
      _logger.verbose(_tag, 'Normalised copy of ${clip.path} from the cache');
      return cached;
    }
    final String name = 'Normalising ${clip.path}';
    final String copy = '${job.path}/normalize-$index.mp4';
    final String next = '${job.path}/normalize-$index-next.mp4';
    // Every step reads the last file written ([clip] itself for the first
    // of the audio-only path) and writes the next, which then replaces
    // the copy.
    String current = clip.path;
    Future<void> step(List<String> Function(String input) arguments) async {
      await _runner.execute(
        arguments(current),
        job: name,
        output: next,
        cancelToken: cancelToken,
      );
      await File(next).rename(copy);
      current = copy;
    }

    final bool hasAudio;
    final bool hasSubtitleStream;
    final int? durationMs;
    if (audioOnly) {
      _logger.info(_tag, '$name: the sound alone, the video copied');
      hasAudio = clip.hasAudio == true;
      hasSubtitleStream = clip.hasSubtitleStream == true;
      durationMs = clip.durationMs;
    } else {
      _logger.info(_tag, '$name into $format with ${encoder.ffmpegName}');
      // Step A writes the copy itself; B to F each read it and replace it.
      // The copy gets the cut keyframes when its length is
      // known (it is, after the probe), so a movie with transitions can
      // cut it like a saved clip.
      await _runner.execute(
        LegacyNormalizeCommands.canvas(
          source: clip.path,
          output: copy,
          format: format,
          encoder: encoder,
          durationMs: clip.durationMs,
          sourceColorTransfer: clip.colorTransfer,
        ),
        job: name,
        output: copy,
        cancelToken: cancelToken,
      );
      current = copy;
      final ClipProbe streams = ClipProbeParser.parse(
        await _runner.probe(ProbeCommands.streams(copy), job: name),
      );
      hasAudio = streams.hasAudio;
      hasSubtitleStream = streams.hasSubtitleStream;
      durationMs = streams.durationMs ?? clip.durationMs;
    }
    if (hasAudio) {
      await step(
        (String input) => LegacyNormalizeCommands.audio(
          input: input,
          output: next,
          format: format,
        ),
      );
    } else {
      if (durationMs == null || durationMs <= 0) {
        throw const _UnreadableClip('it has no audio and no known length');
      }
      final int length = durationMs;
      await step(
        (String input) => LegacyNormalizeCommands.silentAudio(
          input: input,
          output: next,
          durationMs: length,
          format: format,
        ),
      );
    }
    if (!hasSubtitleStream) {
      final String subtitles = await _emptySubtitles(job);
      await step(
        (String input) => LegacyNormalizeCommands.emptySubtitles(
          input: input,
          subtitles: subtitles,
          output: next,
        ),
      );
    }
    await step(
      (String input) => LegacyNormalizeCommands.tags(
        input: input,
        output: next,
        format: format,
      ),
    );
    return _cache.put(key: key, file: copy);
  }

  /// Whether [clip]'s own file has the cut keyframes at
  /// [fps]: from the request when it knows them, else from one probe. A
  /// file whose keyframes cannot be read cannot be cut.
  Future<bool> _canBeCut(MovieClip clip, {required FrameRate fps}) async {
    final ClipKeyframes? keyframes =
        clip.keyframes ?? await _keyframesOf(clip.path);
    return keyframes != null && TransitionPolicy.isReady(keyframes, fps: fps);
  }

  /// A copy of the clip [clip] (already in [format]) that a transition can
  /// cut: step A alone (the canvas re-encode with the keyframes,
  /// keeping its audio, subtitles and tags), from the cache
  /// or made now in [job]'s folder, then kept under the same key a
  /// normalised copy would have.
  Future<String> _upgraded(
    MovieClip clip, {
    required int index,
    required Directory job,
    required ClipFormat format,
    required VideoEncoder encoder,
    required CancelToken cancelToken,
  }) async {
    final String key = await _cacheKey(
      clip.path,
      format: format,
      keyframes: true,
    );
    final String? cached = await _cache.lookup(key);
    if (cached != null) {
      _logger.verbose(_tag, 'Cut-able copy of ${clip.path} from the cache');
      return cached;
    }
    _logger.info(
      _tag,
      'Re-encoding ${clip.path} for transitions with ${encoder.ffmpegName}',
    );
    final String copy = '${job.path}/upgrade-$index.mp4';
    await _runner.execute(
      LegacyNormalizeCommands.canvas(
        source: clip.path,
        output: copy,
        format: format,
        encoder: encoder,
        durationMs: clip.durationMs,
        sourceColorTransfer: clip.colorTransfer,
      ),
      job: 'Re-encoding ${clip.path} for transitions',
      output: copy,
      cancelToken: cancelToken,
    );
    return _cache.put(key: key, file: copy);
  }

  /// A stream copy of the clip at [path] in [job]'s folder with an empty
  /// subtitle stream (the placeholder cue), so the concat, which takes the
  /// FIRST clip's streams, keeps the later clips' subtitles. The subtitle
  /// remux keeps the clip's tags and marks the stream default, like any clip
  /// saved with text.
  Future<String> _withEmptySubtitles(
    String path, {
    required Directory job,
    required CancelToken cancelToken,
  }) async {
    final String output = '${job.path}/first-${path.split('/').last}';
    _logger.info(_tag, 'Adding an empty subtitle stream to a copy of $path');
    await _runner.execute(
      SubtitleCommands.remux(
        clip: path,
        subtitles: await _emptySubtitles(job),
        output: output,
      ),
      job: 'Subtitle stream for $path',
      output: output,
      cancelToken: cancelToken,
    );
    return output;
  }

  /// The cache key of the clip at [path]: its path relative to the videos
  /// folder (absolute paths change with the iOS container), size, time
  /// and the format it is normalised into.
  Future<String> _cacheKey(
    String path, {
    required ClipFormat format,
    required bool keyframes,
  }) async {
    final FileStat stat = await FileStat.stat(path);
    if (stat.type == FileSystemEntityType.notFound) {
      throw VideoProcessingException(
        'Clip not found: $path',
        returnCode: null,
        logTail: '',
      );
    }
    String relPath;
    try {
      relPath = _paths.relativeToVideos(path);
    } on ArgumentError {
      relPath = path;
    }
    return NormalizedCopyCache.keyFor(
      relPath: relPath,
      sizeBytes: stat.size,
      modified: stat.modified,
      format: format,
      keyframes: keyframes,
    );
  }

  static Future<void> _deleteIfThere(File file) async {
    try {
      await file.delete();
    } on PathNotFoundException {
      // Nothing written yet.
    }
  }

  /// The placeholder SRT (one empty cue), made once per movie in [job]'s
  /// folder.
  static Future<String> _emptySubtitles(Directory job) async {
    final File file = File('${job.path}/empty.srt');
    if (!await file.exists()) await file.writeAsString(SrtCodec.emptyCue);
    return file.path;
  }
}

/// A clip the movie is made without: [why] goes to the log.
final class _UnreadableClip implements Exception {
  const _UnreadableClip(this.why);

  final String why;
}

/// A clip the probe found private, in a movie that leaves those out.
final class _PrivateClip implements Exception {
  const _PrivateClip();
}

/// Which request indices made it into the movie and which were left out.
typedef _Outcome = ({
  List<int> skipped,
  List<int> leftOutPrivate,
  List<int> joined,
});
