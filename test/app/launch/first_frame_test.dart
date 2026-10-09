import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:one_second_diary/app/launch/launch_app.dart';
import 'package:one_second_diary/app/launch/launch_environment.dart';
import 'package:one_second_diary/app/launch/post_frame_launch.dart';
import 'package:one_second_diary/app/osd_app.dart';
import 'package:one_second_diary/app/wiring/app_lifecycle_states.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/logging/global_error_handlers.dart';
import 'package:one_second_diary/core/media/media_engine.dart';
import 'package:one_second_diary/core/migrations/legacy_folder_migration.dart';
import 'package:one_second_diary/core/platform/device_info_gateway.dart';
import 'package:one_second_diary/core/platform/ffmpeg_gateway.dart';
import 'package:one_second_diary/core/platform/notifications_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/reminders/data/reminder_scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/support.dart';

/// Runs the real dependency graph, with the real gateways, as an Android
/// device would (no fakes), for exactly one frame.
void main() {
  setUpAll(() {
    EasyLocalization.logger.enableLevels = [];
  });

  testWidgets('builds no launch service and calls no plugin', (
    WidgetTester tester,
  ) async {
    final List<String> channels = <String>[];
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    messenger.allMessagesHandler =
        (String channel, MessageHandler? handler, ByteData? message) {
          channels.add(channel);
          return handler != null
              ? handler(message)
              : messenger.delegate.send(channel, message);
        };
    addTearDown(() async {
      messenger.allMessagesHandler = null;
      rootBundle.clear();
      // A launch service built in this frame's fake-async zone would await
      // that zone in its dispose, forever: fail instead of hanging.
      await sl.reset().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw StateError(
          'The first frame built services that never dispose',
        ),
      );
    });
    await tester.runAsync(sl.reset);
    final AppPaths paths = (await tester.runAsync(createTestPaths))!;
    final FakeClock clock = FakeClock(DateTime(2024, 1, 5, 10));
    SharedPreferences.setMockInitialValues(legacyPrefs());
    Widget? app;
    await tester.runAsync(
      () => launchApp(
        environment: LaunchEnvironment(
          clock: clock,
          isAndroid: true,
          isIOS: false,
          openPrefs: PrefsStore.open,
          resolvePaths: () async => paths,
          documentsPath: () async => paths.internal,
          platformIsDark: () => true,
          deviceLanguageCode: () => 'en',
          installErrorHandlers: (GlobalErrorHandlers handlers) {},
          loadDateSymbols: initializeDateFormatting,
          loadTranslations: EasyLocalization.ensureInitialized,
          printLog: (String line) {},
          lockPortrait: () async {},
        ),
        buildApp: () => const OsdApp(),
        runApp: (Widget widget) => app = widget,
      ),
    );

    await tester.pumpWidget(app!);

    expect(
      channels.where((String channel) => !channel.startsWith('flutter/')),
      isEmpty,
    );
    expect(sl.checkLazySingletonInstanceExists<PostFrameLaunch>(), isFalse);
    expect(sl.checkLazySingletonInstanceExists<MediaEngine>(), isFalse);
    expect(sl.checkLazySingletonInstanceExists<FfmpegGateway>(), isFalse);
    expect(
      sl.checkLazySingletonInstanceExists<NotificationsGateway>(),
      isFalse,
    );
    expect(sl.checkLazySingletonInstanceExists<DeviceInfoGateway>(), isFalse);
    expect(
      sl.checkLazySingletonInstanceExists<LegacyFolderMigration>(),
      isFalse,
    );
    expect(sl.checkLazySingletonInstanceExists<ReminderScheduler>(), isFalse);
    expect(sl.checkLazySingletonInstanceExists<AppLifecycleStates>(), isFalse);
  });
}
