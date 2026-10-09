// The movie the job just made, kept for as long as its page shows (the job
// itself goes idle when the flow ends), and Share.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/share_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_event.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_state.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/movie_created_cubit.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

const ProfileKey _kids = ProfileKey('Kids');

final MovieEntry _movie = MovieEntry(
  fileName: 'OSD-Movie-3-2026-09-28.mp4',
  title: 'September 2026',
  profile: _kids,
  clipCount: 2,
  from: LocalDay(2026, 9, 1),
  to: LocalDay(2026, 9, 2),
  createdAt: DateTime(2026, 9, 28, 10),
  durationMs: 3000,
);

final List<ClipRef> _clips = <ClipRef>[
  ClipRef(profile: _kids, relPath: 'Profiles/Kids/2026-09-01.mp4'),
  ClipRef(profile: _kids, relPath: 'Profiles/Kids/2026-09-02.mp4'),
];

final MovieJobState _done = MovieJobState(
  status: MovieJobStatus.done,
  request: const MovieJobRequest(
    source: MovieSource.month(year: 2026, month: 9),
    profile: _kids,
    format: ClipFormat.legacy(VideoOrientation.portrait),
    title: 'September 2026',
  ),
  clips: _clips,
  processed: 2,
  progress: 1,
  movie: _movie,
);

/// A share sheet that stays open until [close].
class _HeldShare implements ShareGateway {
  final List<List<String>> shared = <List<String>>[];
  Rect? origin;
  final Completer<void> _open = Completer<void>();

  void close() => _open.complete();

  @override
  Future<void> shareFiles(List<String> paths, {Rect? origin}) {
    shared.add(paths);
    this.origin = origin;
    return _open.future;
  }

  @override
  Future<void> shareText(String text, {Rect? origin}) async {}
}

void main() {
  final AppPaths paths = AppPaths.forTest(Directory('/osd'));
  late _HeldShare share;

  setUp(() => share = _HeldShare());

  MovieCreatedCubit cubitOf(MovieJobState job) => MovieCreatedCubit(
    job: job,
    share: share,
    paths: paths,
    showsLocation: true,
  );

  test("keeps the job's movie, its canvas and its first clip (the poster), "
      'whatever the job does next; without a finished job, nothing to '
      'show', () async {
    final MovieCreatedCubit cubit = cubitOf(_done);
    addTearDown(cubit.close);

    expect(cubit.state.movie, _movie);
    expect(cubit.state.orientation, VideoOrientation.portrait);
    expect(cubit.state.poster, _clips.first);
    expect(cubit.state.showsLocation, isTrue);
    expect(cubit.state.sharing, isFalse);

    final MovieCreatedCubit idle = cubitOf(const MovieJobState.idle());
    addTearDown(idle.close);
    expect((idle.state.movie, idle.state.poster), (null, null));
  });

  test("Share hands the movie's file in Movies/ to the share sheet, from "
      'where it was tapped; sharing until the sheet is done', () async {
    final MovieCreatedCubit cubit = cubitOf(_done);
    addTearDown(cubit.close);
    const Rect button = Rect.fromLTWH(16, 700, 174, 54);

    final Future<void> sharing = cubit.share(origin: button);
    expect(cubit.state.sharing, isTrue);
    await cubit.share(origin: button);
    share.close();
    await sharing;

    expect(share.shared, <List<String>>[
      <String>['${paths.movies}OSD-Movie-3-2026-09-28.mp4'],
    ]);
    expect(share.origin, button);
    expect(cubit.state.sharing, isFalse);
  });
}
