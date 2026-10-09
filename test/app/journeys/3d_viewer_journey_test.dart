// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/clip_actions_sheet.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/memory_card.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/harness/seeds.dart';
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
  testWidgets('a long press on a day flies its picture to the viewer, even '
      'while the mini player shows the same clip, and back to the day '
      'shown last', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: _seed,
    );
    await app.shell.tapTab(AppRoute.diary);
    app.diary.expectSelected(jan(4));
    // The app is portrait, but the viewer may turn.
    final List<String> screen = app.harness.gateways.screenOrientation.changes;
    expect(screen, <String>['portrait']);

    await app.diary.startOpeningDay(jan(4));
    app.diary.expectFlight();
    await app.diary.land();
    app.shell.expectShown(AppRoute.viewer);
    app.diary.expectViewer('Thursday, January 4');
    expect(screen.last, 'landscape');

    await app.diary.viewerPrevious();
    await app.diary.viewerPrevious();
    app.diary.expectViewer('Tuesday, January 2');
    await app.diary.startClosingViewer();
    app.diary.expectFlight();
    await app.diary.land();

    app.shell.expectAt(AppRoute.diary);
    app.diary
      ..expectSelected(jan(2))
      ..expectCaption('Tuesday 2');
    expect(screen.last, 'portrait');
    expect(tester.takeException(), isNull);
    app.expectNoPluginChannel();
  });

  testWidgets('a swipe down closes the viewer, the Diary showing through as '
      'it goes; the Diary\'s player holds still meanwhile', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: _seed,
    );
    await app.shell.tapTab(AppRoute.diary);
    await app.diary.expand();
    app.diary.expectViewer('Thursday, January 4');

    final TestGesture finger = await app.diary.dragViewerDown(200);
    app.diary
      ..expectDiaryShowsThrough()
      ..expectDiaryPlayerHeld(clipOf(jan(4)));
    await app.diary.release(finger);

    app.shell.expectAt(AppRoute.diary);
    app.diary
      ..expectSelected(jan(4))
      ..expectPlaying(clipOf(jan(4)));
    expect(tester.takeException(), isNull);
    app.expectNoPluginChannel();
  });

  testWidgets('from Memories, the viewer steps through a day\'s clips, then '
      'the recorded days, both ways; back on the day shown last', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: _seed,
    );
    await app.shell.tapTab(AppRoute.diary);
    await app.diary.showMemories();

    await app.diary.openMemory(jan(2));
    app.diary
      ..expectViewer('Tuesday, January 2')
      ..expectViewerSubtitle('1 of 2')
      ..expectPlaying(clipOf(jan(2)));

    await app.diary.viewerNext();
    app.diary
      ..expectViewer('Tuesday, January 2')
      ..expectViewerSubtitle('2 of 2')
      ..expectPlaying(clipOf(jan(2), ordinal: 2));

    await app.diary.viewerNext();
    app.diary
      ..expectViewer('Thursday, January 4')
      ..expectViewerSubtitle(null);

    await app.diary.viewerPrevious();
    await app.diary.viewerPrevious();
    await app.diary.viewerPrevious();
    app.diary.expectViewer('Monday, January 1');

    await app.diary.closeViewer();
    app.diary.expectMemory(jan(1), title: 'Monday 1');
    await app.diary.showCalendar();
    app.diary.expectSelected(jan(1));
    app.expectNoPluginChannel();
  });

  testWidgets('the viewer deletes the clip it shows for good, says so and '
      'moves on (D5, CL-10, Q-D9)', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: _seed,
    );
    await app.shell.tapTab(AppRoute.diary);
    await app.diary.expand();
    app.diary.expectViewer('Thursday, January 4');

    await app.diary.deleteInViewer();
    await app.harness.settleUntil(
      () => app.diary.viewerTitle == 'Tuesday, January 2',
      reason: 'the last clip gone, the viewer shows the one before',
    );

    app.diary
      ..expectSnackbar('Video deleted')
      ..expectViewerSubtitle('2 of 2');
    final String file = app.harness.paths.absoluteFromVideos(
      clipOf(jan(4)).relPath,
    );
    expect(await tester.runAsync(() => File(file).exists()), isFalse);

    await app.diary.closeViewer();
    app.diary
      ..expectSelected(jan(2))
      ..expectCalendar(month: 'January 2024', count: '2 of 5 days');
  });

  testWidgets("deleting the diary's only clip closes the viewer once D5 "
      'has gone; the Diary says "Video deleted" with the day', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: (AppPaths paths) => seedClip(paths, _default, jan(4)),
    );
    await app.shell.tapTab(AppRoute.diary);
    await app.diary.expand();

    await app.diary.deleteInViewer();
    await app.harness.settleUntil(
      () => app.shell.location == AppRoute.diary.path,
      reason: 'the viewer closes with no clip left',
    );

    app.diary
      ..expectSnackbar('Video deleted')
      ..expectSnackbar('Thursday, January 4');
  });

  testWidgets('the viewer shares the stored file, and rewrites the subtitle '
      'through V4', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: (AppPaths paths) async {
        await _seed(paths);
        await seedClipMeta(paths, <String, ClipMeta>{
          clipOf(jan(4)).relPath: const ClipMeta(
            durationMs: 1500,
            hasSubtitleStream: true,
            subtitleText: 'Walk around Asakusa',
          ),
        });
      },
      configureGateways: (FakeGateways gateways) =>
          gateways.ffmpeg.onExecute = (List<String> arguments) async {
            final File output = File(arguments[arguments.length - 2]);
            await output.parent.create(recursive: true);
            await output.writeAsBytes(<int>[4, 2]);
          },
    );
    await app.shell.tapTab(AppRoute.diary);
    await app.diary.expand();
    app.diary.expectViewerCaption('“Walk around Asakusa”');

    await app.diary.shareInViewer();
    app.diary.expectShared(clipOf(jan(4)));

    await app.diary.editSubtitlesInViewer();
    app.subtitleSheet.expectText('Walk around Asakusa');
    await app.subtitleSheet.enterText('Rain later');
    await app.subtitleSheet.tapSave();
    await app.harness.settleUntil(
      () => app.diary.hasSnackbar('Subtitles saved!'),
      reason: 'the clip is rewritten',
    );

    app.diary.expectViewerCaption('“Rain later”');
    app.shell.expectShown(AppRoute.viewer);
  });

  testWidgets('a Memories card\'s long press deletes its clip for good', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: _seed,
    );
    await app.shell.tapTab(AppRoute.diary);
    await app.diary.showMemories();

    await app.diary.actOnMemory(jan(1), ClipAction.delete);
    await app.diary.confirmDelete();

    app.diary.expectSnackbar('Video deleted');
    expect(find.byKey(MemoryCard.keyOf(jan(1))), findsNothing);
    final String file = app.harness.paths.absoluteFromVideos(
      clipOf(jan(1)).relPath,
    );
    expect(await tester.runAsync(() => File(file).exists()), isFalse);
  });
}
