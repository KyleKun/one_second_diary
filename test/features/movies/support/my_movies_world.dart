import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/osd_pages.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/movies/data/movie_posters.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/my_movies_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/pages/my_movies_page.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/settings/data/setting.dart';

import '../../../shared/fakes/fake_clip_repository.dart';
import '../../../shared/fakes/fake_profiles_repository.dart';
import '../../../support/support.dart';
import 'fake_movie_audio.dart';
import 'fake_movie_posters.dart';
import 'fake_movie_repository.dart';
import 'fake_movie_tag_reader.dart';

/// The Kids profile, shown as "Children" (renamed after its movies were
/// made: titles follow the current name).
const ProfileKey kids = ProfileKey('Kids');

/// A movie of [clips] clips, made on [day] of September 2026.
MovieEntry madeMovie(
  int number, {
  required String title,
  ProfileKey? profile = ProfileKey.defaultProfile,
  int? clips = 25,
  int day = 1,
  VideoOrientation? orientation = VideoOrientation.landscape,
  String folder = '',
}) => MovieEntry(
  fileName: '$folder${'OSD-Movie-$number-2026-09-0$day.mp4'}',
  title: title,
  profile: profile,
  clipCount: clips,
  from: clips == null ? null : LocalDay(2026, 8, 1),
  to: clips == null ? null : LocalDay(2026, 8, 31),
  createdAt: DateTime(2026, 9, day, 20),
  durationMs: clips == null ? null : clips * 1500,
  orientation: orientation,
);

/// Everything My movies reads, faked: the movies in `Movies/`, their tags
/// and posters, the share sheet, and the app's profiles (Default and Kids,
/// shown as "Children").
final class MyMoviesWorld {
  MyMoviesWorld()
    : profiles = FakeProfilesRepository(
        profiles: <Profile>[
          testProfile(),
          const Profile(
            key: kids,
            displayName: 'Children',
            orientation: VideoOrientation.portrait,
            avatarRelPath: null,
          ),
        ],
      );

  final FakeProfilesRepository profiles;
  final FakeClipRepository clips = FakeClipRepository();
  final FakeMovieRepository movies = FakeMovieRepository();
  final FakeMovieTagReader tags = FakeMovieTagReader();
  final FakeMoviePosters posters = FakeMoviePosters();

  /// The music swap, at once.
  final FakeMovieAudio audio = FakeMovieAudio();
  final FakeShareGateway share = FakeShareGateway();
  final MemoryLogSink log = MemoryLogSink();
  final AppPaths paths = AppPaths.forTest(Directory('/osd'));

  /// The view remembered (`moviesLargeView`).
  bool storedLargeView = false;
  late final Setting<bool> largeView = Setting<bool>(
    read: () => storedLargeView,
    write: (bool large) async => storedLargeView = large,
  );

  /// My movies' cubit, as its route makes it.
  MyMoviesCubit cubit() => MyMoviesCubit(
    movies: movies,
    tags: tags,
    share: share,
    paths: paths,
    largeView: largeView,
    logger: memoryLogger(log),
    audio: audio,
  );

  /// What the app root provides: the app's profiles.
  Widget above(Widget app) => BlocProvider<ProfilesCubit>(
    create: (_) => ProfilesCubit(
      profiles: profiles,
      clips: clips,
      logger: memoryLogger(log),
    ),
    child: app,
  );

  /// Journey, with My movies pushed above it, Create movie and the player
  /// as stubs that show what they were opened with.
  GoRouter router() => GoRouter(
    initialLocation: AppRoute.journey.path,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.journey.path,
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: SizedBox.expand(key: journeyKey)),
      ),
      GoRoute(
        path: AppRoute.myMovies.path,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            OsdPages.material(
              state,
              RepositoryProvider<MoviePosters>.value(
                value: posters,
                child: BlocProvider<MyMoviesCubit>(
                  create: (_) => cubit(),
                  child: const MyMoviesPage(
                    key: ValueKey<AppRoute>(AppRoute.myMovies),
                  ),
                ),
              ),
            ),
      ),
      GoRoute(
        path: AppRoute.moviePlayer.path,
        builder: (BuildContext context, GoRouterState state) => Scaffold(
          body: Text(
            state.uri.queryParameters[AppRoute.movieFileParameter]!,
            key: playerKey,
          ),
        ),
      ),
      GoRoute(
        path: AppRoute.createMovie.path,
        builder: (BuildContext context, GoRouterState state) =>
            const Scaffold(body: SizedBox.expand(key: createMovieKey)),
      ),
    ],
  );

  static const Key journeyKey = Key('journey');
  static const Key playerKey = Key('player');
  static const Key createMovieKey = Key('createMovie');

  Future<void> dispose() => clips.close();
}
