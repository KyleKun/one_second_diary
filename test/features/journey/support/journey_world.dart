import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/diary/presentation/diary_opener.dart';
import 'package:one_second_diary/features/journey/presentation/cubit/journey_cubit.dart';
import 'package:one_second_diary/features/movies/data/movie_posters.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';

import '../../../shared/fakes/clip_index_fixture.dart';
import '../../../shared/fakes/fake_clip_caches.dart';
import '../../../shared/fakes/fake_clip_repository.dart';
import '../../../shared/fakes/fake_free_space_gateway.dart';
import '../../../shared/fakes/fake_movie_builder.dart';
import '../../../shared/fakes/fake_profiles_repository.dart';
import '../../../support/support.dart';
import '../../movies/support/fake_movie_posters.dart';
import '../../movies/support/fake_movie_repository.dart';
import '../../movies/support/pausable_backfill.dart';
import 'journey_fakes.dart';

/// Everything the Journey tab reads, faked, on September 28, 2026 at 10:00:
/// the Default profile's clips ([recordDays]), what the backfill knows
/// ([metadata]), the movies, and the app-scoped movie job. [cubit] builds
/// the tab's cubit over them; [wrap] provides what the page reads from the
/// tree.
final class JourneyWorld {
  JourneyWorld()
    : clock = FakeClock(DateTime(2026, 9, 28, 10)),
      profiles = FakeProfilesRepository(),
      clips = FakeClipRepository(),
      thumbnails = FakeThumbnailRepository(),
      metadata = MapClipMetadataCache(),
      backfill = ScriptedBackfill(),
      savedPlaces = FakeSavedPlaces(),
      coordinates = FakePlaceCoordinates(),
      movies = FakeMovieRepository(),
      movieBuilder = FakeMovieBuilder(),
      log = MemoryLogSink();

  final FakeClock clock;
  final FakeProfilesRepository profiles;
  final FakeClipRepository clips;
  final FakeThumbnailRepository thumbnails;
  final MapClipMetadataCache metadata;
  final ScriptedBackfill backfill;
  final FakeSavedPlaces savedPlaces;
  final FakePlaceCoordinates coordinates;
  final FakeMovieRepository movies;
  final FakeMovieBuilder movieBuilder;
  final MemoryLogSink log;

  final AppPaths paths = AppPaths.forTest(Directory('/osd'));

  /// What the tiles ask of the Diary ("This month", "Days recorded").
  final DiaryOpener diary = DiaryOpener();

  /// The Default profile records one clip on each of [days], each [seconds]
  /// long as far as the backfill knows.
  void recordDays(List<LocalDay> days, {int seconds = 1}) {
    clips.publish(clipIndexOf(ProfileKey.defaultProfile, days));
    for (final LocalDay day in days) {
      metadata.known['${day.fileStem}.mp4'] = ClipMeta(
        durationMs: seconds * 1000,
      );
    }
  }

  JourneyCubit cubit() => JourneyCubit(
    profiles: profiles,
    clips: clips,
    metadata: metadata,
    backfill: backfill,
    savedPlaces: savedPlaces,
    coordinates: coordinates,
    movies: movies,
    clock: clock,
    midnight: MidnightTicker(clock: clock),
    logger: memoryLogger(log),
  );

  /// [page] with [cubit] (closed with the tree), the profiles, the movie
  /// job and the clip media services.
  Widget wrap(JourneyCubit cubit, Widget page) => MultiRepositoryProvider(
    providers: <RepositoryProvider<Object>>[
      RepositoryProvider<AppPaths>.value(value: paths),
      RepositoryProvider<ClipRepository>.value(value: clips),
      RepositoryProvider<ThumbnailRepository>.value(value: thumbnails),
      RepositoryProvider<MoviePosters>.value(value: FakeMoviePosters()),
      RepositoryProvider<DiaryOpener>.value(value: diary),
    ],
    child: MultiBlocProvider(
      providers: <BlocProvider<Object?>>[
        BlocProvider<JourneyCubit>(create: (_) => cubit),
        BlocProvider<ProfilesCubit>(
          create: (_) => ProfilesCubit(
            profiles: profiles,
            clips: clips,
            logger: memoryLogger(log),
          ),
        ),
        BlocProvider<MovieJobBloc>(
          create: (_) => MovieJobBloc(
            builder: movieBuilder,
            wakelock: FakeWakelockGateway(),
            backfill: PausableBackfill(),
            freeSpace: FakeFreeSpaceGateway(),
            logger: memoryLogger(log),
          ),
        ),
      ],
      child: page,
    ),
  );

  Future<void> dispose() async {
    await clips.close();
    await diary.dispose();
  }
}
