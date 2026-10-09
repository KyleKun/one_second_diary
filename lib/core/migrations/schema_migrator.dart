import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/migrations/schema_step.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';

/// Keeps `osdSchemaVersion`: which data migrations ran on this install.
///
/// 0 (absent) is an older install, or a fresh one. Each [SchemaStep] above
/// the stored version runs in order, and the version is stored after each
/// one succeeds, so a kill or a failure resumes at the step that did not
/// finish. Steps must therefore be idempotent. They must also leave every
/// older key readable by an older build: a downgrade and a later upgrade
/// keep the stored version, so a step never runs twice on the same install
/// even though the older build may have changed the data meanwhile.
///
/// A stored version above every step means a newer build ran here; nothing
/// runs and the version is kept.
final class SchemaMigrator {
  /// Throws an [ArgumentError] unless [steps] have versions 1 or more, in
  /// strictly increasing order.
  SchemaMigrator({
    required this._prefs,
    required this._logger,
    required List<SchemaStep> steps,
  }) : _steps = List<SchemaStep>.unmodifiable(steps) {
    int previous = 0;
    for (final SchemaStep step in _steps) {
      if (step.version <= previous) {
        throw ArgumentError.value(
          step.version,
          'steps',
          'versions must start at 1 and increase',
        );
      }
      previous = step.version;
    }
  }

  final PrefsStore _prefs;
  final AppLogger _logger;
  final List<SchemaStep> _steps;

  static const String _tag = 'MIGRATION';

  /// Runs the pending steps and returns the stored version afterwards.
  ///
  /// A step that throws is logged and rethrown; the version stays at the
  /// last step that succeeded, so the next launch retries it.
  Future<int> migrate() async {
    final int stored = _prefs.read(PrefKeys.osdSchemaVersion);
    for (final SchemaStep step in _steps) {
      if (step.version <= stored) continue;
      try {
        await step.apply();
      } on Object catch (error, stackTrace) {
        _logger.error(
          _tag,
          'Schema step ${step.version} (${step.description}) failed',
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      }
      await _prefs.write(PrefKeys.osdSchemaVersion, step.version);
      _logger.info(
        _tag,
        'Schema step ${step.version} (${step.description}) done',
      );
    }
    return _prefs.read(PrefKeys.osdSchemaVersion);
  }
}
