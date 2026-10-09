import 'dart:async';

import 'package:flutter/services.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/permissions/permission_requester.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/legacy_prefs_mirror.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_scanner.dart';
import 'package:one_second_diary/features/onboarding/data/onboarding_store.dart';
import 'package:one_second_diary/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile_clip_facts.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../../support/support.dart';
import '../../../support/track_1c/refusing_shared_preferences.dart';

/// The real collaborators of the onboarding flow over a temp folder, the
/// preference store and a scripted permission gateway: what a phone
/// holds when the app starts, for cubit and page tests.
///
/// [cubit] builds the flow's cubit the way the app does at launch; build
/// another over the same world to see what a relaunch would see.
final class OnboardingWorld {
  OnboardingWorld._({
    required this.paths,
    required this.prefs,
    required this.platform,
    required this.permissions,
    required this.deviceInfo,
    required this.profiles,
    required this.clips,
    required this.settings,
    required this.log,
  });

  /// A phone with [prefs] stored (a first launch by default). With
  /// [diaryFolder], the videos folder already exists (a reinstall's);
  /// otherwise nothing has made it yet, as on a fresh install. [sdkInt] is
  /// the Android SDK level (null: iOS).
  static Future<OnboardingWorld> create({
    Map<String, Object> prefs = freshInstallPrefs,
    bool diaryFolder = false,
    int? sdkInt = 34,
  }) async {
    final AppPaths paths = AppPaths.forTest(await createTempRoot());
    if (diaryFolder) await paths.createDirectories();
    final (PrefsStore store, RefusingSharedPreferences platform) =
        await openRefusingPrefs(prefs);
    final MemoryLogSink log = MemoryLogSink();
    final AppLogger logger = memoryLogger(log);
    return OnboardingWorld._(
      paths: paths,
      prefs: store,
      platform: platform,
      permissions: FailingPermissionGateway(),
      deviceInfo: FakeDeviceInfoGateway(sdkInt: sdkInt),
      profiles: ProfilesRepository(
        prefs: store,
        paths: paths,
        mediaStore: FakeMediaStoreGateway(),
        clock: FakeClock(DateTime(2024, 1, 5, 10)),
        logger: logger,
        defaultLabel: () => 'Default',
      ),
      clips: ClipRepository(
        scanner: ClipScanner(paths: paths, logger: logger),
        paths: paths,
        logger: logger,
      ),
      settings: SettingsRepository(prefs: store),
      log: log,
    );
  }

  final AppPaths paths;
  final PrefsStore prefs;

  /// The platform under [prefs]: add a key to `refused` to make the phone
  /// refuse writing it.
  final RefusingSharedPreferences platform;

  /// What the user answers to permission prompts.
  final FailingPermissionGateway permissions;
  final FakeDeviceInfoGateway deviceInfo;
  final ProfilesRepository profiles;
  final ClipRepository clips;
  final SettingsRepository settings;
  final MemoryLogSink log;

  AppLogger get logger => memoryLogger(log);

  /// The phone's clock: 2024-01-05 10:00.
  final FakeClock clock = FakeClock(DateTime(2024, 1, 5, 10));

  /// The reader of Default's clips on a reinstall (none: they cannot be
  /// read, so a reinstall is landscape and legacy).
  ProfileClipFacts? clipFacts;

  /// The flow's cubit, as the app builds it when onboarding opens.
  OnboardingCubit cubit() => OnboardingCubit(
    store: OnboardingStore(
      prefs: prefs,
      profiles: profiles,
      mirror: LegacyPrefsMirror(prefs: prefs),
      paths: paths,
      logger: logger,
      clipFacts: clipFacts,
    ),
    permissions: PermissionRequester(
      permissions: permissions,
      deviceInfo: deviceInfo,
      logger: logger,
    ),
    deviceInfo: deviceInfo,
    forceNativeCamera: settings.forceNativeCamera,
    profiles: profiles,
    userName: settings.userName,
    clips: clips,
    clock: clock,
    logger: logger,
  );
}

/// The shared [FakePermissionGateway], whose plugin can also fail, as
/// permission_handler does when a request is already running.
class FailingPermissionGateway extends FakePermissionGateway {
  /// Whether checking a status throws.
  bool failChecks = false;

  /// Whether asking throws.
  bool failRequests = false;

  /// While set, a request waits for it: the system prompt is up.
  Completer<void>? promptUp;

  @override
  Future<AppPermissionStatus> status(AppPermission permission) {
    if (failChecks) throw PlatformException(code: 'status failed');
    return super.status(permission);
  }

  @override
  Future<Map<AppPermission, AppPermissionStatus>> requestAll(
    Set<AppPermission> permissions,
  ) async {
    if (failRequests) {
      throw PlatformException(
        code: 'PermissionHandler.PermissionManager',
        message: 'A request for permissions is already running',
      );
    }
    await promptUp?.future;
    return super.requestAll(permissions);
  }
}
