import 'package:get_it/get_it.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_character_cubit.dart';
import 'package:one_second_diary/features/today/presentation/cubit/today_cubit.dart';

/// The today feature's registrations, called once by
/// `registerDependencies` after the core services.
///
/// `TodayCubit` and `TodayCharacterCubit` (over the tab's `TodayCubit`)
/// are factories: the Today route builds them for the tab, which lives as
/// long as the tab (the shell keeps its branch alive).
void registerToday(GetIt sl) {
  sl
    ..registerFactory<TodayCubit>(
      () => TodayCubit(
        clips: sl(),
        profiles: sl(),
        midnight: sl(),
        clock: sl(),
        settings: sl(),
        logger: sl(),
      ),
    )
    ..registerFactoryParam<TodayCharacterCubit, TodayCubit, void>(
      (TodayCubit today, _) => TodayCharacterCubit(
        today: today,
        settings: sl(),
        clock: sl(),
        logger: sl(),
      ),
    );
}
