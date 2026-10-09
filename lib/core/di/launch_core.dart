import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/logging/log_session.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

/// What bootstrap built before the dependency container existed (the only
/// work allowed before the first frame), handed to `registerDependencies`
/// so every later service shares these instances.
final class LaunchCore {
  const LaunchCore({
    required this.clock,
    required this.prefs,
    required this.paths,
    required this.logger,
    required this.logSession,
    required this.settings,
    required this.isAndroid,
    required this.isIOS,
    required this.deviceLanguageCode,
  });

  /// The one source of "now".
  final Clock clock;

  final PrefsStore prefs;

  /// This launch's folders.
  final AppPaths paths;

  /// The app log, over the session file (or the console when it could not
  /// be created).
  final AppLogger logger;

  /// This launch's log file; null when it could not be created, and the
  /// log goes to the console instead.
  final LogSession? logSession;

  /// The settings, already used to settle the theme.
  final SettingsRepository settings;

  /// The platform, from `dart:io`'s `Platform` in the app. Services take
  /// these as flags so tests run on any host.
  final bool isAndroid;
  final bool isIOS;

  /// Reads the device locale's language code (without the region), each
  /// time the app language is resolved.
  final String Function() deviceLanguageCode;
}
