// The movie job: app-scoped, so a movie goes on while the user leaves the
// flow, and holds the screen awake while it renders.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/movie_render_event.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/movies/domain/movie_build_event.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_event.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_state.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../../shared/fakes/fake_free_space_gateway.dart';
import '../../../../shared/fakes/fake_movie_builder.dart';
import '../../../../support/support.dart';
import '../../support/pausable_backfill.dart';

const ProfileKey _default = ProfileKey.defaultProfile;
const MovieJobRequest _request = MovieJobRequest(
  source: MovieSource.month(year: 2024, month: 1),
  profile: _default,
  format: ClipFormat.legacy(VideoOrientation.landscape),
  title: 'January 2024',
  clipBytes: 1000,
);

/// Another movie, asked for while or after [_request] is made.
const MovieJobRequest _another = MovieJobRequest(
  source: MovieSource.month(year: 2024, month: 2),
  profile: _default,
  format: ClipFormat.legacy(VideoOrientation.landscape),
  title: 'February 2024',
  clipBytes: 1000,
);

ClipRef _clip(int day) => ClipRef(
  profile: _default,
  relPath: '${LocalDay(2024, 1, day).fileStem}.mp4',
);

final MovieEntry _movie = MovieEntry(
  fileName: 'OSD-Movie-2-2024-01-05.mp4',
  title: 'January 2024',
  profile: _default,
  clipCount: 4,
  from: LocalDay(2024, 1, 1),
  to: LocalDay(2024, 1, 4),
  createdAt: DateTime(2024, 1, 5, 10),
  durationMs: 6000,
);

void main() {
  late FakeMovieBuilder builder;
  late FakeWakelockGateway wakelock;
  late PausableBackfill backfill;
  late FakeFreeSpaceGateway freeSpace;
  late MovieJobBloc bloc;

  setUp(() {
    builder = FakeMovieBuilder();
    wakelock = FakeWakelockGateway();
    backfill = PausableBackfill();
    freeSpace = FakeFreeSpaceGateway();
    bloc = MovieJobBloc(
      builder: builder,
      wakelock: wakelock,
      backfill: backfill,
      freeSpace: freeSpace,
      logger: memoryLogger(MemoryLogSink()),
    );
  });
  tearDown(() => bloc.close());

  final List<ClipRef> clips = <ClipRef>[_clip(1), _clip(2), _clip(3), _clip(4)];

  Future<void> started() async {
    bloc.add(const MovieJobStarted(_request));
    await pumpEventQueue();
    builder.emit(MovieBuildStarted(clips));
    await pumpEventQueue();
  }

  test(
    'a movie from start to end: idle at first; preparing with the clips it '
    'joins and the screen held awake; then the clip in hand, the clips '
    'done and the progress, never backwards and below 100 % until saved; '
    'finishing at 99 %; done with the movie, and the screen may sleep',
    () async {
      expect(bloc.state, const MovieJobState.idle());
      expect(bloc.state.isRunning, isFalse);

      await started();
      final MovieBuildRequest asked = builder.requests.single;
      expect(
        (asked.source, asked.profile, asked.format, asked.title),
        (
          _request.source,
          _default,
          const ClipFormat.legacy(VideoOrientation.landscape),
          'January 2024',
        ),
      );
      expect(bloc.state.status, MovieJobStatus.preparing);
      expect(bloc.state.request, _request);
      expect(bloc.state.clips, clips);
      expect((bloc.state.currentClip, bloc.state.progress), (null, 0));
      expect(bloc.state.isRunning, isTrue);
      expect(wakelock.enabled, isTrue);

      builder.emit(
        const MovieBuildProgress(MoviePreparing(index: 1, total: 4)),
      );
      await pumpEventQueue();
      expect(bloc.state.status, MovieJobStatus.rendering);
      expect(
        (bloc.state.currentClip, bloc.state.processed, bloc.state.progress),
        (_clip(2), 1, .25),
      );

      // The join starts over from the first clip: what was done stays done.
      builder.emit(
        const MovieBuildProgress(
          MovieConcatenating(fraction: .1, currentIndex: 0),
        ),
      );
      await pumpEventQueue();
      expect(
        (bloc.state.currentClip, bloc.state.processed, bloc.state.progress),
        (_clip(1), 1, .25),
      );

      builder.emit(
        const MovieBuildProgress(
          MovieConcatenating(fraction: .6, currentIndex: 2),
        ),
      );
      await pumpEventQueue();
      expect(
        (bloc.state.currentClip, bloc.state.processed, bloc.state.progress),
        (_clip(3), 2, .6),
      );

      builder.emit(
        const MovieBuildProgress(
          MovieConcatenating(fraction: .999, currentIndex: 3),
        ),
      );
      await pumpEventQueue();
      expect(bloc.state.progress, MovieJobState.finishingProgress);

      builder.emit(const MovieBuildFinishing());
      await pumpEventQueue();
      expect(bloc.state.status, MovieJobStatus.finishing);
      expect((bloc.state.processed, bloc.state.currentClip), (4, null));
      expect(bloc.state.progress, MovieJobState.finishingProgress);
      expect(bloc.state.isRunning, isTrue);

      builder.emit(MovieBuilt(_movie));
      await builder.finish();
      await pumpEventQueue();
      expect(bloc.state.status, MovieJobStatus.done);
      expect((bloc.state.movie, bloc.state.progress), (_movie, 1));
      expect(bloc.state.isRunning, isFalse);
      expect(wakelock.enabled, isFalse);
    },
  );

  test('a build that fails: failed, and the screen may sleep; fewer than two '
      'clips left (deleted meanwhile) is its own failure; try again makes the '
      'same movie once more, from the start', () async {
    await started();
    builder.emit(const MovieBuildProgress(MoviePreparing(index: 2, total: 4)));
    await builder.fail(
      const VideoProcessingException('concat', returnCode: 1, logTail: ''),
    );
    await pumpEventQueue();
    expect(bloc.state.status, MovieJobStatus.failed);
    expect(bloc.state.failure, MovieJobFailure.failed);
    expect(wakelock.enabled, isFalse);

    bloc.add(MovieJobStarted(bloc.state.request!));
    await pumpEventQueue();
    expect(builder.building, isTrue);
    expect(builder.lastToken?.isCancelled, isFalse);
    expect(bloc.state.request, _request);
    expect(bloc.state.status, MovieJobStatus.preparing);
    expect((bloc.state.processed, bloc.state.progress), (0, 0));
    expect(bloc.state.failure, isNull);

    await builder.fail(ArgumentError('needs two or more clips'));
    await pumpEventQueue();
    expect(bloc.state.status, MovieJobStatus.failed);
    expect(bloc.state.failure, MovieJobFailure.notEnoughClips);
  });

  // A clip that cannot be read does not fail the movie.
  test('clips that could not be read: a movie made without them lists the '
      'clips it joined and counts the others; with too few left it is the '
      'not-enough-clips failure, with the count', () async {
    await started();
    builder.emit(
      MovieBuilt(
        _movie,
        skipped: <ClipRef>[_clip(2)],
        leftOutPrivate: <ClipRef>[_clip(4)],
      ),
    );
    await builder.finish();
    await pumpEventQueue();
    expect(bloc.state.status, MovieJobStatus.done);
    expect(bloc.state.clips, <ClipRef>[_clip(1), _clip(3)]);
    expect((bloc.state.processed, bloc.state.skippedClips), (2, 1));
    expect(bloc.state.leftOutPrivateClips, 1);

    bloc.add(const MovieJobStarted(_another));
    await pumpEventQueue();
    expect(bloc.state.skippedClips, 0);
    await builder.fail(
      const NotEnoughClipsException('1 of 4 clips can be read', skipped: 3),
    );
    await pumpEventQueue();
    expect(bloc.state.status, MovieJobStatus.failed);
    expect(bloc.state.failure, MovieJobFailure.notEnoughClips);
    expect(bloc.state.skippedClips, 3);
  });

  test(
    'cancel stops the builder: cancelling at once, the progress no longer '
    'moving, cancelled once it has stopped, and the screen may sleep',
    () async {
      builder.ignoreCancel = true;
      await started();

      bloc.add(const MovieJobCancelled());
      await pumpEventQueue();
      expect(builder.lastToken?.isCancelled, isTrue);
      expect(bloc.state.status, MovieJobStatus.cancelling);
      expect(bloc.state.isRunning, isTrue);
      expect(wakelock.enabled, isTrue);

      builder.emit(
        const MovieBuildProgress(MoviePreparing(index: 2, total: 4)),
      );
      await pumpEventQueue();
      expect(bloc.state.status, MovieJobStatus.cancelling);
      expect(bloc.state.processed, 0);

      await builder.fail(const CancelledException('Cancelled'));
      await pumpEventQueue();
      expect(bloc.state.status, MovieJobStatus.cancelled);
      expect(bloc.state.isRunning, isFalse);
      expect(wakelock.enabled, isFalse);
    },
  );

  test('a cancel once the movie is being saved is too late and ignored; a '
      'cancel that lands as the movie ends keeps the movie', () async {
    await started();
    builder.emit(const MovieBuildFinishing());
    await pumpEventQueue();
    bloc.add(const MovieJobCancelled());
    await pumpEventQueue();
    expect(builder.lastToken?.isCancelled, isFalse);
    expect(bloc.state.status, MovieJobStatus.finishing);
    builder.emit(MovieBuilt(_movie));
    await builder.finish();
    await pumpEventQueue();
    bloc.add(const MovieJobDismissed());
    await pumpEventQueue();

    builder.ignoreCancel = true;
    await started();
    bloc.add(const MovieJobCancelled());
    await pumpEventQueue();
    builder.emit(MovieBuilt(_movie));
    await builder.finish();
    await pumpEventQueue();
    expect(bloc.state.status, MovieJobStatus.done);
  });

  test('one movie at a time: a start while one runs is ignored; dismissed '
      'only after the end (M7 Done, the error Close), idle again; closing '
      'the app-scoped bloc stops a running build', () async {
    await started();
    final CancelToken? running = builder.lastToken;

    bloc.add(const MovieJobStarted(_another));
    bloc.add(const MovieJobDismissed());
    await pumpEventQueue();
    expect(bloc.state.request, _request);
    expect(builder.lastToken, same(running));
    expect(bloc.state.status, MovieJobStatus.preparing);

    builder.emit(MovieBuilt(_movie));
    await builder.finish();
    await pumpEventQueue();
    bloc.add(const MovieJobDismissed());
    await pumpEventQueue();
    expect(bloc.state, const MovieJobState.idle());

    // Closing the app-scoped bloc.
    {
      await started();

      await bloc.close();

      expect(builder.lastToken?.isCancelled, isTrue);
      expect(wakelock.enabled, isFalse);
    }
  });

  // The free-space check while the movie renders: iOS never answers it, and
  // other apps write too.
  test(
    'the phone fills up while the movie is made: its own failure, with '
    'what to free (2.1 × the clips, less what is free now), or no amount '
    'when the free space is unknown (iOS) or enough by the estimate',
    () async {
      const VideoProcessingException full = VideoProcessingException(
        'concat failed',
        returnCode: 1,
        logTail: 'No space left on device',
      );
      for (final (int? free, int? shortfall) in <(int?, int?)>[
        (600, 1500),
        (null, null),
        (64000000000, null),
      ]) {
        freeSpace.free = free;
        await started();
        await builder.fail(full);
        await pumpEventQueue();

        expect(bloc.state.status, MovieJobStatus.failed, reason: '$free');
        expect(bloc.state.failure, MovieJobFailure.noSpace, reason: '$free');
        expect(bloc.state.spaceShortfall, shortfall, reason: '$free');
        expect(wakelock.enabled, isFalse);
      }
    },
  );

  test('the metadata backfill waits while a movie is made, whatever ends '
      'it', () async {
    await started();
    expect(backfill.paused, isTrue);
    builder.emit(MovieBuilt(_movie));
    await builder.finish();
    await pumpEventQueue();
    expect(backfill.paused, isFalse);

    await started();
    expect(backfill.paused, isTrue);
    await builder.fail(StateError('boom'));
    await pumpEventQueue();
    expect(backfill.paused, isFalse);

    await started();
    bloc.add(const MovieJobCancelled());
    await pumpEventQueue();
    expect(backfill.paused, isFalse);
  });
}
