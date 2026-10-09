import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/migrations/schema_migrator.dart';
import 'package:one_second_diary/core/migrations/schema_step.dart';
import 'package:one_second_diary/core/migrations/v3_schema_steps.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/support.dart';

void main() {
  late PrefsStore prefs;
  late MemoryLogSink log;
  late List<int> applied;

  setUp(() {
    log = MemoryLogSink();
    applied = <int>[];
  });

  SchemaStep step(int version) => SchemaStep(
    version: version,
    description: 'step $version',
    apply: () async => applied.add(version),
  );

  Future<SchemaMigrator> migratorWith(
    Map<String, Object> values, {
    required List<SchemaStep> steps,
  }) async {
    prefs = await openLegacyPrefs(values);
    return SchemaMigrator(
      prefs: prefs,
      logger: memoryLogger(log),
      steps: steps,
    );
  }

  test('a v1.x install (no osdSchemaVersion) runs every step in order and '
      'stores the last version', () async {
    final SchemaMigrator migrator = await migratorWith(
      legacyPrefs(),
      steps: <SchemaStep>[step(1), step(2)],
    );

    expect(await migrator.migrate(), 2);

    expect(applied, <int>[1, 2]);
    expect(prefs.read(PrefKeys.osdSchemaVersion), 2);
  });

  test('runs only the steps above the stored version', () async {
    final SchemaMigrator migrator = await migratorWith(
      legacyPrefs(extra: <String, Object>{'osdSchemaVersion': 1}),
      steps: <SchemaStep>[step(1), step(2), step(3)],
    );

    expect(await migrator.migrate(), 3);
    expect(applied, <int>[2, 3]);
  });

  test('a failing step keeps the last good version, logs the error and '
      'throws; the next launch retries from there', () async {
    bool broken = true;
    final List<SchemaStep> steps = <SchemaStep>[
      step(1),
      SchemaStep(
        version: 2,
        description: 'flaky',
        apply: () async {
          if (broken) throw StateError('disk full');
          applied.add(2);
        },
      ),
      step(3),
    ];
    final SchemaMigrator first = await migratorWith(
      legacyPrefs(),
      steps: steps,
    );

    await expectLater(first.migrate(), throwsStateError);
    expect(prefs.read(PrefKeys.osdSchemaVersion), 1);
    expect(
      log.lines,
      contains(allOf(startsWith('[ERROR]'), contains('[MIGRATION]'))),
    );

    broken = false;
    final SchemaMigrator retry = SchemaMigrator(
      prefs: prefs,
      logger: memoryLogger(log),
      steps: steps,
    );
    expect(await retry.migrate(), 3);
    expect(applied, <int>[1, 2, 3]);
  });

  test('a version above every step (a newer v3 ran here) runs nothing and '
      'is kept', () async {
    final SchemaMigrator migrator = await migratorWith(
      legacyPrefs(extra: <String, Object>{'osdSchemaVersion': 9}),
      steps: <SchemaStep>[step(1), step(2)],
    );

    expect(await migrator.migrate(), 9);
    expect(applied, isEmpty);
    expect(prefs.read(PrefKeys.osdSchemaVersion), 9);
  });

  test('steps must be in strictly increasing version order from 1', () async {
    prefs = await openLegacyPrefs(legacyPrefs());
    expect(
      () => SchemaMigrator(
        prefs: prefs,
        logger: memoryLogger(log),
        steps: <SchemaStep>[step(2), step(1)],
      ),
      throwsArgumentError,
    );
    expect(
      () => SchemaMigrator(
        prefs: prefs,
        logger: memoryLogger(log),
        steps: <SchemaStep>[step(0)],
      ),
      throwsArgumentError,
    );
  });

  test('v3\'s own steps start with a baseline that records v3 ran here and '
      'changes nothing v1.7 reads', () async {
    final Map<String, Object> v17 = legacyPrefs(
      profiles: <String>['Default', 'Travel'],
      extra: <String, Object>{'lang': 'pt', 'recordingSeconds': 5},
    );
    prefs = await openLegacyPrefs(v17);
    final SchemaMigrator migrator = SchemaMigrator(
      prefs: prefs,
      logger: memoryLogger(log),
      steps: v3SchemaStepsFor(prefs),
    );

    expect(await migrator.migrate(), v3SchemaVersion);

    // Step 2 adds only the what's-new flag; every v1.7 key is untouched.
    final SharedPreferences stored = await SharedPreferences.getInstance();
    expect(<String, Object?>{
      for (final String key in stored.getKeys())
        if (key != PrefKeys.osdSchemaVersion.name &&
            key != PrefKeys.whatsNewQuality.name)
          key: stored.get(key),
    }, v17);
  });
}
