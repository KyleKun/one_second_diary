import 'package:get_it/get_it.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/features/diary/data/clip_captions.dart';
import 'package:one_second_diary/features/diary/data/clip_filtering.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/viewer_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/diary_opener.dart';

/// The diary feature's registrations (the calendar, Memories and the
/// viewer), called once by `registerDependencies` after the core services.
///
/// - `DiaryCubit` is tab-scoped: `diary_routes.dart` makes one for the
///   Diary branch, which lives as long as the tab.
/// - `ViewerCubit` is made for each viewer, with its `ViewerArgs`.
/// - `ClipCaptions` reads a clip's subtitle and place from memory;
///   `ClipFiltering` applies the Diary's filter to a snapshot from it.
/// - `DiaryOpener` is app-scoped: the Journey asks through it for this
///   month's calendar (`journey_routes.dart` provides it), the tab's cubit
///   follows.
void registerDiary(GetIt sl) {
  sl
    ..registerFactory<ClipCaptions>(
      () => ClipCaptions(clips: sl(), metadata: sl()),
    )
    ..registerFactory<ClipFiltering>(() => ClipFiltering(metadata: sl()))
    ..registerFactory<DiaryCubit>(
      () => DiaryCubit(
        profiles: sl(),
        clips: sl(),
        settings: sl(),
        midnight: sl(),
        captions: sl(),
        filtering: sl(),
        store: sl(),
        share: sl(),
        opener: sl(),
        paths: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton<DiaryOpener>(
      DiaryOpener.new,
      dispose: (DiaryOpener opener) => opener.dispose(),
    )
    ..registerFactoryParam<ViewerCubit, ViewerArgs, void>(
      (ViewerArgs args, _) => ViewerCubit(
        args: args,
        profiles: sl(),
        clips: sl(),
        captions: sl(),
        filtering: sl(),
        store: sl(),
        share: sl(),
        paths: sl(),
        settings: sl(),
        logger: sl(),
      ),
    );
}
