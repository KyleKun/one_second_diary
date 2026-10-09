// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/clips/presentation/subtitles/subtitle_sheet.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_edit_sheet.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/harness/seeds.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

/// `AppHarness.defaultNow`: Friday 5 January 2024, 10:00.
final LocalDay _today = LocalDay(2024, 1, 5);
const ProfileKey _default = ProfileKey.defaultProfile;
const ProfileKey _travel = ProfileKey('Travel');

void main() {
  testWidgets('an onboarded diary opens on the empty day: its date, the '
      'Default chip, Record waiting', (tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: (AppPaths paths) => seedClip(paths, _default, LocalDay(2024, 1, 4)),
    );

    app.shell.expectAt(AppRoute.today);
    expect(app.today.weekday, 'FRIDAY');
    expect(app.today.date, 'January 5');
    expect(app.today.profileName, Strings.defaultProfile);
    app.today.expectEmptyDay();
    app.expectNoPluginChannel();
  });

  testWidgets('with "Force native camera" (S3), Record opens the phone\'s '
      'camera, then the editor on its video for today (T1.1)', (tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(
        extra: const <String, Object>{'forceNativeCamera': true},
      ),
      isAndroid: true,
      configureGateways: (FakeGateways gateways) =>
          gateways.picker.cameraAnswers.add(const Picked('/tmp/REC.mp4')),
    );

    await app.today.tapRecord();
    await app.harness.settleUntil(
      () => app.shell.location.startsWith(AppRoute.editClip.path),
      reason: 'the editor opens on the recording',
    );

    app.shell.expectOpenedWith(
      EditClipArgs(
        source: const VideoSource(
          path: '/tmp/REC.mp4',
          ownership: ClipOwnership.cameraTemp,
        ),
        day: _today,
        profile: _default,
      ),
    );
    app.expectNoPluginChannel();
  });

  testWidgets('the saved snackbar lands just after Today shows again (200 '
      'ms, T5.7)', (tester) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    await app.today.tapRecord();
    final SavedClip saved = await app.today.saveAsTheEditor(day: _today);

    app.shell.router.pop(saved);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    app.savedSnackbar.expectGone();

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    app.savedSnackbar.expectShown(
      subtitle: Strings.todaySnackbarSavedBodyNoName,
    );
  });

  testWidgets('a second tap on Record while the camera opens opens nothing '
      'more (CL-20)', (tester) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());

    await app.today.doubleTapRecord();
    app.shell.expectOpenedWith(RecordArgs(day: _today, profile: _default));
    await app.shell.popWith(null);

    app.shell.expectAt(AppRoute.today);
  });

  testWidgets('leaving the camera without a clip leaves the day empty, with '
      'no snackbar', (tester) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());

    await app.today.tapRecord();
    await app.shell.pressBack();

    app.shell.expectAt(AppRoute.today);
    app.savedSnackbar.expectGone();
    app.today.expectEmptyDay();
  });

  testWidgets('Add photo picks a photo for today', (tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      isAndroid: true,
      configureGateways: (FakeGateways gateways) =>
          gateways.picker.galleryAnswers.add(const Picked('/g/IMG_1.jpg')),
    );

    await app.today.tapAddPhoto();
    await app.harness.settleUntil(
      () => app.shell.location.startsWith(AppRoute.editClip.path),
      reason: 'the editor opens on the photo',
    );

    expect(app.today.picker.galleryRequests.single.media, PickerMedia.photo);
  });

  testWidgets('the profile chip switches the diary: Travel is portrait, and '
      'the next recording goes there', (tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: prefsWithProfiles(const <ProfileSeed>[
        ProfileSeed('Travel', orientation: 'portrait'),
      ]),
    );
    expect(app.today.frameSize.width, closeTo(326, .01));

    await app.today.tapProfileChip();
    app.profileSheet.expectShown(title: Strings.profileSheetTitle);
    await app.profileSheet.tap(_travel);
    await app.harness.settleUntil(
      () => app.today.profileName == 'Travel',
      reason: 'the switch is stored and Today follows it',
    );

    app.profileSheet.expectClosed();
    expect(app.today.frameSize.height, 350);
    expect((await app.harness.storedPrefs).getInt('selectedProfileIndex'), 1);

    await app.today.tapRecord();
    app.shell.expectOpenedWith(RecordArgs(day: _today, profile: _travel));
    app.expectNoPluginChannel();
  });

  testWidgets('the camera closed, Today and the app-scoped profiles live '
      'on: the chip still switches the diary (CL-25)', (tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: prefsWithProfiles(const <ProfileSeed>[
        ProfileSeed('Travel', orientation: 'portrait'),
      ]),
    );
    await app.today.tapRecord();
    await app.shell.popWith(null);
    app.shell.expectAt(AppRoute.today);

    await app.today.tapProfileChip();
    await app.profileSheet.tap(_travel);
    await app.harness.settleUntil(
      () => app.today.profileName == 'Travel',
      reason: 'the switch is stored and Today follows it',
    );

    expect(app.today.frameSize.height, 350);
    await app.today.tapRecord();
    app.shell.expectOpenedWith(RecordArgs(day: _today, profile: _travel));
  });

  testWidgets('a tap on the chip while the switch sheet hands over to S5 '
      'opens nothing more: S5 alone (CL-20)', (tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: prefsWithProfiles(const <ProfileSeed>[
        ProfileSeed('Travel', orientation: 'portrait'),
      ]),
    );

    await app.today.tapProfileChip();
    await app.today.longPressProfileRowThenTapChip(_travel);

    app.today.expectEditProfileSheet();
    app.profileSheet.expectClosed();
  });

  group('midnight (CL-36)', () {
    // The launch armed the app's midnight ticker in the real zone, where it
    // reads the fake clock again at most a second of real time after the
    // clock passes midnight: the journey waits for what the user sees.

    testWidgets('while Today stays open, the clock passes midnight: the '
        'header moves to the new day, and the day waits for its clip', (
      tester,
    ) async {
      final AppRobot app = await AppRobot.launch(
        tester,
        prefs: legacyPrefs(),
        now: DateTime(2024, 1, 5, 23, 59, 59),
        seed: (AppPaths paths) => seedClip(paths, _default, _today),
      );
      expect(app.today.date, 'January 5');
      app.today.expectDayShows(
        ClipRef(profile: _default, relPath: '2024-01-05.mp4'),
      );

      app.harness.clock.advance(const Duration(seconds: 2));
      await app.harness.settleUntil(
        () => app.today.date == 'January 6',
        reason: 'the midnight ticker moves Today to the new day',
      );

      expect(app.today.weekday, 'SATURDAY');
      app.today.expectEmptyDay();
      app.expectNoPluginChannel();
    });

    testWidgets('a clip recorded just before midnight and saved just after '
        "is yesterday's: \"Video saved\" without today's line, and the new "
        'day still waits (RG-11)', (tester) async {
      final AppRobot app = await AppRobot.launch(
        tester,
        prefs: legacyPrefs(),
        now: DateTime(2024, 1, 5, 23, 59, 56),
      );

      await app.today.tapRecord();
      app.shell.expectOpenedWith(RecordArgs(day: _today, profile: _default));

      // A 2 s take stops at 23:59:59, so its clip is January 5's (the day the
      // recording stopped); editing takes the clock to 00:00:20.
      app.harness.clock.advance(const Duration(seconds: 24));
      await app.harness.settleUntil(
        () => app.today.dateUnderneath == 'January 6',
        reason: 'Today, under the camera, moves to the new day at midnight',
      );
      final SavedClip saved = await app.today.saveAsTheEditor(day: _today);
      expect(saved.ref.relPath, '2024-01-05.mp4');
      await app.shell.popWith(saved);
      await tester.pump(const Duration(milliseconds: 300));

      app.savedSnackbar.expectShown(subtitle: null);
      expect(app.today.date, 'January 6');
      app.today.expectEmptyDay();
      app.expectNoPluginChannel();
    });
  });

  group('the saved day (T3, T4)', () {
    final ClipRef todays = ClipRef(
      profile: _default,
      relPath: '2024-01-05.mp4',
    );
    ClipRef todays2(int ordinal) =>
        ClipRef(profile: _default, relPath: '2024-01-05-$ordinal.mp4');

    testWidgets('a tap on Add another while the Edit sheet closes does '
        'nothing: only the camera of Record again opens (CL-20)', (
      tester,
    ) async {
      final AppRobot app = await AppRobot.launch(
        tester,
        prefs: legacyPrefs(),
        seed: (AppPaths paths) => seedClip(paths, _default, _today),
      );

      await app.today.tapEdit();
      await app.today.pickEditThenTapAddAnother(TodayEditAction.recordAgain);

      app.shell.expectOpenedWith(
        RecordArgs(day: _today, profile: _default, mode: ReplaceClip(todays)),
      );
      await app.shell.popWith(null);

      app.shell.expectAt(AppRoute.today);
      app.addSource.expectClosed();
      app.today.expectDayShows(todays);
    });

    testWidgets('Edit, Replace from gallery: the gallery, then the editor '
        'replaces the clip in view', (tester) async {
      final AppRobot app = await AppRobot.launch(
        tester,
        prefs: legacyPrefs(),
        isAndroid: true,
        seed: (AppPaths paths) => seedClip(paths, _default, _today),
        configureGateways: (FakeGateways gateways) =>
            gateways.picker.galleryAnswers.add(const Picked('/g/VID_2.mp4')),
      );

      await app.today.tapEdit();
      await app.today.pickEdit(TodayEditAction.replaceFromGallery);
      await app.harness.settleUntil(
        () => app.shell.location.startsWith(AppRoute.editClip.path),
        reason: 'the editor opens on the pick',
      );

      expect(app.today.picker.galleryRequests.single.media, PickerMedia.video);
      app.shell.expectOpenedWith(
        EditClipArgs(
          source: const VideoSource(
            path: '/g/VID_2.mp4',
            ownership: ClipOwnership.userOriginal,
          ),
          day: _today,
          profile: _default,
          mode: ReplaceClip(todays),
        ),
      );
      app.expectNoPluginChannel();
    });

    testWidgets("Edit, Edit subtitles: the V4 sheet on the clip's subtitle", (
      tester,
    ) async {
      final AppRobot app = await AppRobot.launch(
        tester,
        prefs: legacyPrefs(),
        seed: (AppPaths paths) async {
          await seedClip(paths, _default, _today);
          await seedClipMeta(paths, <String, ClipMeta>{
            todays.relPath: const ClipMeta(
              durationMs: 1500,
              hasSubtitleStream: true,
              subtitleText: 'Walk around Asakusa',
            ),
          });
        },
      );

      await app.today.tapEdit();
      await app.today.pickEdit(TodayEditAction.editSubtitles);
      await app.harness.settleUntil(
        () => find.byKey(SubtitleSheet.bodyKey).evaluate().isNotEmpty,
        reason: 'the subtitle is read, then the sheet opens',
      );

      app.subtitleSheet.expectOpen();
      app.subtitleSheet.expectText('Walk around Asakusa');
      await app.subtitleSheet.pressBack();
      app.subtitleSheet.expectClosed();
      app.today.expectDayShows(todays);
    });

    testWidgets('several clips: Today opens on the latest; a swipe, then a '
        'tap on the first dot, go back to the first, and Edit acts on it', (
      tester,
    ) async {
      final AppRobot app = await AppRobot.launch(
        tester,
        prefs: legacyPrefs(),
        seed: (AppPaths paths) =>
            seedDayClips(paths, _default, _today, count: 3),
      );
      app.today.expectDayShows(todays2(3));
      expect(app.today.pagerDots, 3);

      await app.today.swipeToPrevious();
      await app.today.tapDot(0);
      app.today.expectDayShows(todays);

      await app.today.tapEdit();
      await app.today.pickEdit(TodayEditAction.recordAgain);

      app.shell.expectOpenedWith(
        RecordArgs(day: _today, profile: _default, mode: ReplaceClip(todays)),
      );
    });

    testWidgets('a tap plays the clip in view inline, through the tab\'s '
        'player, with sound', (tester) async {
      final AppRobot app = await AppRobot.launch(
        tester,
        prefs: legacyPrefs(),
        seed: (AppPaths paths) => seedClip(paths, _default, _today),
      );
      await app.harness.settleUntil(
        () => app.harness.gateways.players.created.isNotEmpty,
        reason: "the clip's player opens in the background",
      );

      await app.today.tapClip();

      // The one playing: the Diary, built hidden, has its own muted player.
      final FakePlayerHandle player = app.harness.gateways.players.created
          .lastWhere((FakePlayerHandle handle) => handle.value.value.playing);
      expect(player.path, app.harness.paths.absoluteFromVideos(todays.relPath));
      expect(player.mixWithOthers, isFalse);
      expect(player.value.value.playing, isTrue);
      app.expectNoPluginChannel();
    });

    testWidgets('a long press opens the clip in view in the viewer (D4); the '
        'clip the viewer shows last comes into view', (tester) async {
      final AppRobot app = await AppRobot.launch(
        tester,
        prefs: legacyPrefs(),
        seed: (AppPaths paths) =>
            seedDayClips(paths, _default, _today, count: 2),
      );

      await app.today.longPressClip();
      app.shell.expectOpenedWith(ViewerArgs(clip: todays2(2)));

      await app.shell.popWith(todays);

      app.shell.expectAt(AppRoute.today);
      await app.harness.settleUntil(
        () => app.today.clipInView == todays,
        reason: 'the pager moves to the clip the viewer showed last',
      );
    });

    testWidgets("the viewer plays Today's loaded player at once; when it "
        'deletes the day\'s only clip and closes, Today says "Video '
        'deleted" with the date', (tester) async {
      final AppRobot app = await AppRobot.launch(
        tester,
        prefs: legacyPrefs(),
        seed: (AppPaths paths) => seedClip(paths, _default, _today),
      );
      // Today's player has sound; the Diary, built hidden, has its own
      // muted one, which mixes with other apps' audio.
      Iterable<FakePlayerHandle> todays() => app
          .harness
          .gateways
          .players
          .created
          .where((FakePlayerHandle handle) => !handle.mixWithOthers);
      await app.harness.settleUntil(
        () => todays().any(
          (FakePlayerHandle handle) => handle.value.value.initialized,
        ),
        reason: "Today's player of the clip opens in the background",
      );
      final FakePlayerHandle player = todays().last;

      await app.today.longPressClip();
      final ViewerArgs viewer = app.shell.router.state.extra! as ViewerArgs;
      expect(viewer.warmPlayer?.handle, same(player));

      await app.diary.deleteInViewer();
      await app.harness.settleUntil(
        () => app.shell.location == AppRoute.today.path,
        reason: 'the viewer closes with no clip left',
      );
      app.diary
        ..expectSnackbar(Strings.videoDeleted)
        ..expectSnackbar('Friday, January 5');
    });
  });
}
