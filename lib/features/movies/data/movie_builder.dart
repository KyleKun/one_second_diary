import 'dart:async';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/movie_chapter.dart';
import 'package:one_second_diary/core/media/types/movie_clip.dart';
import 'package:one_second_diary/core/media/types/movie_music.dart';
import 'package:one_second_diary/core/media/types/movie_render_event.dart';
import 'package:one_second_diary/core/media/types/movie_render_request.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/movies/data/movie_repository.dart';
import 'package:one_second_diary/features/movies/domain/chapter_title.dart';
import 'package:one_second_diary/features/movies/domain/movie_build_event.dart';
import 'package:one_second_diary/features/movies/domain/movie_clip_facts.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/domain/movie_selection.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/domain/movie_tags.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Makes a movie: the shell around `MediaEngine.renderMovie`.
class MovieBuilder {
  MovieBuilder({
    required this._engine,
    required this._clips,
    required this._metadata,
    required this._movies,
    required this._publisher,
    required this._paths,
    required this._clock,
    required this._logger,
  });

  final MediaEngine _engine;
  final ClipRepository _clips;
  final ClipMetadataCache _metadata;
  final MovieRepository _movies;
  final MediaPublisher _publisher;
  final AppPaths _paths;
  final Clock _clock;
  final AppLogger _logger;

  static const String _tag = 'CREATE MOVIE';

  /// Makes a movie of [source] from [profile]'s clips in [format], the
  /// profile's write-once format (`ProfilesRepository.formatOf`): its canvas,
  /// and what the engine normalises a clip that differs into, so a movie of a
  /// 4K60 HEVC profile is a stream copy of its clips.
  Stream<MovieBuildEvent> build({
    required MovieSource source,
    required ProfileKey profile,
    required ClipFormat format,
    required String title,
    bool includePrivate = false,
    MovieTransition? transition,
    bool upgradeOlderClips = false,
    MovieMusic? music,
    CancelToken? cancelToken,
  }) {
    // Not an async* generator: one waiting inside `await for` never sees
    // its subscription cancelled, so the engine's session would run on.
    final CancelToken token = cancelToken ?? CancelToken();
    final StreamController<MovieBuildEvent> events =
        StreamController<MovieBuildEvent>();
    Future<void>? running;
    events
      ..onListen = () async {
        final Future<void> work = _build(
          source: source,
          profile: profile,
          format: format,
          title: title,
          includePrivate: includePrivate,
          transition: transition,
          upgradeOlderClips: upgradeOlderClips,
          music: music,
          token: token,
          emit: events.add,
        );
        running = work;
        try {
          await work;
        } on Object catch (error, stackTrace) {
          events.addError(error, stackTrace);
        }
        await events.close();
      }
      ..onCancel = () {
        token.cancel();
        // The cancel completes once the job's files are gone.
        return running?.then<void>((_) {}, onError: (Object _) {});
      };
    return events.stream;
  }

  Future<void> _build({
    required MovieSource source,
    required ProfileKey profile,
    required ClipFormat format,
    required String title,
    required bool includePrivate,
    required MovieTransition? transition,
    required bool upgradeOlderClips,
    required MovieMusic? music,
    required CancelToken token,
    required void Function(MovieBuildEvent event) emit,
  }) async {
    final LocalDay today = LocalDay.fromDateTime(_clock.now());
    final ClipIndex index =
        _clips.snapshotOf(profile) ?? await _clips.rescan(profile);
    final List<ClipRef> refs = index.clipsFor(
      source,
      today: today,
      includePrivate: includePrivate,
    );
    // Clips picked by hand are taken as picked, private or not.
    final bool excludePrivate = !includePrivate && source is! CustomMovieSource;
    final TagFilter tags = switch (source) {
      RangedMovieSource(:final TagFilter tags) => tags,
      CustomMovieSource() => TagFilter.none,
    };
    if (refs.length < 2) {
      _logger.warning(
        _tag,
        'Insufficient videos to create movie. Videos: ${_names(refs)}',
      );
      throw ArgumentError.value(refs, 'source', 'needs two or more clips');
    }
    final String fileName = await _movies.nextFreeFileName(today);
    final String job =
        '${_paths.scratchDir}/movie-${_clock.now().microsecondsSinceEpoch}';
    final MovieRenderRequest request = MovieRenderRequest(
      clips: _movieClipsOf(index, refs),
      format: format,
      outputPath: '$job/$fileName',
      title: title,
      comment: 'profile=${profile.value}',
      description: MovieTags.describe(
        clips: refs.length,
        from: refs.first.day,
        to: refs.last.day,
        privateClips: refs.where(index.isPrivate).length,
        tags: tags.anyOf,
        without: tags.noneOf,
        withMusic: music != null,
      ),
      excludePrivate: excludePrivate,
      transition: transition,
      upgradeOlderClips: upgradeOlderClips,
      music: music,
    );
    final String saved = '${PathNames.moviesFolder}/$fileName';
    // The wording the owner reads in bug reports.
    _logger
      ..info(
        _tag,
        source is CustomMovieSource
            ? 'Creating movie with the following custom selected videos: '
                  '${_names(refs)}'
            : 'Creating movie in range ${_rangeOf(source)}'
                  '${tags.isEmpty ? '' : ' (tags: ${tags.anyOf.join(', ')}; '
                            'without: ${tags.noneOf.join(', ')})'} with the '
                  'following videos: ${_names(refs)}',
      )
      ..info(_tag, 'Base videos folder: ${_paths.profileVideos(profile)}')
      ..info(_tag, 'Movie will be saved as: $saved');
    if (transition != null) {
      _logger.info(
        _tag,
        'Joining with the ${transition.name} transition'
        '${upgradeOlderClips ? ', re-encoding older clips first' : ''}',
      );
    }
    if (music != null) {
      _logger.info(
        _tag,
        'Adding music: ${music.tracks.length} tracks at '
        '${(music.volume * 100).round()}%, '
        '${music.keepClipSound ? 'over' : 'instead of'} the videos\' sound',
      );
    }
    emit(MovieBuildStarted(refs));
    bool joining = false;
    try {
      await for (final MovieRenderEvent event in _engine.renderMovie(
        request,
        cancelToken: token,
      )) {
        switch (event) {
          case MoviePreparing(:final int index, :final int total):
            _logger.info(_tag, 'Progress: $index / $total');
            emit(MovieBuildProgress(event));
          case MovieConcatenating():
            if (!joining) {
              joining = true;
              _logger.info(
                _tag,
                'Finished checking videos... creating movie...',
              );
            }
            emit(MovieBuildProgress(event));
          case MovieCompleted(
            :final String outputPath,
            :final int durationMs,
            :final List<int> skipped,
            :final List<int> leftOutPrivate,
            :final List<MovieChapter> chapters,
            :final int transitions,
          ):
            // The user may have cancelled as the session ended: honour it.
            token.throwIfCancelled();
            emit(const MovieBuildFinishing());
            // The engine keeps at least two.
            final List<ClipRef> joined = <ClipRef>[
              for (final (int at, ClipRef ref) in refs.indexed)
                if (!skipped.contains(at) && !leftOutPrivate.contains(at)) ref,
            ];
            // Clips nobody had read, which their files say are private:
            // the library knows now, and the user is told.
            for (final int at in leftOutPrivate) {
              _clips.privacyKnown(refs[at].relPath, private: true);
            }
            final List<ClipRef> leftOutAsPrivate = <ClipRef>[
              for (final int at in leftOutPrivate) refs[at],
            ];
            if (leftOutAsPrivate.isNotEmpty) {
              _logger.info(
                _tag,
                'Leaving out ${leftOutAsPrivate.length} private videos: '
                '${_names(leftOutAsPrivate)}',
              );
            }
            final List<ClipRef> leftOut = <ClipRef>[
              for (final int at in skipped) refs[at],
            ];
            if (leftOut.isNotEmpty) {
              _logger.warning(
                _tag,
                'Leaving out ${leftOut.length} unreadable videos: '
                '${_names(leftOut)}',
              );
            }
            final String published = await _publish(outputPath, day: today);
            final MovieEntry movie = MovieEntry(
              fileName: published,
              title: title,
              profile: profile,
              clipCount: joined.length,
              from: joined.first.day,
              to: joined.last.day,
              // To the millisecond, as the movie index keeps it.
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                _clock.now().millisecondsSinceEpoch,
              ),
              durationMs: durationMs,
              orientation: format.orientation,
              privateClipCount: joined.where(index.isPrivate).length,
              tags: MovieTags.sorted(tags.anyOf),
              without: MovieTags.sorted(tags.noneOf),
              chapters: chapters,
              // The engine says whether a boundary got it: a movie whose every
              // boundary stayed a hard cut records none, like its file
              // (`MovieTransition.descriptionPart`).
              transition: transitions > 0 ? transition : null,
              musicOn: music == null ? null : true,
            );
            await _register(movie);
            _logger.info(
              _tag,
              'Movie saved! ${PathNames.moviesFolder}/$published',
            );
            emit(
              MovieBuilt(
                movie,
                skipped: leftOut,
                leftOutPrivate: leftOutAsPrivate,
              ),
            );
        }
      }
    } on CancelledException {
      _logger.info(_tag, 'Execution was cancelled: $saved');
      rethrow;
    } on NotEnoughClipsException catch (error) {
      // The engine logged each clip it left out.
      _logger.warning(
        _tag,
        'Insufficient videos left to create movie. ${error.message}',
      );
      rethrow;
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Error creating movie -> $saved',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    } finally {
      await _deleteJob(job);
    }
  }

  /// The clips as the log lists them: `[2026-09-01.mp4, trip/2026-09-02.mp4]`.
  static String _names(List<ClipRef> clips) =>
      '[${clips.map((ClipRef clip) => clip.relPath).join(', ')}]';

  /// The range as the log names it: the preset (`last7Days`), the month
  /// (`2026-09`) or the days picked (`2026-09-03..2026-09-12`).
  static String _rangeOf(MovieSource source) => switch (source) {
    PresetMovieSource(:final MoviePreset preset) => preset.name,
    MonthMovieSource(:final int year, :final int month) =>
      '$year-${month.toString().padLeft(2, '0')}',
    DateRangeMovieSource(:final DayRange range) =>
      '${range.first.fileStem}..${range.last.fileStem}',
    CustomMovieSource() => 'custom',
  };

  /// Publishes the finished movie at [outputPath] into `Movies/` and returns
  /// its file name.
  Future<String> _publish(String outputPath, {required LocalDay day}) async {
    final String fileName = await _movies.nextFreeFileName(day);
    if (await _publisher.publish(
          tempPath: outputPath,
          relPath: '${PathNames.moviesFolder}/$fileName',
        ) ==
        null) {
      throw MediaStoreException('Could not publish the movie $fileName');
    }
    return fileName;
  }

  /// Registers the published [movie].
  Future<void> _register(MovieEntry movie) async {
    try {
      await _movies.add(movie);
    } on StorageException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Made ${movie.fileName} but could not record its title',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Deletes the job's scratch folder and whatever is left in it: the published
  /// movie has moved out, a failed or cancelled one never leaves a partial file
  /// behind, whatever the engine did.
  Future<void> _deleteJob(String job) async {
    _logger.info(_tag, 'Deleting temp files... : $job');
    try {
      await Directory(job).delete(recursive: true);
    } on PathNotFoundException {
      // The engine never created it.
    } on FileSystemException catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not delete the movie scratch folder $job',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// The request's clips for [refs], in their order, each with the facts the
  /// metadata cache has for it, copied as they are (a null means unknown, and
  /// the engine probes that one clip; a clip changed since its facts were
  /// cached has none), and its chapter title: its day, its number among the
  /// day's clips in the movie when there are several, and the place and
  /// subtitle the cache knows.
  List<MovieClip> _movieClipsOf(ClipIndex index, List<ClipRef> refs) {
    final Map<LocalDay, int> perDay = <LocalDay, int>{};
    for (final ClipRef ref in refs) {
      perDay[ref.day] = (perDay[ref.day] ?? 0) + 1;
    }
    final Map<LocalDay, int> seen = <LocalDay, int>{};
    final String? locale = Intl.defaultLocale;
    return <MovieClip>[
      for (final ClipRef ref in refs)
        _movieClipOf(
          ref,
          meta: _metaOf(index, ref),
          position: seen[ref.day] = (seen[ref.day] ?? 0) + 1,
          sameDay: perDay[ref.day] ?? 1,
          locale: locale,
        ),
    ];
  }

  ClipMeta? _metaOf(ClipIndex index, ClipRef clip) {
    final FileStamp? stamp = index.stampOf(clip);
    return stamp == null
        ? null
        : _metadata.lookup(relPath: clip.relPath, stamp: stamp);
  }

  MovieClip _movieClipOf(
    ClipRef clip, {
    required ClipMeta? meta,
    required int position,
    required int sameDay,
    required String? locale,
  }) => MovieClipFacts.of(
    meta,
    path: _paths.absoluteFromVideos(clip.relPath),
    chapterTitle: ChapterTitle.of(
      day: clip.day,
      locale: locale,
      position: position,
      sameDay: sameDay,
      place: meta?.locationText,
      subtitle: meta?.subtitleText,
    ),
  );
}
