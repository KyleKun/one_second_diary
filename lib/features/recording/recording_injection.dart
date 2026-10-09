import 'package:get_it/get_it.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/features/recording/data/recording_temps.dart';
import 'package:one_second_diary/features/recording/presentation/bloc/recording_bloc.dart';

/// The recording feature's registrations: the shared [RecordingTemps], and
/// one [RecordingBloc] per camera page, for the [RecordArgs] it was opened
/// with.
///
/// The page's "Report error" is the settings feature's `ReportErrorCubit`.
void registerRecording(GetIt sl) {
  sl
    ..registerLazySingleton<RecordingTemps>(() => RecordingTemps(logger: sl()))
    ..registerFactoryParam<RecordingBloc, RecordArgs, void>(
      (RecordArgs args, _) => RecordingBloc(
        args: args,
        camera: sl(),
        dualCamera: sl(),
        backfill: sl(),
        permissions: sl(),
        settings: sl(),
        profiles: sl(),
        orientationSensor: sl(),
        volumeKeys: sl(),
        import: sl(),
        temps: sl(),
        clock: sl(),
        logger: sl(),
      ),
    );
}
