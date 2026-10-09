import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/app/launch/launch_environment.dart';
import 'package:one_second_diary/app/launch/storage_error_app.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/core/di/launch_core.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/l10n/osd_localization.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/logging/global_error_handlers.dart';
import 'package:one_second_diary/core/logging/log_session.dart';
import 'package:one_second_diary/core/migrations/schema_migrator.dart';
import 'package:one_second_diary/core/migrations/v3_schema_steps.dart';
import 'package:one_second_diary/core/platform/console_log_sink.dart';
import 'package:one_second_diary/core/platform/log_sink.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/features/settings/domain/app_language.dart';

/// Launches the app.
///
/// Before the first frame, only what the first frame needs: the portrait
/// lock, the preference store, the folders, this launch's log file (with
/// the global error handlers on it), the theme, the schema version, the
/// date symbols, the translations and intl's default locale (the app
/// language); then the dependency container, which builds nothing yet. No
/// other platform call and no folder is made here; in particular the diary
/// folders are never created before onboarding.
///
/// Then [runApp] shows [buildApp]'s widget. The rest (`PostFrameLaunch`)
/// starts from the widget tree, once the app's pages show
/// (`LaunchStarter`), so the migration dialog's listener is mounted first.
///
/// On an Android device without a storage root (`AppPaths.resolve` throws
/// a `StorageException`) only [StorageErrorApp] runs: nothing else is
/// built, and no folder, log file or preference is written.
///
/// [overrides] replaces registrations of the container (tests register a
/// fake for every gateway).
Future<void> launchApp({
  required LaunchEnvironment environment,
  required Widget Function() buildApp,
  required void Function(Widget app) runApp,
  DependencyOverrides? overrides,
}) async {
  // Portrait before anything shows, the storage error state included.
  await environment.lockPortrait();
  final PrefsStore prefs = await environment.openPrefs();
  final SettingsRepository settings = SettingsRepository(prefs: prefs);
  final AppPaths paths;
  try {
    paths = await environment.resolvePaths();
  } on StorageException catch (error, stackTrace) {
    // No folder, so no log file either: say it on the console.
    environment.printLog('Launch stopped, $error\n$stackTrace');
    await environment.loadTranslations();
    final AppLanguage language = settings.appLanguage(
      deviceLanguageCode: environment.deviceLanguageCode(),
    );
    OsdLocalization.applyToIntl(language);
    runApp(
      StorageErrorApp(
        language: language,
        darkMode: settings.darkMode.value,
        legacyVideosPath: await _legacyVideosPath(environment),
      ),
    );
    return;
  }
  final (LogSession? logSession, AppLogger logger) = await _openLog(
    environment: environment,
    prefs: prefs,
    paths: paths,
  );
  environment.installErrorHandlers(GlobalErrorHandlers(logger: logger));
  await _settleTheme(
    environment: environment,
    settings: settings,
    logger: logger,
  );
  await _migrateSchema(prefs: prefs, logger: logger);
  await environment.loadDateSymbols();
  await environment.loadTranslations();
  // `LocaleCubit` resolves the same language and `AppLocaleSync` keeps
  // intl on it from then on.
  OsdLocalization.applyToIntl(
    settings.appLanguage(deviceLanguageCode: environment.deviceLanguageCode()),
  );
  registerDependencies(
    core: LaunchCore(
      clock: environment.clock,
      prefs: prefs,
      paths: paths,
      logger: logger,
      logSession: logSession,
      settings: settings,
      isAndroid: environment.isAndroid,
      isIOS: environment.isIOS,
      deviceLanguageCode: environment.deviceLanguageCode,
    ),
    overrides: overrides,
  );
  runApp(buildApp());
}

const String _tag = 'APP';

/// Where older installs saved clips on a device without a storage root;
/// null when even the private folder is unknown.
Future<String?> _legacyVideosPath(LaunchEnvironment environment) async {
  try {
    return AppPaths.legacyPrivateVideos(
      documents: await environment.documentsPath(),
    );
  } on Object catch (error) {
    environment.printLog('The private documents folder is unknown: $error');
    return null;
  }
}

/// This launch's log file and the logger on it. When the file cannot be
/// created, the log goes to the console instead, and says why.
Future<(LogSession?, AppLogger)> _openLog({
  required LaunchEnvironment environment,
  required PrefsStore prefs,
  required AppPaths paths,
}) async {
  final LogSession session = LogSession(
    paths: paths,
    prefs: prefs,
    clock: environment.clock,
  );
  LogSink sink;
  Object? failure;
  StackTrace? failureStack;
  try {
    sink = await session.open();
    // A debug run shows the log in the terminal too (never under tests,
    // whose console stays quiet).
    if (kDebugMode && !Platform.environment.containsKey('FLUTTER_TEST')) {
      sink = EchoingLogSink(sink, print: environment.printLog);
    }
  } on StorageException catch (error, stackTrace) {
    sink = ConsoleLogSink(print: environment.printLog);
    failure = error;
    failureStack = stackTrace;
  }
  final AppLogger logger = AppLogger(
    sink: sink,
    clock: environment.clock,
    isVerboseEnabled: () => prefs.read(PrefKeys.verboseLogging),
  );
  if (failure == null) return (session, logger);
  logger.error(
    'LOGS',
    'Could not create the log file; logging to the console',
    error: failure,
    stackTrace: failureStack,
  );
  return (null, logger);
}

/// A refused write keeps the stored (or default) theme.
Future<void> _settleTheme({
  required LaunchEnvironment environment,
  required SettingsRepository settings,
  required AppLogger logger,
}) async {
  try {
    await settings.settleThemeOnLaunch(
      platformIsDark: environment.platformIsDark(),
    );
  } on StorageException catch (error, stackTrace) {
    logger.error(
      _tag,
      'Could not store the theme',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// A failed step is logged by the migrator and retried at the next launch;
/// the app runs on the old keys meanwhile.
Future<void> _migrateSchema({
  required PrefsStore prefs,
  required AppLogger logger,
}) async {
  try {
    await SchemaMigrator(
      prefs: prefs,
      logger: logger,
      steps: v3SchemaStepsFor(prefs),
    ).migrate();
  } on Object {
    // Logged by the migrator.
  }
}
