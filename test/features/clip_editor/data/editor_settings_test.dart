// The clip editor's remembered settings (SettingsRepository): the last
// quick cut and the framing sheet's fill per canvas.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/clip_editor/domain/quick_cuts.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../../support/support.dart';

void main() {
  group('the last quick cut', () {
    test('reads 1.5 s until one is tapped; only a quick cut counts on read, '
        'anything else reads as 1.5 s; storing anything else throws', () async {
      for (final (int? stored, int read) in <(int?, int)>[
        (null, 1500),
        (1000, 1000),
        (60000, 60000),
        (2222, 1500),
        (0, 1500),
        (-1, 1500),
      ]) {
        final SettingsRepository settings = SettingsRepository(
          prefs: await openLegacyPrefs(
            legacyPrefs(extra: <String, Object>{'lastQuickCutMs': ?stored}),
          ),
        );
        expect(settings.lastQuickCut.value, read, reason: '$stored');
      }

      final PrefsStore prefs = await openLegacyPrefs(legacyPrefs());
      final SettingsRepository settings = SettingsRepository(prefs: prefs);
      await settings.lastQuickCut.set(3000);
      expect(prefs.read(PrefKeys.lastQuickCutMs), 3000);
      expect(settings.lastQuickCut.value, 3000);
      await expectLater(
        () => settings.lastQuickCut.set(2500),
        throwsArgumentError,
      );
      expect(settings.lastQuickCut.value, 3000);
    });

    test('the chips run 1, 1.5, 2, 3, 5, 10, 15, 30, 60 s; the default is '
        'among them', () {
      expect(QuickCuts.lengthsMs, <int>[
        1000,
        1500,
        2000,
        3000,
        5000,
        10000,
        15000,
        30000,
        60000,
      ]);
      expect(QuickCuts.lengthsMs, contains(QuickCuts.defaultMs));
      expect(QuickCuts.accepted(null), 1500);
      expect(QuickCuts.accepted(15000), 15000);
      expect(QuickCuts.accepted(15001), 1500);
    });
  });

  test('the framing fill is blur by default on a portrait canvas and black '
      'on a landscape one, each remembered on its own', () async {
    final PrefsStore prefs = await openLegacyPrefs(legacyPrefs());
    final SettingsRepository settings = SettingsRepository(prefs: prefs);

    expect(
      settings.framingFill(VideoOrientation.portrait).value,
      FrameFill.blur,
    );
    expect(
      settings.framingFill(VideoOrientation.landscape).value,
      FrameFill.black,
    );

    await settings.framingFill(VideoOrientation.portrait).set(FrameFill.black);
    await settings.framingFill(VideoOrientation.landscape).set(FrameFill.blur);

    expect(prefs.read(PrefKeys.framingBlurPortrait), isFalse);
    expect(prefs.read(PrefKeys.framingBlurLandscape), isTrue);
    expect(
      settings.framingFill(VideoOrientation.portrait).value,
      FrameFill.black,
    );
    expect(
      settings.framingFill(VideoOrientation.landscape).value,
      FrameFill.blur,
    );
  });
}
