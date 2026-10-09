import 'package:get_it/get_it.dart';
import 'package:one_second_diary/core/di/launch_core.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/features/movies/data/movie_audio.dart';
import 'package:one_second_diary/features/movies/data/movie_posters.dart';
import 'package:one_second_diary/features/movies/data/movie_tag_reader.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_state.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/movie_created_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/movie_player_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/my_movies_cubit.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

/// The movies feature's registrations, called once by `registerDependencies`
/// after the core services.
void registerMovies(GetIt sl) {
  sl
    ..registerFactoryParam<CreateMovieCubit, CreateMovieArgs, void>(
      (CreateMovieArgs args, _) => CreateMovieCubit(
        source: args.source,
        preset: args.preset,
        tags: args.tags,
        profiles: sl(),
        clips: sl(),
        clock: sl(),
        freeSpace: sl(),
        backfill: sl(),
        metadata: sl(),
        audioPicker: sl(),
      ),
    )
    ..registerFactoryParam<MovieCreatedCubit, MovieJobState, void>(
      (MovieJobState job, _) => MovieCreatedCubit(
        job: job,
        share: sl(),
        paths: sl(),
        showsLocation: sl<LaunchCore>().isAndroid,
      ),
    )
    ..registerLazySingleton<MovieJobBloc>(
      () => MovieJobBloc(
        builder: sl(),
        wakelock: sl(),
        backfill: sl(),
        freeSpace: sl(),
        logger: sl(),
      ),
      dispose: (MovieJobBloc job) => job.close(),
    )
    ..registerLazySingleton<MovieAudio>(
      () => MovieAudio(
        engine: sl(),
        publisher: sl(),
        movies: sl(),
        paths: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton<MoviePosters>(
      () => MoviePosters(gateway: sl(), queue: sl(), paths: sl(), logger: sl()),
    )
    ..registerLazySingleton<MovieTagSource>(
      () => EngineMovieTagSource(engine: sl()),
    )
    ..registerLazySingleton<MovieTagReader>(
      () =>
          MovieTagReader(source: sl(), index: sl(), paths: sl(), logger: sl()),
    )
    ..registerFactory<MyMoviesCubit>(
      () => MyMoviesCubit(
        movies: sl(),
        tags: sl(),
        share: sl(),
        paths: sl(),
        largeView: sl<SettingsRepository>().moviesLargeView,
        logger: sl(),
        audio: sl(),
      ),
    )
    ..registerFactoryParam<MoviePlayerCubit, String, void>(
      (String file, _) => MoviePlayerCubit(
        file: file,
        movies: sl(),
        wakelock: sl(),
        logger: sl(),
      ),
    );
}
