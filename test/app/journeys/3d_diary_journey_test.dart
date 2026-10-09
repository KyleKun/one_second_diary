// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_mini_player.dart';
import 'package:one_second_diary/features/movies/domain/movie_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hero.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/harness/seeds.dart';
import '../../shared/harness/settle.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

LocalDay jan(int day) => LocalDay(2024, 1, day);

ClipRef clipOf(LocalDay day, {int ordinal = 1}) => ClipRef(
  profile: _default,
  relPath: ordinal == 1
      ? '${day.fileStem}.mp4'
      : '${day.fileStem}-$ordinal.mp4',
);

/// A diary begun on December 30, 2023; January 3 missed, two clips on
/// January 2, nothing yet today (January 5).
Future<void> _seed(AppPaths paths) async {
  await seedClip(paths, _default, LocalDay(2023, 12, 30));
  await seedClip(paths, _default, jan(1));
  await seedDayClips(paths, _default, jan(2), count: 2);
  await seedClip(paths, _default, jan(4));
}

void main() {
  testWidgets('the Diary is ready before its first visit: the selected '
      "day's player opened at launch, hidden, and plays once the tab shows", (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: _seed,
    );
    final String file = app.harness.paths.absoluteFromVideos(
      clipOf(jan(4)).relPath,
    );
    bool isJan4(FakePlayerHandle player) => player.path == file;
    await app.harness.settleUntil(
      () => app.harness.gateways.players.created.any(
        (FakePlayerHandle player) =>
            isJan4(player) && player.value.value.initialized,
      ),
      reason: "the Diary's player of January 4 opens while Today shows",
    );
    final FakePlayerHandle player = app.harness.gateways.players.created
        .singleWhere(isJan4);
    expect(player.value.value.playing, isFalse, reason: 'hidden, it waits');

    await app.shell.tapTab(AppRoute.diary);

    expect(player.value.value.playing, isTrue);
    app.diary.expectSelected(jan(4));
  });

  testWidgets('the selected day plays muted under the calendar and flies to '
      'the viewer, which comes back on the day it showed last', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: _seed,
    );
    await app.shell.tapTab(AppRoute.diary);
    app.diary
      ..expectSelected(jan(4))
      ..expectPlaying(clipOf(jan(4)))
      ..expectCaption('Thursday 4');

    final FakePlayerHandle miniPlayer = app.harness.gateways.players.alive
        .singleWhere(
          (FakePlayerHandle player) =>
              player.path ==
              app.harness.paths.absoluteFromVideos(clipOf(jan(4)).relPath),
        );
    await tester.tap(find.byKey(DiaryMiniPlayer.expandKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(OsdHero.shuttleKey), findsOneWidget);
    await settle(tester);
    app.shell.expectShown(AppRoute.viewer);
    app.diary
      ..expectViewer('Thursday, January 4')
      ..expectPlaying(clipOf(jan(4)));
    // The viewer plays the mini player's warm player, from the start and with
    // sound, instead of opening the clip again.
    expect(miniPlayer.value.value.playing, isTrue);
    expect(miniPlayer.volume, 1);

    await app.diary.viewerPrevious();
    app.diary.expectViewer('Tuesday, January 2');
    // The Diary turns to that day before the video flies back to it.
    await tester.tap(find.byIcon(OsdIcons.closeFullscreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(OsdHero.shuttleKey), findsOneWidget);
    await settle(tester);

    app.shell.expectAt(AppRoute.diary);
    app.diary
      ..expectSelected(jan(2))
      ..expectCaption('Tuesday 2')
      ..expectPlaying(clipOf(jan(2), ordinal: 2));
    app.expectNoPluginChannel();
  });

  testWidgets('Memories lists the diary newest first and opens the viewer', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: _seed,
    );
    await app.shell.tapTab(AppRoute.diary);

    await app.diary.showMemories();
    app.diary
      ..expectMemory(jan(4), title: 'Thursday 4')
      ..expectMemory(jan(2), title: 'Tuesday 2');

    await app.diary.openMemory(jan(2));
    app.diary.expectViewer('Tuesday, January 2');
    await app.diary.closeViewer();

    app.diary.expectMemory(jan(2), title: 'Tuesday 2');
    await app.diary.showCalendar();
    app.diary.expectSelected(jan(2));
  });

  testWidgets('deleting a day\'s clip removes the file for good, says so, '
      'and the day turns missed (CL-10, Q-D9)', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: _seed,
    );
    await app.shell.tapTab(AppRoute.diary);
    app.diary.expectCalendar(month: 'January 2024', count: '3 of 5 days');

    await app.diary.deleteShownClip();

    await app.harness.settleUntil(
      () => app.diary.countText == '2 of 5 days',
      reason: 'the index drops the clip',
    );
    app.diary
      ..expectSnackbar('Video deleted')
      ..expectPanelSays('No video on Thursday 4');
    final String file = app.harness.paths.absoluteFromVideos(
      clipOf(jan(4)).relPath,
    );
    expect(await tester.runAsync(() => File(file).exists()), isFalse);
  });

  testWidgets('deleting today\'s clips, one from D1 and the last from D4, '
      'empties Today and v1.7\'s counters (CL-45)', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: (AppPaths paths) async {
        await _seed(paths);
        await seedDayClips(paths, _default, jan(5), count: 2);
      },
    );
    final SharedPreferences stored = await app.harness.storedPrefs;
    await app.harness.settleUntil(
      () => stored.getBool('dailyEntry') ?? false,
      reason: 'the counters follow the index: today is recorded',
    );
    final int days = stored.getInt('videoCount')!;
    await app.shell.tapTab(AppRoute.diary);
    app.diary
      ..expectSelected(jan(5))
      ..expectPlayerPage(1, count: 2);

    await app.diary.deleteShownClip();
    await app.harness.settleUntil(
      () => !app.diary.pagesClips,
      reason: 'today keeps one clip',
    );
    await app.diary.expand();
    app.diary.expectViewer('Friday, January 5');
    await app.diary.deleteInViewer();
    await app.harness.settleUntil(
      () => app.diary.viewerTitle == 'Thursday, January 4',
      reason: 'today\'s last clip gone, the viewer shows the day before',
    );
    await app.diary.closeViewer();

    await app.harness.settleUntil(
      () =>
          stored.getBool('dailyEntry') == false &&
          stored.getInt('videoCount') == days - 1,
      reason: 'a downgrade finds today not recorded, and a day less',
    );
    await app.shell.tapTab(AppRoute.today);
    app.today.expectEmptyDay();
    app.expectNoPluginChannel();
  });

  testWidgets('a tapped day shows its picture in the same frame, then plays '
      'muted, mixing with the user\'s music (Q-D8)', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: _seed,
    );
    await app.shell.tapTab(AppRoute.diary);
    await app.harness.settleUntil(
      () => app.diary.dayHasPicture(jan(1)),
      reason: 'the grid\'s cells have their pictures',
    );
    app.diary.holdPlayers();

    await app.diary.tapDayOnly(jan(1));

    app.diary
      ..expectSelected(jan(1))
      ..expectPlayerPicture(jan(1));
    await app.diary.readyPlayers();
    app.diary.expectPlayingMuted(clipOf(jan(1)));
    app.expectNoPluginChannel();
  });

  testWidgets('a day of several clips keeps playing the clip shown, paged '
      'with dots: the end of one never moves to the next', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: _seed,
    );
    await app.shell.tapTab(AppRoute.diary);

    await app.diary.tapDay(jan(2));
    app.diary
      ..expectCaption('Tuesday 2')
      ..expectPlayerPage(1, count: 2)
      ..expectPlaying(clipOf(jan(2)));

    await app.diary.finishPlaying(clipOf(jan(2)));
    app.diary.expectPlayerPage(1, count: 2);
  });

  testWidgets('a missed day takes a photo through the editor, for that day '
      '(D2)', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      isAndroid: true,
      seed: _seed,
      configureGateways: (FakeGateways gateways) =>
          gateways.picker.galleryAnswers.add(const Picked('/g/IMG_1.jpg')),
    );
    await app.shell.tapTab(AppRoute.diary);
    await app.diary.tapDay(jan(3));

    await app.diary.tapAddPhoto();
    await app.harness.settleUntil(
      () => app.shell.location.startsWith(AppRoute.editClip.path),
      reason: 'the editor opens on the photo',
    );
    app.shell.expectOpenedWith(
      EditClipArgs(
        source: const PhotoSource(
          path: '/g/IMG_1.jpg',
          ownership: ClipOwnership.userOriginal,
        ),
        day: jan(3),
        profile: _default,
      ),
    );
  });

  testWidgets('Make movie in a Memories header opens M5 on that month', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: _seed,
    );
    await app.shell.tapTab(AppRoute.diary);
    await app.diary.showMemories();

    await app.diary.makeMovieOf(const DiaryMonth(2024, 1));

    app.shell.expectOpenedWith(
      const CreateMovieArgs(source: MovieSource.month(year: 2024, month: 1)),
    );
  });
}
