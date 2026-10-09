import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:one_second_diary/core/di/launch_core.dart';
import 'package:one_second_diary/features/clips/data/originals_store.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/settings/data/bundled_documents.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/about_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/changelog_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/contact_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/link_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/locale_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/places_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/preferences_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/tags_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/thanks_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/user_name_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/report_error/report_error_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/sheets/backup_sheet_cubit.dart';

/// The settings feature's registrations, called once by
/// `registerDependencies` after the core services.
///
/// App-scoped cubits are lazy singletons closed on `sl.reset()` and
/// provided with `BlocProvider.value` at the app root; screen cubits are
/// factories their route builder provides (`settings_routes.dart`).
void registerSettings(GetIt sl) {
  sl
    ..registerLazySingleton<ThemeCubit>(
      () => ThemeCubit(settings: sl(), logger: sl()),
      dispose: (ThemeCubit cubit) => cubit.close(),
    )
    ..registerLazySingleton<LocaleCubit>(
      () => LocaleCubit(
        settings: sl(),
        deviceLanguageCode: sl<LaunchCore>().deviceLanguageCode,
        logger: sl(),
      ),
      dispose: (LocaleCubit cubit) => cubit.close(),
    )
    ..registerLazySingleton<UserNameCubit>(
      () => UserNameCubit(settings: sl(), logger: sl()),
      dispose: (UserNameCubit cubit) => cubit.close(),
    )
    // Lives as long as the Settings tab.
    ..registerFactory<SettingsCubit>(
      () => SettingsCubit(appInfo: sl(), share: sl()),
    )
    ..registerFactory<ContactCubit>(() => ContactCubit(bugReports: sl()))
    // One per page that opens it (the Settings tab, About).
    ..registerFactory<BackupSheetCubit>(
      () => BackupSheetCubit(
        clips: sl(),
        profiles: sl(),
        urls: sl(),
        paths: sl(),
        logger: sl(),
        isIOS: sl<LaunchCore>().isIOS,
        originalsBytes: () => sl<OriginalsStore>().sizeBytes(),
      ),
    )
    // One per page with a failure surface, made by that page's routes file.
    ..registerFactory<ReportErrorCubit>(() => ReportErrorCubit(reports: sl()))
    // The Originals rows read the kept originals and the active profile's
    // format.
    ..registerFactory<PreferencesCubit>(
      () => PreferencesCubit(
        settings: sl(),
        imports: sl(),
        logger: sl(),
        originals: sl(),
        activeFormat: () => sl<ProfilesRepository>().formatOf(
          sl<ProfilesRepository>().active.key,
        ),
      ),
    )
    // One for the Settings tab (the Tags row's count) and one per Tags page.
    ..registerFactory<TagsCubit>(
      () => TagsCubit(
        tags: sl(),
        batch: sl(),
        colors: sl(),
        clips: sl(),
        profiles: sl(),
        logger: sl(),
      ),
    )
    // One for the Settings tab (the Places row's count) and one per Places
    // page.
    ..registerFactory<PlacesCubit>(
      () => PlacesCubit(places: sl(), locations: sl(), logger: sl()),
    )
    // One per Settings page that opens links, for as long as it shows.
    ..registerFactory<LinkCubit>(() => LinkCubit(urls: sl(), logger: sl()))
    // About and its pages: the version and the bundled documents.
    ..registerLazySingleton<BundledDocuments>(
      () => BundledDocuments(bundle: rootBundle),
    )
    ..registerFactory<AboutCubit>(() => AboutCubit(appInfo: sl(), clock: sl()))
    ..registerFactory<ChangelogCubit>(
      () => ChangelogCubit(documents: sl(), logger: sl()),
    )
    ..registerFactory<ThanksCubit>(
      () => ThanksCubit(documents: sl(), logger: sl()),
    );
}
