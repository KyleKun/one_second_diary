import 'package:get_it/get_it.dart';
import 'package:one_second_diary/core/di/launch_core.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/features/clip_editor/data/clip_saver.dart';
import 'package:one_second_diary/features/clip_editor/data/filmstrip_frames.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';

/// The clip editor's registrations. Each editor gets its own `EditClipCubit`
/// and `FilmstripFrames` from the route builder; the stateless `ClipSaver`
/// is shared.
void registerClipEditor(GetIt sl) {
  sl
    ..registerLazySingleton<ClipSaver>(
      () => ClipSaver(
        engine: sl(),
        store: sl(),
        wakelock: sl(),
        backfill: sl(),
        freeSpace: sl(),
        paths: sl(),
        logger: sl(),
        isIOS: sl<LaunchCore>().isIOS,
        settings: sl(),
        deviceInfo: sl(),
        appInfo: sl(),
        clock: sl(),
      ),
    )
    ..registerFactoryParam<EditClipCubit, EditClipArgs, void>(
      (EditClipArgs args, _) => EditClipCubit(
        args: args,
        settings: sl(),
        clips: sl(),
        locations: sl(),
        savedPlaces: sl(),
        metadata: sl(),
        saver: sl(),
        logger: sl(),
      ),
    )
    ..registerFactory<FilmstripFrames>(
      () => FilmstripFrames(gateway: sl(), paths: sl(), logger: sl()),
    );
}
