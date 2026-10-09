import 'dart:async';

import 'package:one_second_diary/app/launch/media_start_gate.dart';
import 'package:one_second_diary/app/wiring/legacy_counter_wiring.dart';
import 'package:one_second_diary/app/wiring/library_wiring.dart';
import 'package:one_second_diary/app/wiring/reminder_plan_wiring.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/logging/log_session.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/migrations/legacy_folder_migration.dart';
import 'package:one_second_diary/core/migrations/legacy_migration_event.dart';
import 'package:one_second_diary/core/migrations/orphan_sweep.dart';
import 'package:one_second_diary/core/permissions/access_outcome.dart';
import 'package:one_second_diary/core/permissions/permission_feature.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/platform/app_info_gateway.dart';
import 'package:one_second_diary/core/platform/device_info_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/legacy_prefs_mirror.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/onboarding/data/onboarding_store.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// The launch work that waits for the first frame.
///
/// A plain class (not final), so the launch cubit's tests can fake it.
class PostFrameLaunch {
  /// [logSession] is null when this launch logs to the console (its file
  /// could not be created). [launchPublisher] is the `MediaPublisher` over
  /// the time-limited gateway, used here only for `purgeTrash()`.
  PostFrameLaunch({
    required this._logSession,
    required this._mirror,
    required this._paths,
    required this._deviceInfo,
    required this._appInfo,
    required this._permissions,
    required this._isAndroid,
    required this._onboarding,
    required this._migration,
    required this._launchPublisher,
    required this._sweep,
    required this._mediaGate,
    required this._engine,
    required this._reminderPlan,
    required this._library,
    required this._counters,
    required this._metadata,
    required this._thumbnails,
    required this._clips,
    required this._profiles,
    required this._logger,
  });

  final LogSession? _logSession;
  final LegacyPrefsMirror _mirror;
  final AppPaths _paths;
  final DeviceInfoGateway _deviceInfo;
  final AppInfoGateway _appInfo;

  /// Asks for access to the videos (Android).
  final PermissionRequester _permissions;
  final bool _isAndroid;
  final OnboardingStore _onboarding;
  final LegacyFolderMigration _migration;
  final MediaPublisher _launchPublisher;
  final OrphanSweep _sweep;
  final MediaStartGate _mediaGate;
  final MediaEngine _engine;
  final ReminderPlanWiring _reminderPlan;
  final LibraryWiring _library;
  final LegacyCounterWiring _counters;
  final ClipMetadataCache _metadata;
  final ThumbnailRepository _thumbnails;
  final ClipRepository _clips;
  final ProfilesRepository _profiles;
  final AppLogger _logger;

  static const String _tag = 'APP';

  /// Runs every step once, in order. The folder migration, when one
  /// is needed, reports each event to [onMigrationEvent] for its dialog, or
  /// [onMigrationFailed] when it ends with an error.
  ///
  /// Never throws: a failed step is logged and the launch goes on.
  Future<void> run({
    required void Function(LegacyMigrationEvent event) onMigrationEvent,
    required void Function() onMigrationFailed,
  }) async {
    // What a log that is sent in came from: without it a report names
    // neither the version nor the phone.
    await _step('log the app version and the device', _logWhatRuns);
    // 1. What only a downgrade to an older version reads.
    final LogSession? logSession = _logSession;
    if (logSession != null) {
      await _step('record the log file name', logSession.recordFileName);
      // Never throws; a failure is logged.
      await logSession.deleteOldLogs(logger: _logger);
    }
    await _step(
      'write the legacy path keys',
      () => _mirror.writePathKeys(_paths),
    );
    await _step(
      'write the Android SDK level',
      () async => _mirror.writeSdkVersion(await _deviceInfo.androidSdkInt()),
    );
    // The logs, videos and movies folders. Never before onboarding: once
    // the videos folder exists, a denied storage permission reads as a
    // reinstall and onboarding's permission step is skipped.
    if (_onboarding.isOnboarded) {
      await _step('ask for access to the videos', _askForTheVideos);
      await _step('create the app folders', _paths.createDirectories);
    }
    // 2. The pre-2023 Android folders, behind the migration dialog. Never
    // before onboarding: before it the folders can't be read without the
    // storage permission.
    if (_onboarding.isOnboarded) {
      await _step(
        'migrate the legacy Android folders',
        () => _migrate(
          onMigrationEvent: onMigrationEvent,
          onMigrationFailed: onMigrationFailed,
        ),
      );
    }
    // 3. Pending trash may hold the only copy of a clip.
    await _step('purge the trash', _launchPublisher.purgeTrash);
    // 4. What killed jobs left behind.
    await _step('sweep orphans', () => _sweep.run(isMediaBusy: () => false));
    // 5. Only now may media jobs start: init() empties the scratch folder
    // the migration and the sweep used, and every job awaits it.
    _mediaGate.open();
    unawaited(_engine.init());
    // 6. Reminder taps, then the notification plugin and the reminders.
    await _step('start the notifications', _reminderPlan.start);
    // 7. The caches, then the clip index, the active profile first.
    await _step(
      'load the clip caches',
      () => (_metadata.load(), _thumbnails.load()).wait,
    );
    _library.start();
    _counters.start();
    await _step('load the clips', () {
      final ProfileKey active = _profiles.active.key;
      return _clips.loadAll(
        active: active,
        profiles: <ProfileKey>[
          for (final Profile profile in _profiles.profiles) profile.key,
        ],
      );
    });
  }

  /// `v2.0.0+22 on Android 14 (SDK 34), Google Pixel 8`. Neither gateway
  /// throws.
  Future<void> _logWhatRuns() async {
    final String version = await _appInfo.version();
    final String? build = await _appInfo.buildNumber();
    _logger.info(
      _tag,
      'v$version${build == null ? '' : '+$build'} on '
      '${await _deviceInfo.description()}',
    );
  }

  /// An onboarded Android diary without access to the gallery can't list
  /// or save its clips: on every start until granted, it asks again,
  /// before the folders, the migration and the clips are read, and logs a
  /// refusal. Onboarding asks the first time; nothing to ask on iOS.
  Future<void> _askForTheVideos() async {
    if (!_isAndroid) return;
    const PermissionFeature videos = PermissionFeature.mediaLibrary;
    if (await _permissions.check(videos) == AccessOutcome.granted) return;
    if (await _permissions.request(videos) == AccessOutcome.granted) return;
    _logger.error(
      'StorageUtils',
      'Some storage permissions were not granted for sdk version '
          '${await _deviceInfo.androidSdkInt()}',
    );
  }

  Future<void> _migrate({
    required void Function(LegacyMigrationEvent event) onMigrationEvent,
    required void Function() onMigrationFailed,
  }) async {
    if (!await _migration.isNeeded()) return;
    try {
      await _migration.run().forEach(onMigrationEvent);
    } on Object {
      onMigrationFailed();
      rethrow;
    }
  }

  /// Runs [step], logging a failure instead of stopping the launch.
  Future<void> _step(String name, Future<void> Function() step) async {
    try {
      await step();
    } on Object catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Launch step failed: $name',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
