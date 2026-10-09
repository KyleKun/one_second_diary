// The one-time "What's new: quality" flag: due when the schema step set it,
// cleared once the sheet was answered, and a refused clear is only logged.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/whats_new_quality_cubit.dart';

import '../../../../support/support.dart';
import '../../../../support/track_1c/refusing_shared_preferences.dart';

void main() {
  late MemoryLogSink log;

  setUp(() => log = MemoryLogSink());

  WhatsNewQualityCubit cubitOver(PrefsStore prefs) {
    final WhatsNewQualityCubit cubit = WhatsNewQualityCubit(
      prefs: prefs,
      logger: memoryLogger(log),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('unknown until loaded; due only when the flag is set; dismiss clears '
      'it so the sheet never shows twice', () async {
    final PrefsStore prefs = await openLegacyPrefs(
      legacyPrefs(extra: <String, Object>{'whatsNewQuality': true}),
    );
    final WhatsNewQualityCubit due = cubitOver(prefs);
    expect(due.state, WhatsNewQualityStatus.unknown);

    due.load();
    expect(due.state, WhatsNewQualityStatus.due);

    await due.dismiss();
    expect(due.state, WhatsNewQualityStatus.shown);
    expect(prefs.read(PrefKeys.whatsNewQuality), isFalse);

    final WhatsNewQualityCubit again = cubitOver(prefs)..load();
    expect(again.state, WhatsNewQualityStatus.shown);

    final WhatsNewQualityCubit fresh = cubitOver(
      await openLegacyPrefs(legacyPrefs()),
    )..load();
    expect(fresh.state, WhatsNewQualityStatus.shown);
  });

  test('a refused clear is logged and the sheet counts as shown for this '
      'launch', () async {
    final (PrefsStore prefs, _) = await openRefusingPrefs(
      legacyPrefs(extra: <String, Object>{'whatsNewQuality': true}),
      refused: <String>{'whatsNewQuality'},
    );
    final WhatsNewQualityCubit cubit = cubitOver(prefs)..load();

    await cubit.dismiss();

    expect(cubit.state, WhatsNewQualityStatus.shown);
    expect(log.lines, anyElement(contains('[WARNING]')));
  });
}
