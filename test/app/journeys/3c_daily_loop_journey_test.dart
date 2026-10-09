// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_clip_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_edit_sheet.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

/// `AppHarness.defaultNow`: Friday 5 January 2024, 10:00.
final LocalDay _today = LocalDay(2024, 1, 5);
const ProfileKey _default = ProfileKey.defaultProfile;
final ClipRef _todays = ClipRef(profile: _default, relPath: '2024-01-05.mp4');

/// What ffmpeg writes for a saved clip.
const List<int> _rendered = <int>[4, 2];

/// The clip that was there before a replace.
const List<int> _old = <int>[7, 7, 7];

void main() {
  late AppPaths paths;

  /// A video in the phone's gallery, picked by the fake picker.
  late String galleryVideo;

  /// The app over [seed], with the editor's player 4 s long and ffmpeg
  /// writing [_rendered] wherever it is told to.
  Future<AppRobot> launch(
    WidgetTester tester, {
    Future<void> Function(AppPaths paths)? seed,
    void Function(FakeGateways gateways)? configure,
  }) => AppRobot.launch(
    tester,
    prefs: legacyPrefs(),
    isAndroid: true,
    seed: (AppPaths at) async {
      paths = at;
      final File video = File('${at.temporaryDir}/gallery/VID_1.mp4');
      await video.create(recursive: true);
      await video.writeAsBytes(fakeVideoBytes);
      galleryVideo = video.path;
      await seed?.call(at);
    },
    configureGateways: (FakeGateways gateways) {
      gateways.players.duration = const Duration(seconds: 4);
      gateways.ffmpeg.onExecute = (List<String> arguments) async {
        final File output = File(arguments[arguments.length - 2]);
        await output.parent.create(recursive: true);
        await output.writeAsBytes(_rendered);
      };
      configure?.call(gateways);
    },
  );

  List<int>? bytesOf(String relPath) {
    final File file = File('${paths.videos}$relPath');
    return file.existsSync() ? file.readAsBytesSync() : null;
  }

  testWidgets('Today: Record, the camera (the screen kept awake), then Save '
      'in the editor; Today shows the clip, "Video saved" and "See you '
      'tomorrow" above Edit and Add another', (WidgetTester tester) async {
    final AppRobot app = await launch(tester);

    await app.today.tapRecord();
    app.recording.expectLive();
    expect(
      app.harness.gateways.wakelock.enabled,
      isTrue,
      reason: 'the camera keeps the screen awake (recording.md R1 §0.1)',
    );
    await app.recording.pressShutter();
    await app.recording.wait(const Duration(seconds: 3));
    await app.clipEditor.waitForTheSource();
    await app.clipEditor.tapSave();
    await app.clipEditor.waitUntilSaved();

    app.shell.expectAt(AppRoute.today);
    app.savedSnackbar.expectShown(
      subtitle: Strings.todaySnackbarSavedBodyNoName,
    );
    expect(
      app.savedSnackbar.bounds.bottom,
      lessThanOrEqualTo(app.today.clipActions.top),
      reason: 'it covers neither Edit nor Add another (T5, Q2)',
    );
    app.today.expectDayShows(_todays);
    expect(bytesOf(_todays.relPath), _rendered);
    app.recording.expectReleased();
    expect(app.harness.gateways.wakelock.enabled, isFalse);
    app.expectNoPluginChannel();
  });

  testWidgets('Today: Add video picks from the gallery, for today; saved in '
      'the editor, it shows with "Video saved"', (WidgetTester tester) async {
    final AppRobot app = await launch(
      tester,
      configure: (FakeGateways gateways) =>
          gateways.picker.galleryAnswers.add(Picked(galleryVideo)),
    );

    await app.today.tapAddVideo();
    await app.clipEditor.waitForTheSource();
    expect(app.today.picker.galleryRequests.single.media, PickerMedia.video);
    await app.clipEditor.tapSave();
    await app.clipEditor.waitUntilSaved();

    app.shell.expectAt(AppRoute.today);
    app.savedSnackbar.expectShown(
      subtitle: Strings.todaySnackbarSavedBodyNoName,
    );
    app.today.expectDayShows(_todays);
    expect(bytesOf(_todays.relPath), _rendered);
    app.expectNoPluginChannel();
  });

  testWidgets('Today: Add another records the day\'s second clip (D1); saved '
      'in the editor, it comes into view: "That\'s 2 today", two dots', (
    WidgetTester tester,
  ) async {
    final ClipRef second = ClipRef(
      profile: _default,
      relPath: '2024-01-05-2.mp4',
    );
    final AppRobot app = await launch(
      tester,
      seed: (AppPaths at) => seedClip(at, _default, _today, bytes: _old),
    );

    await app.today.tapAddAnother();
    app.addSource.expectShown(title: Strings.todayAddAnotherTitle);
    await app.addSource.tap(AddClipSource.record);
    await app.harness.settleUntil(
      () => app.shell.location.startsWith(AppRoute.record.path),
      reason: 'the camera opens once the sheet has closed',
    );
    await app.recording.pressShutter();
    await app.recording.wait(const Duration(seconds: 3));
    await app.clipEditor.waitForTheSource();
    await app.clipEditor.tapSave();
    await app.clipEditor.waitUntilSaved();

    app.savedSnackbar.expectShown(
      subtitle: Strings.todaySnackbarSavedBodyCount(count: 2),
    );
    app.today.expectDayShows(second);
    expect(app.today.pagerDots, 2);
    expect(bytesOf(second.relPath), _rendered);
    expect(bytesOf(_todays.relPath), _old);
    app.expectNoPluginChannel();
  });

  testWidgets('the Diary: a missed day takes a video from the gallery; '
      'saved in the editor, the Diary shows that day with its clip and '
      '"Video saved" (D2, CL-37)', (WidgetTester tester) async {
    final LocalDay january3 = LocalDay(2024, 1, 3);
    final AppRobot app = await launch(
      tester,
      seed: (AppPaths at) async {
        await seedClip(at, _default, LocalDay(2024, 1, 2));
        await seedClip(at, _default, LocalDay(2024, 1, 4));
      },
      configure: (FakeGateways gateways) =>
          gateways.picker.galleryAnswers.add(Picked(galleryVideo)),
    );
    await app.shell.tapTab(AppRoute.diary);
    await app.diary.tapDay(january3);
    app.diary.expectPanelSays('No video on Wednesday 3');

    await app.diary.tapAddVideo();
    await app.clipEditor.waitForTheSource();
    await app.clipEditor.tapSave();
    await app.clipEditor.waitUntilSaved();

    app.shell.expectAt(AppRoute.diary);
    app.diary
      ..expectSnackbar(Strings.videoSavedTitle)
      ..expectSelected(january3)
      ..expectCaption('Wednesday 3');
    expect(bytesOf('2024-01-03.mp4'), _rendered);
    // The user's own gallery video stays where it was.
    expect(File(galleryVideo).existsSync(), isTrue);
    app.expectNoPluginChannel();
  });

  group("Today's Edit sheet: a replace", () {
    Future<void> seedToday(AppPaths at) =>
        seedClip(at, _default, _today, bytes: _old);

    testWidgets('Replace from gallery, saved in the editor, replaces the '
        'clip in view', (WidgetTester tester) async {
      final AppRobot app = await launch(
        tester,
        seed: seedToday,
        configure: (FakeGateways gateways) =>
            gateways.picker.galleryAnswers.add(Picked(galleryVideo)),
      );
      app.today.expectDayShows(_todays);

      await app.today.tapEdit();
      await app.today.pickEdit(TodayEditAction.replaceFromGallery);
      await app.clipEditor.waitForTheSource();
      await app.clipEditor.tapSave();
      await app.clipEditor.waitUntilSaved();

      app.savedSnackbar.expectShown(
        subtitle: Strings.todaySnackbarSavedBodyNoName,
      );
      app.today.expectDayShows(_todays);
      expect(bytesOf(_todays.relPath), _rendered);
      app.expectNoPluginChannel();
    });

    testWidgets('Record again: the camera, then the editor replaces the clip '
        'in view', (WidgetTester tester) async {
      final AppRobot app = await launch(tester, seed: seedToday);

      await app.today.tapEdit();
      await app.today.pickEdit(TodayEditAction.recordAgain);
      app.recording.expectLive();
      await app.recording.pressShutter();
      await app.recording.wait(const Duration(seconds: 3));
      await app.clipEditor.waitForTheSource();
      await app.clipEditor.tapSave();
      await app.clipEditor.waitUntilSaved();

      app.shell.expectAt(AppRoute.today);
      app.savedSnackbar.expectShown(
        subtitle: Strings.todaySnackbarSavedBodyNoName,
      );
      app.today.expectDayShows(_todays);
      expect(bytesOf(_todays.relPath), _rendered);
      app.expectNoPluginChannel();
    });
  });
}
