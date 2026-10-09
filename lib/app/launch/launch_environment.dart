import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:one_second_diary/core/logging/global_error_handlers.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/system_chrome_orientation_gateway.dart';
import 'package:one_second_diary/core/platform/system_clock.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:path_provider/path_provider.dart';

/// What the launch reads from the platform, and the process-wide set-up it
/// does, before the dependency container exists: the seams of
/// `launchApp`, so tests can run it on any host with fakes.
final class LaunchEnvironment {
  const LaunchEnvironment({
    required this.clock,
    required this.isAndroid,
    required this.isIOS,
    required this.openPrefs,
    required this.resolvePaths,
    required this.documentsPath,
    required this.platformIsDark,
    required this.deviceLanguageCode,
    required this.installErrorHandlers,
    required this.loadDateSymbols,
    required this.loadTranslations,
    required this.printLog,
    required this.lockPortrait,
  });

  factory LaunchEnvironment.device() => LaunchEnvironment(
    clock: const SystemClock(),
    isAndroid: Platform.isAndroid,
    isIOS: Platform.isIOS,
    openPrefs: PrefsStore.open,
    resolvePaths: AppPaths.resolve,
    documentsPath: () async => (await getApplicationDocumentsDirectory()).path,
    platformIsDark: () =>
        PlatformDispatcher.instance.platformBrightness == Brightness.dark,
    deviceLanguageCode: () => PlatformDispatcher.instance.locale.languageCode,
    installErrorHandlers: (GlobalErrorHandlers handlers) => handlers.install(),
    loadDateSymbols: initializeDateFormatting,
    loadTranslations: EasyLocalization.ensureInitialized,
    printLog: debugPrint,
    lockPortrait: const SystemChromeOrientationGateway().portraitOnly,
  );

  final Clock clock;
  final bool isAndroid;
  final bool isIOS;
  final Future<PrefsStore> Function() openPrefs;

  /// `AppPaths.resolve`: throws a `StorageException` on an Android device
  /// without a storage root.
  final Future<AppPaths> Function() resolvePaths;

  /// The app's private Documents folder, where older installs wrote clips
  /// when there was no storage root: the storage error state names it.
  final Future<String> Function() documentsPath;

  /// Whether the phone is in dark mode.
  final bool Function() platformIsDark;

  /// The device language, without the region.
  final String Function() deviceLanguageCode;
  final void Function(GlobalErrorHandlers handlers) installErrorHandlers;

  /// Loads intl's date symbols for every language.
  final Future<void> Function() loadDateSymbols;
  final Future<void> Function() loadTranslations;

  /// Where log lines go when the session log file cannot be created.
  final void Function(String line) printLog;
  final Future<void> Function() lockPortrait;
}
