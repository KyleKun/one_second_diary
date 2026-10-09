// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/policy/srt_codec.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/harness/seeds.dart';
import '../../shared/robots/app_robot.dart';
import '../../shared/robots/shell_robot.dart';
import '../../support/support.dart';

void main() {
  final LocalDay january5 = LocalDay(2024, 1, 5);
  late AppPaths paths;
  late String recording;

  /// Every SRT the engine wrote for ffmpeg, read while its job ran.
  late List<String> subtitleFiles;

  const List<int> rendered = <int>[4, 2];

  Future<AppRobot> launch(
    WidgetTester tester, {
    void Function(FakeGateways gateways)? configure,
  }) async {
    subtitleFiles = <String>[];
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(),
      seed: (AppPaths at) async {
        paths = at;
        final File video = File('${at.temporaryDir}/REC_1.mp4');
        await video.create(recursive: true);
        await video.writeAsBytes(fakeVideoBytes);
        recording = video.path;
      },
      configureGateways: (FakeGateways gateways) {
        gateways.players.duration = const Duration(seconds: 4);
        gateways.ffmpeg.onExecute = (List<String> arguments) async {
          for (final String argument in arguments) {
            if (argument.endsWith('subtitles.srt')) {
              subtitleFiles.add(await File(argument).readAsString());
            }
          }
          final File output = File(arguments[arguments.length - 2]);
          await output.parent.create(recursive: true);
          await output.writeAsBytes(rendered);
        };
        configure?.call(gateways);
      },
    );
    return app;
  }

  EditClipArgs editRecording() => EditClipArgs(
    source: VideoSource(path: recording, ownership: ClipOwnership.cameraTemp),
    day: january5,
    profile: ProfileKey.defaultProfile,
  );

  /// The ffmpeg runs that made a clip (not the probes of it).
  List<List<String>> saves(AppRobot app) => <List<String>>[
    for (final List<String> arguments in app.harness.gateways.ffmpeg.executed)
      if (arguments.last == '-y') arguments,
  ];

  testWidgets('a recording trimmed, stamped, tagged and subtitled is saved '
      'once, however hurried the thumb, and the editor pops with it', (
    tester,
  ) async {
    final AppRobot app = await launch(tester);
    final RouteResult<SavedClip> result = await app.shell
        .openForResult<SavedClip>(editRecording());
    await app.clipEditor.waitForTheSource();

    await app.clipEditor.tapCut(1);
    await app.clipEditor.openDateStamp();
    await app.clipEditor.pickDateFormat('January 5, 2024');
    await app.clipEditor.pickStampColor(Strings.colorCoral);
    await app.clipEditor.tapDateStampDone();
    await app.clipEditor.openLocationTab();
    await app.clipEditor.tapShowMyLocation();
    await app.clipEditor.openSubtitlesTab();
    // A first word over 45 characters.
    const String subtitle =
        'Supercalifragilisticexpialidociously-extraordinary morning';
    await app.subtitleSheet.enterText(subtitle);
    await app.subtitleSheet.tapSave();

    await app.clipEditor.doubleTapSave();
    app.clipEditor.expectSaving();
    await app.clipEditor.waitUntilSaved();

    final SavedClip saved = result.value!;
    expect(
      saved.ref,
      ClipRef(profile: ProfileKey.defaultProfile, relPath: '2024-01-05.mp4'),
    );
    expect(saved.replaced, isFalse);
    expect(File('${paths.videos}2024-01-05.mp4').readAsBytesSync(), rendered);
    // The camera's temp goes once the clip is in the diary.
    expect(File(recording).existsSync(), isFalse);

    // One render for two taps.
    final List<String> save = saves(app).single;
    expect(save, containsAllInOrder(<String>['-ss', '0ms', '-to', '1500ms']));
    expect(
      save,
      contains(
        allOf(startsWith('location='), contains('+35.71'), endsWith('Japan')),
      ),
    );
    // No empty line inside the cue: the whole subtitle reaches the clip.
    expect(
      SrtCodec.decode(subtitleFiles.single),
      <String>[
        'Supercalifragilisticexpialidociously-extraordinary',
        'morning',
      ].join('\n'),
    );
    expect(app.harness.gateways.calls, contains('wakelock.enable'));
    expect(app.harness.gateways.wakelock.enabled, isFalse);
    app.expectNoPluginChannel();
  });

  testWidgets('a photo is saved as a clip of the day it was added to, held '
      'for its length', (tester) async {
    late String photo;
    final AppRobot app = await launch(tester, configure: (_) {});
    await tester.runAsync(() async {
      final File still = File('${paths.temporaryDir}/IMG_1.jpg');
      await still.writeAsBytes(onePixelPng);
      photo = still.path;
    });
    final RouteResult<SavedClip> result = await app.shell
        .openForResult<SavedClip>(
          EditClipArgs(
            source: PhotoSource(
              path: photo,
              ownership: ClipOwnership.pickerCopy,
            ),
            day: LocalDay(2024, 1, 3),
            profile: ProfileKey.defaultProfile,
          ),
        );
    await app.clipEditor.waitForTheSource();

    await app.clipEditor.tapCut(2);
    await app.clipEditor.tapSave();
    await app.clipEditor.waitUntilSaved();

    expect(result.value!.ref.relPath, '2024-01-03.mp4');
    expect(saves(app).single, containsAllInOrder(<String>['-t', '2.0']));
    expect(File('${paths.videos}2024-01-03.mp4').readAsBytesSync(), rendered);
    // A picker's copy goes too.
    expect(File(photo).existsSync(), isFalse);
  });

  group('a replace', () {
    final ClipRef january5Clip = ClipRef(
      profile: ProfileKey.defaultProfile,
      relPath: '2024-01-05.mp4',
    );

    Future<AppRobot> launchWithClip(
      WidgetTester tester, {
      void Function(FakeGateways gateways)? configure,
    }) async {
      final AppRobot app = await launch(tester, configure: configure);
      await tester.runAsync(
        () => seedClip(
          paths,
          ProfileKey.defaultProfile,
          january5,
          bytes: const <int>[7, 7, 7],
        ),
      );
      return app;
    }

    EditClipArgs replacing() => EditClipArgs(
      source: VideoSource(path: recording, ownership: ClipOwnership.cameraTemp),
      day: january5,
      profile: ProfileKey.defaultProfile,
      mode: ReplaceClip(january5Clip),
    );

    testWidgets('writes the new version under the same name', (tester) async {
      final AppRobot app = await launchWithClip(tester);
      final RouteResult<SavedClip> result = await app.shell
          .openForResult<SavedClip>(replacing());
      await app.clipEditor.waitForTheSource();

      await app.clipEditor.tapSave();
      await app.clipEditor.waitUntilSaved();

      expect(result.value!.ref, january5Clip);
      expect(result.value!.replaced, isTrue);
      expect(File('${paths.videos}2024-01-05.mp4').readAsBytesSync(), rendered);
    });

    testWidgets('that fails leaves the old clip as it was (D B2)', (
      tester,
    ) async {
      final AppRobot app = await launchWithClip(
        tester,
        configure: (FakeGateways gateways) =>
            gateways.ffmpeg.executeResults.add(FakeFfmpegGateway.failure()),
      );
      await app.shell.openForResult<SavedClip>(replacing());
      await app.clipEditor.waitForTheSource();

      await app.clipEditor.tapSave();
      await app.clipEditor.waitForTheFailure();

      app.clipEditor.expectSaveFailed();
      expect(File('${paths.videos}2024-01-05.mp4').readAsBytesSync(), <int>[
        7,
        7,
        7,
      ]);
    });
  });

  /// Every file left in the engine's scratch folder.
  List<String> scratchFiles() => <String>[
    for (final FileSystemEntity entity in Directory(
      paths.scratchDir,
    ).listSync(recursive: true))
      if (entity is File) entity.path,
  ];

  testWidgets('Cancel while saving stops ffmpeg and leaves no file; the '
      'clip saves on the next try', (tester) async {
    final AppRobot app = await launch(
      tester,
      configure: (FakeGateways gateways) =>
          gateways.ffmpeg.holdExecutions = true,
    );
    final RouteResult<SavedClip> result = await app.shell
        .openForResult<SavedClip>(editRecording());
    await app.clipEditor.waitForTheSource();

    await app.clipEditor.tapSave();
    await app.harness.settleUntil(
      () => app.harness.gateways.ffmpeg.heldSessions.isNotEmpty,
      reason: 'the render to start',
    );
    app.clipEditor.expectSaving();
    final int session = app.harness.gateways.ffmpeg.heldSessions.single;

    await app.clipEditor.tapCancelSave();

    expect(app.harness.gateways.ffmpeg.cancelledSessions, <int>[session]);
    expect(result.popped, isFalse);
    expect(Directory(paths.videos).listSync().whereType<File>(), isEmpty);
    expect(scratchFiles(), isEmpty);
    expect(File(recording).existsSync(), isTrue);
    expect(app.harness.gateways.wakelock.enabled, isFalse);
    expect(app.clipEditor.canSave, isTrue);

    app.harness.gateways.ffmpeg.holdExecutions = false;
    await app.clipEditor.tapSave();
    await app.clipEditor.waitUntilSaved();
    expect(result.value!.ref.relPath, '2024-01-05.mp4');
  });

  testWidgets('a failure says nothing changed; Report error mails the logs, '
      'and the clip can be saved again', (tester) async {
    final AppRobot app = await launch(
      tester,
      configure: (FakeGateways gateways) =>
          gateways.ffmpeg.executeResults.add(FakeFfmpegGateway.failure()),
    );
    final RouteResult<SavedClip> result = await app.shell
        .openForResult<SavedClip>(editRecording());
    await app.clipEditor.waitForTheSource();

    await app.clipEditor.tapSave();
    await app.clipEditor.waitForTheFailure();
    app.clipEditor.expectSaveFailed();
    await app.clipEditor.tapReportError();

    final EmailDraft report = app.harness.gateways.email.sent.single;
    expect(report.subject, endsWith('App Error Report'));
    expect(report.body, Strings.errorMailBody);
    expect(report.attachmentPaths, <String>[paths.logsZipPath]);
    expect(Directory(paths.videos).listSync().whereType<File>(), isEmpty);
    expect(File(recording).existsSync(), isTrue);
    app.clipEditor.expectShown();

    await app.clipEditor.tapSave();
    await app.clipEditor.waitUntilSaved();
    expect(result.value!.ref.relPath, '2024-01-05.mp4');
  });

  testWidgets('Close after a failure goes back to the clip as it was', (
    tester,
  ) async {
    final AppRobot app = await launch(
      tester,
      configure: (FakeGateways gateways) =>
          gateways.ffmpeg.executeResults.add(FakeFfmpegGateway.failure()),
    );
    await app.shell.openForResult<SavedClip>(editRecording());
    await app.clipEditor.waitForTheSource();
    await app.clipEditor.tapCut(2);

    await app.clipEditor.tapSave();
    await app.clipEditor.waitForTheFailure();
    await app.clipEditor.tapCloseFailure();

    app.clipEditor
      ..expectShown()
      ..expectSelectedCut(2);
    expect(app.harness.gateways.email.sent, isEmpty);
  });

  group('leaving', () {
    testWidgets('with changes asks; Keep editing stays, Discard leaves '
        'without a clip and gives the recording up', (tester) async {
      final AppRobot app = await launch(tester);
      final RouteResult<SavedClip> result = await app.shell
          .openForResult<SavedClip>(editRecording());
      await app.clipEditor.waitForTheSource();
      await app.clipEditor.tapCut(1);

      await app.clipEditor.pressBack();
      app.clipEditor.expectDiscardDialog(recordAgain: true);
      await app.clipEditor.tapKeepEditing();
      app.clipEditor
        ..expectShown()
        ..expectSelectedCut(1);

      await app.clipEditor.pressBack();
      await app.clipEditor.tapDiscard();

      expect(result.value, isNull);
      expect(File(recording).existsSync(), isFalse);
      expect(Directory(paths.videos).listSync().whereType<File>(), isEmpty);
      expect(app.harness.gateways.ffmpeg.executed, isEmpty);
    });

    testWidgets('"Record again" opens the camera above the editor; the new '
        'clip reaches whoever opened the first one', (tester) async {
      final AppRobot app = await launch(tester);
      final RouteResult<SavedClip> result = await app.shell
          .openForResult<SavedClip>(editRecording());
      await app.clipEditor.waitForTheSource();
      await app.clipEditor.tapCut(1);
      await app.clipEditor.pressBack();

      await app.clipEditor.tapRecordAgain();
      app.shell.expectAt(AppRoute.record);

      await app.recording.pressShutter();
      await app.recording.wait(const Duration(seconds: 3));
      final String second = app.recording.camera.current!.recordings.single;
      app.shell.expectNoPageOf(AppRoute.record);
      await app.clipEditor.waitForTheSource();
      await app.clipEditor.tapSave();
      await app.harness.settleUntil(
        () => result.popped,
        reason: 'the new clip to save and both editors to leave',
      );

      expect(result.value!.ref.relPath, '2024-01-05.mp4');
      app.shell.expectAt(AppRoute.today);
      // The first recording was given up, the second filed.
      expect(File(recording).existsSync(), isFalse);
      expect(File(second).existsSync(), isFalse);
    });
  });
}
