import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:one_second_diary/app/launch/gated_media_engine.dart';
import 'package:one_second_diary/app/launch/launch_cubit.dart';
import 'package:one_second_diary/app/launch/media_start_gate.dart';
import 'package:one_second_diary/app/launch/post_frame_launch.dart';
import 'package:one_second_diary/app/wiring/active_profile_clips.dart';
import 'package:one_second_diary/app/wiring/app_lifecycle_states.dart';
import 'package:one_second_diary/app/wiring/legacy_counter_wiring.dart';
import 'package:one_second_diary/app/wiring/library_wiring.dart';
import 'package:one_second_diary/app/wiring/reminder_plan_wiring.dart';
import 'package:one_second_diary/core/di/launch_core.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/location/location_service.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/logging/bug_report_service.dart';
import 'package:one_second_diary/core/logging/log_session.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/media/policy/date_stamp.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/migrations/legacy_folder_migration.dart';
import 'package:one_second_diary/core/migrations/orphan_sweep.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/platform/android_volume_key_gateway.dart';
import 'package:one_second_diary/core/platform/app_info_gateway.dart';
import 'package:one_second_diary/core/platform/archive_gateway.dart';
import 'package:one_second_diary/core/platform/audio_picker_gateway.dart';
import 'package:one_second_diary/core/platform/camera_gateway.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/device_info_free_space_gateway.dart';
import 'package:one_second_diary/core/platform/device_info_gateway.dart';
import 'package:one_second_diary/core/platform/device_info_plus_gateway.dart';
import 'package:one_second_diary/core/platform/dual_camera_gateway.dart';
import 'package:one_second_diary/core/platform/email_gateway.dart';
import 'package:one_second_diary/core/platform/email_sender_gateway.dart';
import 'package:one_second_diary/core/platform/ffmpeg_gateway.dart';
import 'package:one_second_diary/core/platform/ffmpeg_kit_gateway.dart';
import 'package:one_second_diary/core/platform/flutter_archive_gateway.dart';
import 'package:one_second_diary/core/platform/flutter_timezone_gateway.dart';
import 'package:one_second_diary/core/platform/free_space_gateway.dart';
import 'package:one_second_diary/core/platform/geolocator_location_gateway.dart';
import 'package:one_second_diary/core/platform/get_thumbnail_video_gateway.dart';
import 'package:one_second_diary/core/platform/local_notifications_gateway.dart';
import 'package:one_second_diary/core/platform/location_gateway.dart';
import 'package:one_second_diary/core/platform/media_store_gateway.dart';
import 'package:one_second_diary/core/platform/media_store_plus_gateway.dart';
import 'package:one_second_diary/core/platform/native_orientation_sensor_gateway.dart';
import 'package:one_second_diary/core/platform/notification_channel_text.dart';
import 'package:one_second_diary/core/platform/notification_tap.dart';
import 'package:one_second_diary/core/platform/notifications_gateway.dart';
import 'package:one_second_diary/core/platform/orientation_sensor_gateway.dart';
import 'package:one_second_diary/core/platform/package_info_plus_gateway.dart';
import 'package:one_second_diary/core/platform/permission_gateway.dart';
import 'package:one_second_diary/core/platform/permission_handler_gateway.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/core/platform/player_factory.dart';
import 'package:one_second_diary/core/platform/plugin_audio_picker_gateway.dart';
import 'package:one_second_diary/core/platform/plugin_camera_gateway.dart';
import 'package:one_second_diary/core/platform/plugin_dual_camera_gateway.dart';
import 'package:one_second_diary/core/platform/plugin_picker_gateway.dart';
import 'package:one_second_diary/core/platform/sandbox_media_store_gateway.dart';
import 'package:one_second_diary/core/platform/screen_orientation_gateway.dart';
import 'package:one_second_diary/core/platform/share_gateway.dart';
import 'package:one_second_diary/core/platform/share_plus_gateway.dart';
import 'package:one_second_diary/core/platform/shared_wakelock.dart';
import 'package:one_second_diary/core/platform/still_photo_converter.dart';
import 'package:one_second_diary/core/platform/system_chrome_orientation_gateway.dart';
import 'package:one_second_diary/core/platform/thumbnail_gateway.dart';
import 'package:one_second_diary/core/platform/time_limited_media_store_gateway.dart';
import 'package:one_second_diary/core/platform/time_zone_gateway.dart';
import 'package:one_second_diary/core/platform/url_gateway.dart';
import 'package:one_second_diary/core/platform/url_launcher_gateway.dart';
import 'package:one_second_diary/core/platform/video_player_factory.dart';
import 'package:one_second_diary/core/platform/volume_key_gateway.dart';
import 'package:one_second_diary/core/platform/wakelock_gateway.dart';
import 'package:one_second_diary/core/platform/wakelock_plus_gateway.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/app_router.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/legacy_prefs_mirror.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/local_time_zone.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clip_editor/clip_editor_injection.dart';
import 'package:one_second_diary/features/clips/data/clip_audio.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_backfill.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_privacy.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/data/clip_subtitles.dart';
import 'package:one_second_diary/features/clips/data/clip_tags.dart';
import 'package:one_second_diary/features/clips/data/import_flow.dart';
import 'package:one_second_diary/features/clips/data/import_processor.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/originals_store.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/data/profile_converter.dart';
import 'package:one_second_diary/features/clips/data/saved_places.dart';
import 'package:one_second_diary/features/clips/data/tag_batch.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_queue.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_conversion.dart';
import 'package:one_second_diary/features/clips/presentation/recovered/recovered_clip_cubit.dart';
import 'package:one_second_diary/features/diary/diary_injection.dart';
import 'package:one_second_diary/features/journey/journey_injection.dart';
import 'package:one_second_diary/features/movies/data/movie_builder.dart';
import 'package:one_second_diary/features/movies/data/movie_index.dart';
import 'package:one_second_diary/features/movies/data/movie_repository.dart';
import 'package:one_second_diary/features/movies/movies_injection.dart';
import 'package:one_second_diary/features/onboarding/data/engine_device_media_check_runner.dart';
import 'package:one_second_diary/features/onboarding/data/onboarding_store.dart';
import 'package:one_second_diary/features/onboarding/domain/camera_capability_probe.dart';
import 'package:one_second_diary/features/onboarding/domain/device_media_check_runner.dart';
import 'package:one_second_diary/features/onboarding/onboarding_injection.dart';
import 'package:one_second_diary/features/profiles/data/device_media_profile_store.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/profiles_injection.dart';
import 'package:one_second_diary/features/recording/data/gateway_camera_capability_probe.dart';
import 'package:one_second_diary/features/recording/recording_injection.dart';
import 'package:one_second_diary/features/reminders/data/reminder_scheduler.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_settings.dart';
import 'package:one_second_diary/features/reminders/domain/reminder_text.dart';
import 'package:one_second_diary/features/reminders/reminders_injection.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/settings_injection.dart';
import 'package:one_second_diary/features/today/today_injection.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

/// The app's service locator. Only the composition files read it: this
/// file, `app/osd_app.dart`, and each feature's
/// `features/<f>/<f>_injection.dart` and `features/<f>/<f>_routes.dart`
/// (`service_locator_guard_test.dart`). Widgets use `context.read` /
/// `watch` / `select`; services take every dependency through their
/// constructor.
final GetIt sl = GetIt.instance;

/// Registrations that replace the real ones (tests register a fake for
/// every gateway).
typedef DependencyOverrides = void Function(GetIt sl);

/// The names of the second registration of a type.
abstract final class DiNames {
  /// The time-limited media store gateway and the `MediaPublisher` of the
  /// launch chain (the folder migration and `purgeTrash()`), which
  /// gates `MediaEngine.init()` and so must finish.
  static const String launchChain = 'launchChain';

  /// The time-limited media store gateway of `ProfilesRepository` (profile
  /// deletion may raise one consent prompt per file).
  static const String profileDeletion = 'profileDeletion';

  /// The platform's wakelock (`wakelock_plus`), which only the app's
  /// `SharedWakelock` drives: every owner takes the shared one, so one
  /// letting go never turns the screen lock off under another.
  static const String platformWakelock = 'platformWakelock';
}

/// How long a launch-chain gallery call may take before it reads as not
/// done. Nothing in the chain normally prompts; the folder migration's
/// delete of an original from before a reinstall may, and a minute is time
/// to answer it.
const Duration launchChainTimeLimit = Duration(minutes: 1);

/// How long a profile-deletion gallery call may take: long enough for a
/// person to read and answer one consent prompt, as the gateway's own queue
/// allows.
const Duration profileDeletionTimeLimit = MediaStorePlusGateway.turnTimeLimit;

/// The reminders' Android status-bar icon: the app logo as a white
/// silhouette (`android/app/src/main/res/drawable/ic_notification.xml`).
/// `res/raw/keep.xml` keeps it through resource shrinking, because the
/// plugin looks it up by name.
const String reminderSmallIcon = '@drawable/ic_notification';

/// Registers every service, in phases (platform gateways, stores and
/// repositories, services, app-level wiring), over what bootstrap built
/// before the first frame ([core]). Everything is lazy, and the first frame
/// asks only for what the app root shows: the app-scoped cubits and the
/// router, with the stores and repositories they read. That calls no
/// platform (the media store plugin is made on its first call). The launch
/// services, and every platform plugin behind them, are built after it,
/// when `LaunchCubit.start` asks for `PostFrameLaunch`.
///
/// [overrides] runs last and may register any type again, replacing the
/// real one: tests register a fake for every gateway there
/// (`test/shared/harness/fake_gateways.dart`).
///
/// One media store gateway serves the whole app (its calls run one at a
/// time); only the callers that must finish get a time-limited wrapper of
/// it ([DiNames]). The `MediaPublisher` that saves and replaces clips never
/// does: it deletes the render on `false`, and a consent answered after the
/// limit would then lose the old clip.
void registerDependencies({
  required LaunchCore core,
  DependencyOverrides? overrides,
}) {
  _registerLaunchCore(core);
  _registerPlatformGateways(core);
  _registerStoresAndRepositories(core);
  _registerServices(core);
  _registerApp(core);
  _registerFeatures();
  if (overrides == null) return;
  sl.allowReassignment = true;
  try {
    overrides(sl);
  } finally {
    sl.allowReassignment = false;
  }
}

void _registerLaunchCore(LaunchCore core) {
  sl
    // The platform flags and the device language, for the feature files.
    ..registerSingleton<LaunchCore>(core)
    ..registerSingleton<Clock>(core.clock)
    ..registerSingleton<PrefsStore>(core.prefs)
    ..registerSingleton<AppPaths>(core.paths)
    ..registerSingleton<AppLogger>(core.logger)
    ..registerSingleton<SettingsRepository>(core.settings);
  final LogSession? logSession = core.logSession;
  if (logSession != null) sl.registerSingleton<LogSession>(logSession);
}

void _registerPlatformGateways(LaunchCore core) {
  sl
    ..registerLazySingleton<FfmpegGateway>(FfmpegKitGateway.new)
    ..registerLazySingleton<MediaStoreGateway>(
      () => core.isAndroid
          ? MediaStorePlusGateway(
              mediaStore: MediaStore.new,
              byPath: SandboxMediaStoreGateway(paths: sl(), logger: sl()),
              logger: sl(),
            )
          : SandboxMediaStoreGateway(paths: sl(), logger: sl()),
    )
    ..registerLazySingleton<MediaStoreGateway>(
      () => TimeLimitedMediaStoreGateway(
        inner: sl(),
        timeLimit: launchChainTimeLimit,
        logger: sl(),
      ),
      instanceName: DiNames.launchChain,
    )
    ..registerLazySingleton<MediaStoreGateway>(
      () => TimeLimitedMediaStoreGateway(
        inner: sl(),
        timeLimit: profileDeletionTimeLimit,
        logger: sl(),
      ),
      instanceName: DiNames.profileDeletion,
    )
    ..registerLazySingleton<ThumbnailGateway>(
      () => GetThumbnailVideoGateway(logger: sl()),
    )
    ..registerLazySingleton<PlayerFactory>(VideoPlayerFactory.new)
    ..registerLazySingleton<PermissionGateway>(
      () => PermissionHandlerGateway(logger: sl()),
    )
    ..registerLazySingleton<LocationGateway>(
      () => const GeolocatorLocationGateway(),
    )
    ..registerLazySingleton<NotificationsGateway>(
      () => LocalNotificationsGateway(
        plugin: FlutterLocalNotificationsPlugin(),
        timeZone: sl(),
        clock: sl(),
        logger: sl(),
        androidSmallIcon: reminderSmallIcon,
      ),
    )
    ..registerLazySingleton<DeviceInfoGateway>(
      () => DeviceInfoPlusGateway(
        plugin: DeviceInfoPlugin(),
        isAndroid: core.isAndroid,
      ),
    )
    ..registerLazySingleton<WakelockGateway>(
      () => WakelockPlusGateway(logger: sl()),
      instanceName: DiNames.platformWakelock,
    )
    // A fresh `DeviceInfoPlugin` each time: the plugin caches its answers.
    ..registerLazySingleton<FreeSpaceGateway>(
      () => DeviceInfoFreeSpaceGateway(
        isAndroid: core.isAndroid,
        androidInfo: () => DeviceInfoPlugin().androidInfo,
        logger: sl(),
      ),
    )
    // Every owner of the screen lock shares one reference-counted hold.
    ..registerLazySingleton<WakelockGateway>(
      () =>
          SharedWakelock(platform: sl(instanceName: DiNames.platformWakelock)),
    )
    ..registerLazySingleton<ShareGateway>(
      () => SharePlusGateway(sharePlus: SharePlus.instance, logger: sl()),
    )
    ..registerLazySingleton<UrlGateway>(() => UrlLauncherGateway(logger: sl()))
    ..registerLazySingleton<EmailGateway>(() => EmailSenderGateway(urls: sl()))
    ..registerLazySingleton<ArchiveGateway>(() => const FlutterArchiveGateway())
    ..registerLazySingleton<TimeZoneGateway>(
      () => const FlutterTimezoneGateway(),
    )
    ..registerLazySingleton<AppInfoGateway>(
      () =>
          PackageInfoPlusGateway(read: PackageInfo.fromPlatform, logger: sl()),
    )
    ..registerLazySingleton<CameraGateway>(
      () => PluginCameraGateway(
        listCameras: availableCameras,
        createController: PluginCameraGateway.controllerFor,
        logger: sl(),
      ),
    )
    ..registerLazySingleton<DualCameraGateway>(
      () => PluginDualCameraGateway(logger: sl()),
    )
    ..registerLazySingleton<OrientationSensorGateway>(
      NativeOrientationSensorGateway.new,
    )
    // Portrait, but for the pages that may turn.
    ..registerLazySingleton<ScreenOrientationGateway>(
      () => const SystemChromeOrientationGateway(),
    )
    ..registerLazySingleton<VolumeKeyGateway>(
      () => AndroidVolumeKeyGateway(isAndroid: core.isAndroid),
    )
    ..registerLazySingleton<PickerGateway>(
      () => PluginPickerGateway(
        imagePicker: ImagePicker(),
        clock: sl(),
        isAndroid: core.isAndroid,
        logger: sl(),
      ),
    )
    ..registerLazySingleton<AudioPickerGateway>(
      () => PluginAudioPickerGateway(paths: sl(), clock: sl(), logger: sl()),
    );
}

void _registerStoresAndRepositories(LaunchCore core) {
  sl
    ..registerLazySingleton<LegacyPrefsMirror>(
      () => LegacyPrefsMirror(prefs: sl()),
    )
    ..registerLazySingleton<LocalTimeZone>(
      () => LocalTimeZone(gateway: sl(), logger: sl()),
    )
    ..registerLazySingleton<MidnightTicker>(() => MidnightTicker(clock: sl()))
    ..registerLazySingleton<ProfilesRepository>(
      () => ProfilesRepository(
        prefs: sl(),
        paths: sl(),
        mediaStore: sl(instanceName: DiNames.profileDeletion),
        clock: sl(),
        logger: sl(),
        defaultLabel: () => Strings.defaultProfile,
        clipFacts: sl(),
      ),
    )
    ..registerLazySingleton<OnboardingStore>(
      () => OnboardingStore(
        prefs: sl(),
        profiles: sl(),
        mirror: sl(),
        paths: sl(),
        logger: sl(),
        clipFacts: sl(),
      ),
    )
    ..registerLazySingleton<LegacyFolderMigration>(
      () => LegacyFolderMigration(
        paths: sl(),
        mediaStore: sl(instanceName: DiNames.launchChain),
        wakelock: sl(),
        profiles: sl(),
        logger: sl(),
        isAndroid: core.isAndroid,
      ),
    )
    ..registerLazySingleton<OrphanSweep>(
      () => OrphanSweep(paths: sl(), clock: sl(), logger: sl()),
    )
    // The originals moved beside the diary (`OneSecondDiary Originals/`):
    // the raw gateway, one consent per batch.
    ..registerLazySingleton<OriginalsStore>(
      () => OriginalsStore(
        paths: sl(),
        gateway: sl(),
        logger: sl(),
        isAndroid: core.isAndroid,
      ),
    )
    // Saves, replaces and deletes clips and movies: the raw gateway.
    ..registerLazySingleton<MediaPublisher>(
      () => MediaPublisher(
        gateway: sl(),
        paths: sl(),
        logger: sl(),
        clock: sl(),
        originals: sl(),
      ),
    )
    // Only `purgeTrash()` at launch.
    ..registerLazySingleton<MediaPublisher>(
      () => MediaPublisher(
        gateway: sl(instanceName: DiNames.launchChain),
        paths: sl(),
        logger: sl(),
        clock: sl(),
        originals: sl(),
      ),
      instanceName: DiNames.launchChain,
    )
    ..registerLazySingleton<ClipScanner>(
      () => ClipScanner(paths: sl(), logger: sl()),
    )
    ..registerLazySingleton<ClipRepository>(
      () => ClipRepository(scanner: sl(), paths: sl(), logger: sl()),
    )
    ..registerLazySingleton<ClipMetadataCache>(
      () => ClipMetadataCache(paths: sl(), logger: sl()),
    )
    // One queue in front of the thumbnail plugin for the clips' thumbnails
    // and the movie posters, so the two share one bound on decodes.
    ..registerLazySingleton<ThumbnailQueue>(ThumbnailQueue.new)
    ..registerLazySingleton<ThumbnailRepository>(
      () => ThumbnailRepository(
        gateway: sl(),
        queue: sl(),
        metadata: sl(),
        paths: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton<ClipStore>(
      () => ClipStore(
        publisher: sl(),
        repository: sl(),
        metadata: sl(),
        thumbnails: sl(),
        paths: sl(),
        logger: sl(),
        isIOS: core.isIOS,
      ),
    )
    ..registerLazySingleton<MovieIndex>(
      () => MovieIndex(paths: sl(), logger: sl(), clock: sl()),
    )
    ..registerLazySingleton<MovieRepository>(
      () => MovieRepository(
        index: sl(),
        publisher: sl(),
        prefs: sl(),
        paths: sl(),
        logger: sl(),
      ),
    );
}

void _registerServices(LaunchCore core) {
  sl
    // Every media job waits for the launch to open the gate.
    ..registerLazySingleton<MediaStartGate>(MediaStartGate.new)
    ..registerLazySingleton<MediaEngine>(
      () => GatedMediaEngine(
        gate: sl(),
        ffmpeg: sl(),
        paths: sl(),
        logger: sl(),
        clock: sl(),
        loadAsset: rootBundle.load,
        isIOS: core.isIOS,
        freeSpace: sl(),
      ),
    )
    ..registerLazySingleton<ClipMetadataBackfill>(
      () => ClipMetadataBackfill(
        engine: sl(),
        cache: sl(),
        paths: sl(),
        logger: sl(),
        clock: sl(),
      ),
    )
    // One pool per screen that plays clips; `muted` is its starting mode.
    ..registerFactoryParam<PlayerPool, bool, void>(
      (bool muted, _) => PlayerPool(factory: sl(), logger: sl(), muted: muted),
    )
    ..registerLazySingleton<MovieBuilder>(
      () => MovieBuilder(
        engine: sl(),
        clips: sl(),
        metadata: sl(),
        movies: sl(),
        publisher: sl(),
        paths: sl(),
        clock: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton<PermissionRequester>(
      () => PermissionRequester(
        permissions: sl(),
        deviceInfo: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton<LocationService>(
      () => LocationService(location: sl(), permissions: sl(), logger: sl()),
    )
    ..registerLazySingleton<ReminderScheduler>(
      () => ReminderScheduler(
        notifications: sl(),
        readSettings: () => _reminderSettings(sl()),
        timeZone: sl(),
        clock: sl(),
        logger: sl(),
      ),
    )
    // Add video / Add photo / the system camera.
    ..registerLazySingleton<ImportFlow>(
      () => ImportFlow(
        picker: sl(),
        settings: sl(),
        deviceInfo: sl(),
        paths: sl(),
        clock: sl(),
        logger: sl(),
        isAndroid: core.isAndroid,
        isIOS: core.isIOS,
        firstCellLabel: _pickerFirstCellLabel,
        stillPhotos: const UiStillPhotoConverter(),
      ),
    )
    // Processes the videos another app put in the diary folder
    //. On Android the gateway itself knows
    // whether the SDK asks a consent for files it does not own.
    ..registerLazySingleton<ImportProcessor>(
      () => ImportProcessor(
        engine: sl(),
        store: sl(),
        clips: sl(),
        metadata: sl(),
        mediaStore: sl(),
        wakelock: sl(),
        backfill: sl(),
        settings: sl(),
        formatOf: _profileFormatOf,
        paths: sl(),
        logger: sl(),
        requiresWriteConsent: core.isAndroid,
        prefs: sl(),
        originals: sl(),
        speedOf: _encodeSpeedOf,
      ),
    )
    // "Convert into a new profile": the one
    // `ProfileConversionStarter`, before the features that read it.
    ..registerLazySingleton<ProfileConversionStarter>(
      () => ProfileConverter(
        engine: sl(),
        store: sl(),
        clips: sl(),
        metadata: sl(),
        freeSpace: sl(),
        wakelock: sl(),
        backfill: sl(),
        formatOf: _profileFormatOf,
        paths: sl(),
        logger: sl(),
        speedOf: _encodeSpeedOf,
        // A clip with a kept original and its recipe is re-rendered from
        // the source, stamped in the app language.
        originals: sl(),
        keepOriginals: () => sl<SettingsRepository>().keepOriginals.value,
        legacyStampFont: () => sl<SettingsRepository>().legacyStampFont.value,
        stampTextOf: (LocalDay day, StampFormat format) =>
            _conversionStampText(core, day, format),
      ),
    )
    // The phone check's parts the engine and the camera provide.
    ..registerLazySingleton<DeviceMediaCheckRunner>(
      () => EngineDeviceMediaCheckRunner(
        engine: sl(),
        paths: sl(),
        loadAsset: rootBundle.load,
        logger: sl(),
      ),
    )
    ..registerLazySingleton<CameraCapabilityProbe>(
      () => GatewayCameraCapabilityProbe(
        camera: sl(),
        engine: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton<ClipSubtitles>(
      () => ClipSubtitles(
        engine: sl(),
        publisher: sl(),
        repository: sl(),
        metadata: sl(),
        thumbnails: sl(),
        paths: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton<ClipPrivacy>(
      () => ClipPrivacy(
        engine: sl(),
        publisher: sl(),
        repository: sl(),
        metadata: sl(),
        thumbnails: sl(),
        paths: sl(),
        logger: sl(),
        // The kept original follows the clip's privacy mark.
        originals: sl(),
      ),
    )
    ..registerLazySingleton<ClipAudio>(
      () => ClipAudio(
        engine: sl(),
        publisher: sl(),
        repository: sl(),
        metadata: sl(),
        thumbnails: sl(),
        paths: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton<TagColors>(
      () => TagColors(prefs: sl(), logger: sl()),
      dispose: (TagColors colors) => colors.dispose(),
    )
    ..registerLazySingleton<SavedPlaces>(
      () => SavedPlaces(prefs: sl(), logger: sl()),
      dispose: (SavedPlaces places) => places.dispose(),
    )
    ..registerLazySingleton<TagBatch>(
      () => TagBatch(tags: sl(), clips: sl(), colors: sl(), logger: sl()),
    )
    ..registerLazySingleton<ClipTags>(
      () => ClipTags(
        engine: sl(),
        publisher: sl(),
        repository: sl(),
        metadata: sl(),
        thumbnails: sl(),
        paths: sl(),
        logger: sl(),
      ),
    )
    ..registerLazySingleton<BugReportService>(
      () => BugReportService(
        logger: sl(),
        paths: sl(),
        archive: sl(),
        email: sl(),
        appInfo: sl(),
        logsUnavailable: () => Strings.contactLogsUnavailable,
      ),
    );
}

void _registerApp(LaunchCore core) {
  sl
    ..registerLazySingleton<AppLifecycleStates>(
      AppLifecycleStates.new,
      dispose: (AppLifecycleStates states) => states.dispose(),
    )
    // One per wiring that follows the active profile's clips.
    ..registerFactory<ActiveProfileClips>(
      () => ActiveProfileClips(profiles: sl(), clips: sl()),
    )
    // The session-long wiring the post-frame launch starts.
    ..registerLazySingleton<ReminderPlanWiring>(
      () => ReminderPlanWiring(
        notifications: sl(),
        reminders: sl(),
        reminderText: () => ReminderText(
          title: Strings.notificationTitle,
          body: Strings.notificationBody,
        ),
        channelText: () => NotificationChannelText(
          name: Strings.notificationsChannelName,
          description: Strings.notificationsChannelDescription,
        ),
        settings: sl(),
        activeClips: sl(),
        clock: sl(),
        logger: sl(),
        onNotificationTap: _reminderTapped,
      ),
      dispose: (ReminderPlanWiring wiring) => wiring.dispose(),
    )
    ..registerLazySingleton<LibraryWiring>(
      () => LibraryWiring(
        profiles: sl(),
        clips: sl(),
        backfill: sl(),
        thumbnails: sl(),
        metadata: sl(),
        originals: sl(),
        midnight: sl(),
        lifecycleStates: sl<AppLifecycleStates>().states,
        logger: sl(),
      ),
      dispose: (LibraryWiring wiring) => wiring.dispose(),
    )
    ..registerLazySingleton<LegacyCounterWiring>(
      () => LegacyCounterWiring(
        activeClips: sl(),
        mirror: sl(),
        midnight: sl(),
        clock: sl(),
        logger: sl(),
      ),
      dispose: (LegacyCounterWiring wiring) => wiring.dispose(),
    )
    ..registerLazySingleton<PostFrameLaunch>(
      () => PostFrameLaunch(
        logSession: core.logSession,
        mirror: sl(),
        paths: sl(),
        deviceInfo: sl(),
        appInfo: sl(),
        permissions: sl(),
        isAndroid: core.isAndroid,
        onboarding: sl(),
        migration: sl(),
        launchPublisher: sl(instanceName: DiNames.launchChain),
        sweep: sl(),
        mediaGate: sl(),
        engine: sl(),
        reminderPlan: sl(),
        library: sl(),
        counters: sl(),
        metadata: sl(),
        thumbnails: sl(),
        clips: sl(),
        profiles: sl(),
        logger: sl(),
      ),
    )
    // Built by the first frame; the launch behind it only when it starts.
    ..registerLazySingleton<LaunchCubit>(
      () => LaunchCubit(launch: () => sl<PostFrameLaunch>()),
    )
    // A recording Android kept, from the app root to Today.
    ..registerLazySingleton<RecoveredClipCubit>(
      RecoveredClipCubit.new,
      dispose: (RecoveredClipCubit cubit) => cubit.close(),
    )
    ..registerLazySingleton<GoRouter>(
      () =>
          buildAppRouter(isOnboarded: () => sl<OnboardingStore>().isOnboarded),
      dispose: (GoRouter router) => router.dispose(),
    );
}

/// Each feature's own registrations (`lib/features/<f>/<f>_injection.dart`):
/// its screen, flow and app-scoped cubits. They resolve only the core
/// services above.
void _registerFeatures() {
  registerOnboarding(sl);
  registerToday(sl);
  registerRecording(sl);
  registerClipEditor(sl);
  registerDiary(sl);
  registerJourney(sl);
  registerMovies(sl);
  registerSettings(sl);
  registerProfiles(sl);
  registerReminders(sl);
}

/// A reminder opens Today, also for an app already running, but only while
/// the root navigator shows the tabs (or onboarding, whose gate then keeps
/// it). Over a full-screen page, a sheet or a dialog (the camera, the clip
/// editor, the viewer, the Create movie flow), going would replace the root
/// stack and drop unsaved work without asking, past any `PopScope`; the OS
/// has already brought the app to the front, so the page stays. The tap that
/// launches the app finds only the tabs and opens Today.
void _reminderTapped(NotificationTap tap) {
  final GoRouter router = sl<GoRouter>();
  final bool pageOnTop =
      router.routerDelegate.navigatorKey.currentState?.canPop() ?? false;
  sl<AppLogger>().info(
    'NOTIFICATIONS',
    'Reminder tapped (id ${tap.id})${pageOnTop ? ', kept the open page' : ''}',
  );
  if (!pageOnTop) router.go(AppRoute.today.path);
}

/// The first cell of the in-app picker's grid, in the app language: the
/// latest videos or photos, or the day a date-filtered pick starts at.
String _pickerFirstCellLabel({
  required PickerMedia media,
  required LocalDay? from,
}) => from != null
    ? Strings.importPickerFromDay(
        date: DateFormat.yMd().format(from.toLocalDateTime()),
      )
    : switch (media) {
        PickerMedia.video => Strings.importPickerLatestVideos,
        PickerMedia.photo => Strings.importPickerLatestPhotos,
      };

/// The write-once format of a profile's clips, for the
/// services that render into a profile: one source of truth, the profiles
/// repository.
ClipFormat _profileFormatOf(ProfileKey profile) =>
    sl<ProfilesRepository>().formatOf(profile);

/// How fast this phone encodes [format], as the phone check measured it
///; real time when it never ran or never tried
/// that format.
double _encodeSpeedOf(ClipFormat format) =>
    sl<DeviceMediaProfileStore>().read()?.encodeOf(format)?.realtimeFactor ??
    1.0;

/// The date stamp of [day] in [format] for a clip re-rendered from its
/// kept original by the profile converter: the app language with the
/// phone's region, as the clip editor's preview draws it
/// (`DateStamp.displayLocale`).
String _conversionStampText(LaunchCore core, LocalDay day, StampFormat format) {
  final Locale device = PlatformDispatcher.instance.locale;
  return DateStamp.text(
    day,
    format: format,
    locale: DateStamp.displayLocale(
      appLanguage: core.settings
          .appLanguage(deviceLanguageCode: core.deviceLanguageCode())
          .code,
      deviceLanguage: device.languageCode,
      deviceRegion: device.countryCode,
    ),
  );
}

/// The stored reminder settings, read at each re-plan.
ReminderSettings _reminderSettings(SettingsRepository settings) =>
    ReminderSettings(
      enabled: settings.remindersEnabled.value,
      persistent: settings.persistentReminder.value,
      time: settings.reminderTime.value,
    );
