import 'dart:io';

import 'package:get_it/get_it.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/platform/app_info_gateway.dart';
import 'package:one_second_diary/core/platform/archive_gateway.dart';
import 'package:one_second_diary/core/platform/camera_gateway.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/device_info_gateway.dart';
import 'package:one_second_diary/core/platform/dual_camera_gateway.dart';
import 'package:one_second_diary/core/platform/email_gateway.dart';
import 'package:one_second_diary/core/platform/ffmpeg_gateway.dart';
import 'package:one_second_diary/core/platform/free_space_gateway.dart';
import 'package:one_second_diary/core/platform/location_gateway.dart';
import 'package:one_second_diary/core/platform/media_store_gateway.dart';
import 'package:one_second_diary/core/platform/notification_channel_text.dart';
import 'package:one_second_diary/core/platform/notification_tap.dart';
import 'package:one_second_diary/core/platform/notifications_gateway.dart';
import 'package:one_second_diary/core/platform/orientation_sensor_gateway.dart';
import 'package:one_second_diary/core/platform/pending_notification.dart';
import 'package:one_second_diary/core/platform/permission_gateway.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/core/platform/player_factory.dart';
import 'package:one_second_diary/core/platform/screen_orientation_gateway.dart';
import 'package:one_second_diary/core/platform/share_gateway.dart';
import 'package:one_second_diary/core/platform/thumbnail_gateway.dart';
import 'package:one_second_diary/core/platform/time_zone_gateway.dart';
import 'package:one_second_diary/core/platform/url_gateway.dart';
import 'package:one_second_diary/core/platform/volume_key_gateway.dart';
import 'package:one_second_diary/core/platform/wakelock_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

import '../../support/support.dart';
import '../../support/track_1d/fake_archive_gateway.dart';
import '../../support/track_1d/fake_time_zone_gateway.dart';
import '../fakes/fake_app_info_gateway.dart';
import '../fakes/fake_camera_gateway.dart';
import '../fakes/fake_dual_camera_gateway.dart';
import '../fakes/fake_free_space_gateway.dart';
import '../fakes/fake_picker_gateway.dart';
import '../fakes/fake_screen_orientation_gateway.dart';
import '../fakes/fake_sensor_gateways.dart';

/// A fake for every platform gateway the DI container registers, for tests
/// that build the real service graph (`registerDependencies(overrides:
/// gateways.register)`).
///
/// The fakes are the shared ones of `test/support`, except that the calls
/// they otherwise leave no trace of (the SDK level, the encoder listing, the
/// time zone, the notification plugin, the wakelock) are written to
/// [calls], so a launch test can tell what reached the platform and when.
/// Call [close] in `tearDown`.
final class FakeGateways {
  /// [paths] makes the media store move and delete real files under it
  /// (`FakeMediaStoreGateway.onDisk`); without it the store records only.
  ///
  /// [calls] is the list the recorded calls go to; pass a test's own
  /// journal to see them in order with other events.
  FakeGateways({required Clock clock, AppPaths? paths, List<String>? calls})
    : calls = calls ?? <String>[],
      mediaStore = paths == null
          ? FakeMediaStoreGateway()
          : FakeMediaStoreGateway.onDisk(paths),
      camera = FakeCameraGateway(
        recordingsDir:
            '${paths?.temporaryDir ?? Directory.systemTemp.path}/fake_camera',
      ) {
    notifications = _RecordingNotificationsGateway(
      clock: clock,
      calls: this.calls,
    );
    ffmpeg = _RecordingFfmpegGateway(calls: this.calls);
    deviceInfo = _RecordingDeviceInfoGateway(calls: this.calls);
    timeZone = _RecordingTimeZoneGateway(calls: this.calls);
    wakelock = _RecordingWakelockGateway(calls: this.calls);
  }

  /// `<gateway>.<method>` for each recorded call, in call order.
  final List<String> calls;

  late final FakeFfmpegGateway ffmpeg;
  final FakeMediaStoreGateway mediaStore;
  final FakeThumbnailGateway thumbnails = FakeThumbnailGateway();
  final FakePlayerFactory players = FakePlayerFactory();
  final FakePermissionGateway permissions = FakePermissionGateway();
  final FakeLocationGateway location = FakeLocationGateway();
  late final FakeNotificationsGateway notifications;
  late final FakeDeviceInfoGateway deviceInfo;
  late final FakeWakelockGateway wakelock;
  final FakeShareGateway share = FakeShareGateway();
  final FakeUrlGateway urls = FakeUrlGateway();
  final FakeEmailGateway email = FakeEmailGateway();
  final FakeArchiveGateway archive = FakeArchiveGateway();
  late final FakeTimeZoneGateway timeZone;
  final FakeAppInfoGateway appInfo = FakeAppInfoGateway();

  /// The in-app camera; recordings are written under the temp folder.
  final FakeCameraGateway camera;

  /// Both cameras at once: a phone that can't, unless a test says so.
  late final FakeDualCameraGateway dualCamera = FakeDualCameraGateway(camera);
  final FakeOrientationSensorGateway orientation =
      FakeOrientationSensorGateway();
  final FakeVolumeKeyGateway volumeKeys = FakeVolumeKeyGateway();

  /// The gallery pickers, the system camera and profile photos.
  final FakePickerGateway picker = FakePickerGateway();

  /// The free space a movie checks: unknown, as on iOS, until a test says
  /// how much is free.
  final FakeFreeSpaceGateway freeSpace = FakeFreeSpaceGateway();

  /// Which ways the screen may turn.
  final FakeScreenOrientationGateway screenOrientation =
      FakeScreenOrientationGateway();

  /// Whether anything reached a platform gateway.
  bool get untouched =>
      calls.isEmpty &&
      ffmpeg.executed.isEmpty &&
      ffmpeg.probed.isEmpty &&
      ffmpeg.fontDirectories.isEmpty &&
      mediaStore.calls.isEmpty &&
      thumbnails.requests.isEmpty &&
      players.created.isEmpty &&
      permissions.requested.isEmpty &&
      permissions.requestedTogether.isEmpty &&
      location.localesRequested.isEmpty &&
      share.sharedFiles.isEmpty &&
      share.sharedTexts.isEmpty &&
      urls.opened.isEmpty &&
      email.sent.isEmpty &&
      email.mailtos.isEmpty &&
      archive.zips.isEmpty &&
      appInfo.versionReads == 0 &&
      camera.sessions.isEmpty &&
      !orientation.listening &&
      !volumeKeys.listening &&
      screenOrientation.changes.isEmpty &&
      picker.untouched;

  /// Registers every fake against its gateway interface. Pass it as the
  /// `overrides` of `registerDependencies`.
  void register(GetIt sl) {
    sl
      ..registerSingleton<FfmpegGateway>(ffmpeg)
      ..registerSingleton<MediaStoreGateway>(mediaStore)
      ..registerSingleton<ThumbnailGateway>(thumbnails)
      ..registerSingleton<PlayerFactory>(players)
      ..registerSingleton<PermissionGateway>(permissions)
      ..registerSingleton<LocationGateway>(location)
      ..registerSingleton<NotificationsGateway>(notifications)
      ..registerSingleton<DeviceInfoGateway>(deviceInfo)
      ..registerSingleton<WakelockGateway>(
        wakelock,
        instanceName: DiNames.platformWakelock,
      )
      ..registerSingleton<ShareGateway>(share)
      ..registerSingleton<UrlGateway>(urls)
      ..registerSingleton<EmailGateway>(email)
      ..registerSingleton<ArchiveGateway>(archive)
      ..registerSingleton<TimeZoneGateway>(timeZone)
      ..registerSingleton<AppInfoGateway>(appInfo)
      ..registerSingleton<CameraGateway>(camera)
      ..registerSingleton<DualCameraGateway>(dualCamera)
      ..registerSingleton<OrientationSensorGateway>(orientation)
      ..registerSingleton<VolumeKeyGateway>(volumeKeys)
      ..registerSingleton<PickerGateway>(picker)
      ..registerSingleton<FreeSpaceGateway>(freeSpace)
      ..registerSingleton<ScreenOrientationGateway>(screenOrientation);
  }

  Future<void> close() async {
    await notifications.close();
    await orientation.close();
    await volumeKeys.close();
  }
}

class _RecordingNotificationsGateway extends FakeNotificationsGateway {
  _RecordingNotificationsGateway({required super.clock, required this.calls});

  final List<String> calls;

  @override
  Stream<NotificationTap> get taps {
    calls.add('notifications.taps');
    return super.taps;
  }

  @override
  Future<void> initialize({required NotificationChannelText channel}) {
    calls.add('notifications.initialize');
    return super.initialize(channel: channel);
  }

  @override
  Future<void> updateChannel(NotificationChannelText channel) {
    calls.add('notifications.updateChannel');
    return super.updateChannel(channel);
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
    required bool persistent,
  }) {
    calls.add('notifications.schedule');
    return super.schedule(
      id: id,
      at: at,
      title: title,
      body: body,
      persistent: persistent,
    );
  }

  @override
  Future<void> cancel(int id) {
    calls.add('notifications.cancel');
    return super.cancel(id);
  }

  @override
  Future<void> cancelAll() {
    calls.add('notifications.cancelAll');
    return super.cancelAll();
  }

  @override
  Future<List<PendingNotification>> pending() {
    calls.add('notifications.pending');
    return super.pending();
  }
}

class _RecordingFfmpegGateway extends FakeFfmpegGateway {
  _RecordingFfmpegGateway({required this.calls});

  final List<String> calls;

  @override
  Future<String> listEncoders() {
    calls.add('ffmpeg.listEncoders');
    return super.listEncoders();
  }
}

class _RecordingDeviceInfoGateway extends FakeDeviceInfoGateway {
  _RecordingDeviceInfoGateway({required this.calls});

  final List<String> calls;

  @override
  Future<int?> androidSdkInt() {
    calls.add('deviceInfo.androidSdkInt');
    return super.androidSdkInt();
  }
}

class _RecordingTimeZoneGateway extends FakeTimeZoneGateway {
  _RecordingTimeZoneGateway({required this.calls}) : super('Europe/Berlin');

  final List<String> calls;

  @override
  Future<String> localTimeZoneName() {
    calls.add('timeZone.localTimeZoneName');
    return super.localTimeZoneName();
  }
}

class _RecordingWakelockGateway extends FakeWakelockGateway {
  _RecordingWakelockGateway({required this.calls});

  final List<String> calls;

  @override
  Future<void> enable() {
    calls.add('wakelock.enable');
    return super.enable();
  }

  @override
  Future<void> disable() {
    calls.add('wakelock.disable');
    return super.disable();
  }
}
