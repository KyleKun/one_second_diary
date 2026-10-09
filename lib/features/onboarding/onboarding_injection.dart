import 'package:get_it/get_it.dart';
import 'package:one_second_diary/core/di/launch_core.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/onboarding/data/phone_check.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/phone_check_cubit.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

/// The onboarding feature's registrations, called once by
/// `registerDependencies` after the core services.
///
/// `OnboardingCubit` is flow-scoped: the onboarding `ShellRoute`
/// (`onboarding_routes.dart`) makes one each time the routes open, and it
/// lives as long as they do (the intro, the orientation page, the
/// permissions page and the phone check share it).
///
/// The phone check's parts the engine and the camera provide
/// (`DeviceMediaCheckRunner` over `MediaEngine.checkDevice`,
/// `CameraCapabilityProbe` over `CameraGateway`) are core services,
/// registered before the features (`injection_container.dart`).
/// `PhoneCheck` is app-scoped (a skipped check finishes in the
/// background); `PhoneCheckCubit` is screen-scoped, one per phone check or Settings
/// "Check again" page, for the orientation it recommends on.
void registerOnboarding(GetIt sl) {
  sl
    ..registerFactory<OnboardingCubit>(
      () => OnboardingCubit(
        store: sl(),
        permissions: sl(),
        deviceInfo: sl(),
        forceNativeCamera: sl<SettingsRepository>().forceNativeCamera,
        profiles: sl(),
        userName: sl<SettingsRepository>().userName,
        clips: sl(),
        clock: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton<PhoneCheck>(
      () => PhoneCheck(
        runner: sl(),
        camera: sl(),
        freeSpace: sl(),
        permissions: sl(),
        store: sl(),
        clock: sl(),
        logger: sl(),
      ),
    )
    ..registerFactoryParam<PhoneCheckCubit, VideoOrientation, void>(
      (VideoOrientation orientation, _) => PhoneCheckCubit(
        check: sl(),
        store: sl(),
        orientation: orientation,
        isIOS: sl<LaunchCore>().isIOS,
        logger: sl(),
      ),
    );
}
