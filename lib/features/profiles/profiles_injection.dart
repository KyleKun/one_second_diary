import 'package:get_it/get_it.dart';
import 'package:one_second_diary/core/di/launch_core.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/features/clips/domain/clip_conversion.dart';
import 'package:one_second_diary/features/profiles/data/device_media_profile_store.dart';
import 'package:one_second_diary/features/profiles/data/probed_profile_clip_facts.dart';
import 'package:one_second_diary/features/profiles/domain/profile_clip_facts.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/convert_profile_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/found_profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_target.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/whats_new_quality_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/profile_labels.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/convert_profile_sheet.dart';

/// The profiles feature's registrations, called once by
/// `registerDependencies` after the core services.
///
/// `ProfilesCubit` is app-scoped: a lazy singleton closed on `sl.reset()` and
/// provided at the app root. `DeviceMediaProfileStore` and `ProfileClipFacts`
/// are app-scoped services the onboarding feature shares.
/// `ProfileConversionStarter` is registered earlier in
/// `injection_container.dart`; the convert sheet's cubit only resolves it.
void registerProfiles(GetIt sl) {
  sl
    ..registerLazySingleton<DeviceMediaProfileStore>(
      () => DeviceMediaProfileStore(
        prefs: sl(),
        appInfo: sl(),
        deviceInfo: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton<ProfileClipFacts>(
      () => ProbedProfileClipFacts(
        scanner: sl(),
        engine: sl(),
        paths: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton<ProfilesCubit>(
      () => ProfilesCubit(profiles: sl(), clips: sl(), logger: sl()),
      dispose: (ProfilesCubit cubit) => cubit.close(),
    )
    ..registerFactory<FoundProfilesCubit>(
      () => FoundProfilesCubit(profiles: sl(), logger: sl()),
    )
    ..registerFactoryParam<ProfileFormCubit, ProfileFormTarget, void>(
      (ProfileFormTarget target, _) => ProfileFormCubit(
        target: target,
        profiles: sl(),
        picker: sl(),
        deviceProfile: sl(),
        isIOS: sl<LaunchCore>().isIOS,
        logger: sl(),
      ),
    )
    // Sheets open from any page, so the app root provides this factory.
    ..registerLazySingleton<ProfileFormFactory>(
      () =>
          (ProfileFormTarget target) => sl<ProfileFormCubit>(param1: target),
    )
    ..registerFactoryParam<ConvertProfileCubit, ProfileKey, void>(
      (ProfileKey source, _) => ConvertProfileCubit(
        source: source,
        profiles: sl(),
        converter: sl<ProfileConversionStarter>(),
        deviceProfile: sl(),
        isIOS: sl<LaunchCore>().isIOS,
        defaultNameOf: (String name, ClipFormat target) =>
            Strings.convertProfileDefaultName(
              name: name,
              quality: ProfileLabels.tier(target.tier),
            ),
        logger: sl(),
      ),
    )
    ..registerLazySingleton<ConvertProfileFactory>(
      () =>
          (ProfileKey source) => sl<ConvertProfileCubit>(param1: source),
    )
    ..registerFactory<WhatsNewQualityCubit>(
      () => WhatsNewQualityCubit(prefs: sl(), logger: sl()),
    );
}
