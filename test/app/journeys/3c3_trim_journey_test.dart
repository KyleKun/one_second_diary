// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/osd_fade_through_page.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/animated_stamp_text.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/date_stamp_card.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/edit_clip_preview.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/edit_clip_profile_card.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/edit_clip_stamps.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/edit_clip_tabs.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/filmstrip_trimmer.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/general_tab.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/trim_readout.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/video_source_preview.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/harness/seeds.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

void main() {
  late String recording;
  late String photo;

  Future<AppRobot> launch(
    WidgetTester tester, {
    Duration recordingLength = const Duration(seconds: 8),
    Map<String, Object> extra = const <String, Object>{},
  }) => AppRobot.launch(
    tester,
    prefs: legacyPrefs(extra: extra),
    seed: (AppPaths paths) async {
      final File video = File('${paths.temporaryDir}/REC_1.mp4');
      await video.create(recursive: true);
      await video.writeAsBytes(fakeVideoBytes);
      recording = video.path;
      final File still = File('${paths.temporaryDir}/IMG_1.jpg');
      await still.writeAsBytes(onePixelPng);
      photo = still.path;
    },
    configureGateways: (FakeGateways gateways) =>
        gateways.players.duration = recordingLength,
  );

  EditClipArgs editRecording() => EditClipArgs(
    source: VideoSource(path: recording, ownership: ClipOwnership.cameraTemp),
    day: LocalDay(2024, 1, 5),
    profile: ProfileKey.defaultProfile,
  );

  testWidgets('trimming a recording: the quick cuts keep the start, the '
      'window moves, the readout shows what will be saved', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await launch(tester);

    await app.shell.open(editRecording());
    await app.clipEditor.waitForTheSource();

    app.clipEditor
      ..expectTitle(Strings.saveVideo)
      ..expectReadout('08.00')
      ..expectQuickCuts(
        <double>[1, 1.5, 2, 3, 5],
        enabled: <double>[1, 1.5, 2, 3, 5],
      )
      ..expectSelectedCut(null);

    await app.clipEditor.tapCut(1);
    app.clipEditor
      ..expectSelectedCut(1)
      ..expectReadout('01.50');

    await app.clipEditor.dragWindow(
      fromSecond: .5,
      seconds: 3,
      sourceSeconds: 8,
    );
    await app.clipEditor.tapCut(2);

    app.clipEditor
      ..expectSelectedCut(2)
      ..expectReadout('02.50');
    expect(
      app.clipEditor.player.value.value.position,
      const Duration(seconds: 3),
    );
    app.expectNoPluginChannel();
  });

  testWidgets('a short recording offers only the cuts it can give', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await launch(
      tester,
      recordingLength: const Duration(milliseconds: 2400),
    );

    await app.shell.open(editRecording());
    await app.clipEditor.waitForTheSource();

    app.clipEditor
      ..expectReadout('02.40')
      ..expectQuickCuts(
        <double>[1, 1.5, 2, 3, 5],
        enabled: <double>[1, 1.5, 2],
      );
  });

  // No +500 ms pad and no "Strict clip length" switch: the readout is exactly the window.
  testWidgets('the readout shows the window as it is: a 1.5 s cut reads '
      '01.50', (WidgetTester tester) async {
    final AppRobot app = await launch(tester);

    await app.shell.open(editRecording());
    await app.clipEditor.waitForTheSource();
    await app.clipEditor.tapCut(1.5);

    app.clipEditor.expectReadout('01.50');
  });

  testWidgets('the preview pauses on a tap and plays on the next', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await launch(tester);
    await app.shell.open(editRecording());
    await app.clipEditor.waitForTheSource();

    await app.clipEditor.tapPreview();
    app.clipEditor.expectPaused(paused: true);

    await app.clipEditor.tapPreview();
    app.clipEditor.expectPaused(paused: false);
  });

  testWidgets('a photo is held for the length picked, and the next photo '
      'starts there', (WidgetTester tester) async {
    final AppRobot app = await launch(tester);
    EditClipArgs editPhoto() => EditClipArgs(
      source: PhotoSource(path: photo, ownership: ClipOwnership.pickerCopy),
      day: LocalDay(2024, 1, 3),
      profile: ProfileKey.defaultProfile,
    );

    await app.shell.open(editPhoto());
    await app.clipEditor.waitForTheSource();
    app.clipEditor
      ..expectTitle(Strings.savePhoto)
      ..expectReadout('01.00')
      ..expectSelectedCut(1);

    await app.clipEditor.tapCut(3);
    app.clipEditor.expectReadout('03.00');
    await app.clipEditor.discard();

    await app.shell.open(editPhoto());
    await app.clipEditor.waitForTheSource();
    app.clipEditor
      ..expectReadout('03.00')
      ..expectSelectedCut(3);
    app.expectNoPluginChannel();
  });

  // The camera handed over, so back would land on the tab and drop the take
  // unasked.
  testWidgets('back from an untouched recording asks first; Discard deletes '
      'the take and returns to the tab', (WidgetTester tester) async {
    final AppRobot app = await launch(tester);
    await app.shell.open(editRecording());
    await app.clipEditor.waitForTheSource();

    await app.clipEditor.pressBack();
    app.clipEditor
      ..expectShown()
      ..expectDiscardDialog(recordAgain: true);
    await app.clipEditor.tapDiscard();

    app.shell.expectAt(AppRoute.today);
    expect(File(recording).existsSync(), isFalse);
  });

  testWidgets('a recording fades through into the editor; a photo is '
      'pushed', (WidgetTester tester) async {
    final AppRobot app = await launch(tester);
    bool fadesThrough() =>
        ModalRoute.of(app.shell.pageElement(AppRoute.editClip))!.settings
            is OsdFadeThroughPage<Object?>;

    await app.shell.open(editRecording());
    expect(fadesThrough(), isTrue);
    await app.clipEditor.discard();

    await app.shell.open(
      EditClipArgs(
        source: PhotoSource(path: photo, ownership: ClipOwnership.pickerCopy),
        day: LocalDay(2024, 1, 5),
        profile: ProfileKey.defaultProfile,
      ),
    );
    expect(fadesThrough(), isFalse);
  });

  testWidgets('a recording Android kept says so once', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await launch(tester);

    await app.shell.open(
      EditClipArgs(
        source: VideoSource(
          path: recording,
          ownership: ClipOwnership.cameraTemp,
        ),
        day: LocalDay(2024, 1, 4),
        profile: ProfileKey.defaultProfile,
        recovered: true,
      ),
    );
    await app.clipEditor.waitForTheSource();

    expect(find.text(Strings.recordingRecovered), findsOneWidget);
  });

  testWidgets('dragging the window rebuilds the trim block only', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await launch(tester);
    await app.shell.open(editRecording());
    await app.clipEditor.waitForTheSource();
    await app.clipEditor.tapCut(1);

    final Set<Type> rebuilt = <Type>{};
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    await app.clipEditor.dragWindowWatching(
      fromSecond: .5,
      seconds: 4,
      sourceSeconds: 8,
      onMoving: () =>
          debugOnRebuildDirtyWidget = (Element element, bool builtOnce) =>
              rebuilt.add(element.widget.runtimeType),
      onLifting: () => debugOnRebuildDirtyWidget = null,
    );

    expect(rebuilt, contains(FilmstripTrimmer));
    expect(rebuilt, contains(TrimReadout));
    expect(
      rebuilt.intersection(<Type>{
        EditClipPreview,
        VideoSourcePreview,
        EditClipStamps,
        AnimatedStampText,
        EditClipTabs,
        GeneralTab,
        EditClipProfileCard,
        DateStampCard,
        OsdAppBar,
        Scaffold,
      }),
      isEmpty,
    );
  });
}
