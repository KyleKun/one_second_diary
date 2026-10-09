// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/journey_stats_bento.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

/// The Default profile's clip of [day].
ClipRef _clip(LocalDay day) =>
    ClipRef(profile: _default, relPath: '${day.fileStem}.mp4');

void main() {
  /// Default: December 2023, every day, and January 1 to 5, 2024 (today).
  Future<AppRobot> launch(WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: (AppPaths paths) async {
        for (int day = 1; day <= 31; day++) {
          await seedClip(paths, _default, LocalDay(2023, 12, day));
        }
        for (int day = 1; day <= 5; day++) {
          await seedClip(paths, _default, LocalDay(2024, 1, day));
        }
      },
    );
    await app.shell.tapTab(AppRoute.journey);
    await app.harness.settleUntil(
      () => app.journey.hasNumber(JourneyTile.daysRecorded),
      reason: 'the diary was read',
    );
    return app;
  }

  testWidgets('clips picked one by one, across months, make the movie; '
      'back in the picker they are still picked', (WidgetTester tester) async {
    final AppRobot app = await launch(tester);
    await app.journey.tapCreateMovie();

    await app.movies.tapPickVideos();

    app.shell.expectAt(AppRoute.pickClips);
    expect(app.movies.monthHeaders.first, 'JANUARY 2024');
    expect(app.movies.pickedCount, Strings.noneSelected);
    expect(app.movies.canContinuePicks, isFalse);

    await app.movies.tapClip(_clip(LocalDay(2024, 1, 2)));
    await app.movies.tapClip(_clip(LocalDay(2024, 1, 4)));
    expect(app.movies.pickedCount, Strings.selectedCount(2));
    expect(app.movies.canContinuePicks, isTrue);

    await app.movies.tapClip(_clip(LocalDay(2023, 12, 20)));
    expect(app.movies.pickedCount, Strings.selectedCount(3));

    await app.movies.tapPickContinue();

    app.shell.expectAt(AppRoute.confirmMovie);
    expect(app.movies.confirmTitle, Strings.movieTitleHandPicked(3));
    expect(
      app.movies.confirmSummary,
      Strings.movieSummary(
        clips: Strings.clipCount(3),
        profile: Strings.defaultProfile,
        orientation: Strings.landscape,
      ),
    );

    await app.shell.pressBack();
    app.shell.expectAt(AppRoute.pickClips);
    expect(app.movies.pickedCount, Strings.selectedCount(3));
    await app.movies.scrollPickerToTop();
    expect(app.movies.isPicked(_clip(LocalDay(2024, 1, 4))), isTrue);
    expect(app.movies.isPicked(_clip(LocalDay(2024, 1, 5))), isFalse);

    await app.shell.pressBack();
    await app.movies.tapPickVideos();
    expect(
      app.movies.pickedCount,
      Strings.selectedCount(3),
      reason: 'the picks stay while the flow is open',
    );
    app.expectNoPluginChannel();
  });

  testWidgets('Select all picks the whole diary, and a second tap none', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await launch(tester);
    await app.journey.tapCreateMovie();
    await app.movies.tapPickVideos();

    await app.movies.tapSelectAll();
    expect(app.movies.pickedCount, Strings.selectedCount(36));

    await app.movies.tapSelectAll();
    expect(app.movies.pickedCount, Strings.noneSelected);
    app.expectNoPluginChannel();
  });
}
