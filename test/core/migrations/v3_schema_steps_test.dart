// Schema step 2: nothing to migrate, but an install that existed before owes the user the
// one-time "What's new: quality" sheet; a fresh install does not. Idempotent and safe to run
// after a kill.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/migrations/schema_migrator.dart';
import 'package:one_second_diary/core/migrations/v3_schema_steps.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';

import '../../support/support.dart';

void main() {
  Future<PrefsStore> migrated(Map<String, Object> values) async {
    final PrefsStore prefs = await openLegacyPrefs(values);
    await SchemaMigrator(
      prefs: prefs,
      logger: memoryLogger(MemoryLogSink()),
      steps: v3SchemaStepsFor(prefs),
    ).migrate();
    return prefs;
  }

  test(
    'a v1.x install (showIntro answered) and a 2.0 install (baseline '
    'ran) get the flag; a fresh install does not; the version ends at 2',
    () async {
      final PrefsStore v1 = await migrated(legacyPrefs());
      expect(v1.read(PrefKeys.whatsNewQuality), isTrue);
      expect(v1.read(PrefKeys.osdSchemaVersion), v3SchemaVersion);

      final PrefsStore v2 = await migrated(<String, Object>{
        'osdSchemaVersion': 1,
        'profiles': <String>['Default'],
      });
      expect(v2.read(PrefKeys.whatsNewQuality), isTrue);

      final PrefsStore fresh = await migrated(<String, Object>{});
      expect(fresh.read(PrefKeys.whatsNewQuality), isFalse);
      expect(fresh.read(PrefKeys.osdSchemaVersion), v3SchemaVersion);
    },
  );

  test('idempotent: run twice on the same install, and after the sheet '
      'cleared the flag, nothing sets it again', () async {
    final PrefsStore prefs = await migrated(legacyPrefs());
    await prefs.write(PrefKeys.whatsNewQuality, false);

    await SchemaMigrator(
      prefs: prefs,
      logger: memoryLogger(MemoryLogSink()),
      steps: v3SchemaStepsFor(prefs),
    ).migrate();

    expect(prefs.read(PrefKeys.whatsNewQuality), isFalse);
    expect(prefs.read(PrefKeys.osdSchemaVersion), v3SchemaVersion);
  });
}
