import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/app/launch/launch_cubit.dart';
import 'package:one_second_diary/app/launch/launch_starter.dart';
import 'package:one_second_diary/app/launch/legacy_migration_listener.dart';
import 'package:one_second_diary/app/launch/lost_pick_listener.dart';
import 'package:one_second_diary/app/locale/app_locale_sync.dart';
import 'package:one_second_diary/app/locale/locale_rebuild_scope.dart';
import 'package:one_second_diary/app/osd_localization_root.dart';
import 'package:one_second_diary/app/osd_material_app.dart';
import 'package:one_second_diary/app/wiring/reminder_plan_wiring.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_audio.dart';
import 'package:one_second_diary/features/clips/data/clip_privacy.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/data/clip_subtitles.dart';
import 'package:one_second_diary/features/clips/data/clip_tags.dart';
import 'package:one_second_diary/features/clips/data/import_flow.dart';
import 'package:one_second_diary/features/clips/data/import_processor.dart';
import 'package:one_second_diary/features/clips/data/saved_places.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/import_result.dart';
import 'package:one_second_diary/features/clips/presentation/recovered/recovered_clip_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_bloc.dart';
import 'package:one_second_diary/features/onboarding/data/onboarding_store.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profile_form_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/whats_new_quality_cubit.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/convert_profile_sheet.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/locale_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/theme_state.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/user_name_cubit.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_error_scope.dart';

/// The app root, and one of the three places that read the service locator.
///
/// Provides the app-scoped cubits and the movie job, the services the shared
/// flows and media widgets read, the translations (kept on the [LocaleCubit]'s
/// language by [AppLocaleSync]) and `MaterialApp.router`. Starts the post-frame
/// launch once the pages show ([LaunchStarter]), shows the folder migration
/// dialog over any route, and sends a recording Android kept after killing the
/// app to Today ([LostPickListener]).
///
/// A language change rebuilds every page in place ([LocaleRebuildScope]), then
/// the profiles re-read Default's label and the reminders are re-planned. The
/// profiles also re-read once the first language's translations load, since
/// they were read while this root was built.
class OsdApp extends StatelessWidget {
  const OsdApp({super.key});

  @override
  Widget build(BuildContext context) {
    final LocaleCubit locale = sl<LocaleCubit>();
    final GoRouter router = sl<GoRouter>();
    return OsdErrorScope(
      onError: _logUiError,
      child: MultiRepositoryProvider(
        // The services the shared flows and media widgets read. Lazy: each
        // is resolved on its first read, so the first frame builds none of
        // them.
        providers: [
          RepositoryProvider<AppPaths>(create: (_) => sl<AppPaths>()),
          RepositoryProvider<ImportFlow>(create: (_) => sl<ImportFlow>()),
          RepositoryProvider<ImportProcessor>(
            create: (_) => sl<ImportProcessor>(),
          ),
          RepositoryProvider<PermissionRequester>(
            create: (_) => sl<PermissionRequester>(),
          ),
          RepositoryProvider<ClipRepository>(
            create: (_) => sl<ClipRepository>(),
          ),
          RepositoryProvider<ClipStore>(create: (_) => sl<ClipStore>()),
          RepositoryProvider<ClipSubtitles>(create: (_) => sl<ClipSubtitles>()),
          RepositoryProvider<ClipPrivacy>(create: (_) => sl<ClipPrivacy>()),
          RepositoryProvider<ClipAudio>(create: (_) => sl<ClipAudio>()),
          RepositoryProvider<ClipTags>(create: (_) => sl<ClipTags>()),
          RepositoryProvider<TagColors>(create: (_) => sl<TagColors>()),
          RepositoryProvider<SavedPlaces>(create: (_) => sl<SavedPlaces>()),
          RepositoryProvider<ThumbnailRepository>(
            create: (_) => sl<ThumbnailRepository>(),
          ),
          // The form of each profile sheet, which `ProfileSheets` opens from
          // any page.
          RepositoryProvider<ProfileFormFactory>(
            create: (_) => sl<ProfileFormFactory>(),
          ),
          RepositoryProvider<ConvertProfileFactory>(
            create: (_) => sl<ConvertProfileFactory>(),
          ),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<LaunchCubit>.value(value: sl<LaunchCubit>()),
            BlocProvider<ThemeCubit>.value(value: sl<ThemeCubit>()),
            BlocProvider<LocaleCubit>.value(value: locale),
            BlocProvider<ProfilesCubit>.value(value: sl<ProfilesCubit>()),
            BlocProvider<UserNameCubit>.value(value: sl<UserNameCubit>()),
            BlocProvider<RecoveredClipCubit>.value(
              value: sl<RecoveredClipCubit>(),
            ),
            // Lazy, unlike the others: its movie builder brings the media
            // engine, which the first frame must not build. Its container
            // registration disposes it too; a second close is a no-op.
            BlocProvider<MovieJobBloc>(create: (_) => sl<MovieJobBloc>()),
            // The one-time "What's new: quality" flag Today reads.
            BlocProvider<WhatsNewQualityCubit>(
              create: (_) => sl<WhatsNewQualityCubit>(),
            ),
          ],
          child: OsdLocalizationRoot(
            language: locale.state.language,
            child: AppLocaleSync(
              child: BlocSelector<ThemeCubit, ThemeState, (bool, bool)>(
                selector: (ThemeState state) =>
                    (state.darkMode, state.revealed),
                // The stamp previews follow the "legacy font" preference.
                builder: (BuildContext context, (bool, bool) theme) =>
                    StreamBuilder<bool>(
                      stream: sl<SettingsRepository>().legacyStampFont.changes,
                      initialData:
                          sl<SettingsRepository>().legacyStampFont.value,
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<bool> legacyStampFont,
                          ) => OsdMaterialApp(
                            darkMode: theme.$1,
                            animateTheme: !theme.$2,
                            legacyStampFont: legacyStampFont.data ?? false,
                            routerConfig: router,
                            builder: (BuildContext context, Widget? child) =>
                                LocaleRebuildScope(
                                  onLocaleApplied: _localeApplied,
                                  child: LegacyMigrationListener(
                                    navigatorKey:
                                        router.routerDelegate.navigatorKey,
                                    child: LostPickListener(
                                      isOnboarded: () =>
                                          sl<OnboardingStore>().isOnboarded,
                                      recover: () =>
                                          sl<ImportFlow>().recoverLostPick(),
                                      open: (RecoveredClip clip) =>
                                          sl<RecoveredClipCubit>().offer(clip),
                                      child: LaunchStarter(
                                        child: child ?? const SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A failed dialog confirm or snackbar action, in the log file Report
  /// error sends.
  static void _logUiError(
    String message, {
    required Object error,
    required StackTrace stackTrace,
  }) => sl<AppLogger>().error(
    'UI',
    message,
    error: error,
    stackTrace: stackTrace,
  );

  /// What keeps text outside the widget tree follows the new language.
  static void _localeApplied() {
    sl<ProfilesCubit>().localeChanged();
    sl<ReminderPlanWiring>().localeChanged();
  }
}
