import 'package:one_second_diary/core/migrations/schema_step.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';

/// The data migrations, for `SchemaMigrator`, oldest first. Append steps
/// with the next version; never renumber or remove one.
///
/// 1. **Baseline.** Every key of older installs stays the source of truth
///    and the rest is derived (`profileMeta` reads as empty, the counters
///    are rewritten by `LegacyPrefsMirror`), so nothing is converted.
///    Storing version 1 records that this schema ran on this install.
/// 2. **Quality.** Nothing to migrate: an absent format is the legacy one.
///    On an existing install (baseline ran, or `showIntro` answered) it
///    sets the one-time `PrefKeys.whatsNewQuality` flag; a fresh install
///    gets none. The flag is only set here and cleared by the sheet.
///
/// `LegacyFolderMigration` and `OrphanSweep` are not versioned steps: they
/// check the disk every launch, because files can reappear (a restore, a
/// downgrade).
List<SchemaStep> v3SchemaStepsFor(PrefsStore prefs) {
  // Decided BEFORE any step runs: the migrator stores the version after
  // each step, so step 2 would otherwise read step 1's write (1) on a
  // fresh install and flag the sheet for a user with nothing new to learn.
  final bool existing =
      prefs.read(PrefKeys.osdSchemaVersion) >= 1 ||
      prefs.contains(PrefKeys.showIntro);
  return List<SchemaStep>.unmodifiable(<SchemaStep>[
    SchemaStep(version: 1, description: 'v3 baseline', apply: () async {}),
    SchemaStep(
      version: 2,
      description: 'quality: what\'s new flag for existing installs',
      apply: () async {
        if (existing) await prefs.write(PrefKeys.whatsNewQuality, true);
      },
    ),
  ]);
}

/// The last version [v3SchemaStepsFor] reaches.
const int v3SchemaVersion = 2;
