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
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_clip_flow.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_clip_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/harness/settle.dart';
import '../../shared/robots/app_robot.dart';
import '../../shared/robots/shell_robot.dart';
import '../../support/support.dart';

/// The harness's today.
final LocalDay _today = LocalDay(2024, 1, 5);
const ProfileKey _profile = ProfileKey.defaultProfile;
final ClipRef _clip = ClipRef(
  profile: _profile,
  relPath: '${_today.fileStem}.mp4',
);
final ReplaceClip _replace = ReplaceClip(_clip);

EditClipArgs _editorOn(String path) => EditClipArgs(
  source: VideoSource(path: path, ownership: ClipOwnership.cameraTemp),
  day: _today,
  profile: _profile,
  mode: _replace,
);

/// Today's Edit sheet taps Record again.
Future<RouteResult<SavedClip>> _recordAgain(AppRobot app) async {
  final RouteResult<SavedClip> result = RouteResult<SavedClip>(
    AddClipFlow.start(
      app.shell.pageElement(AppRoute.today),
      source: AddClipSource.record,
      day: _today,
      profile: _profile,
      mode: _replace,
    ),
  );
  await settle(app.tester);
  return result;
}

/// The app with today's clip, the editor's player 4 s long, ffmpeg writing
/// every render.
Future<AppRobot> _launch(
  WidgetTester tester, {
  Map<String, Object> extraPrefs = const <String, Object>{},
  Future<void> Function(AppPaths paths)? seed,
  void Function(FakeGateways gateways)? configure,
}) => AppRobot.launch(
  tester,
  prefs: legacyPrefs(extra: extraPrefs),
  seed: (AppPaths paths) async {
    await seedClip(paths, _profile, _today);
    await seed?.call(paths);
  },
  configureGateways: (FakeGateways gateways) {
    gateways.players.duration = const Duration(seconds: 4);
    gateways.ffmpeg.onExecute = (List<String> arguments) async {
      final File output = File(arguments[arguments.length - 2]);
      await output.parent.create(recursive: true);
      await output.writeAsBytes(const <int>[4, 2]);
    };
    configure?.call(gateways);
  },
);

void main() {
  testWidgets('Record again records a new take and opens the editor to '
      'replace the clip; the editor\'s Record again opens the camera above '
      'it and keeps the replace, and the new save reaches the Edit sheet', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await _launch(tester);

    final RouteResult<SavedClip> result = await _recordAgain(app);
    app.recording.expectLive();
    await app.recording.pressShutter();
    await app.recording.wait(const Duration(seconds: 3));
    final String firstTake = app.recording.camera.current!.recordings.single;
    app.shell.expectOpenedWith(_editorOn(firstTake));

    await app.clipEditor.waitForTheSource();
    await app.clipEditor.tapCut(1);
    await app.clipEditor.pressBack();
    app.clipEditor.expectDiscardDialog(recordAgain: true);
    await app.clipEditor.tapRecordAgain();
    app.shell.expectAt(AppRoute.record);
    app.recording.expectLive();
    await app.recording.pressShutter();
    await app.recording.wait(const Duration(seconds: 3));
    final String secondTake = app.recording.camera.current!.recordings.single;
    app.shell
      ..expectOpenedWith(_editorOn(secondTake))
      ..expectNoPageOf(AppRoute.record);

    await app.clipEditor.waitForTheSource();
    await app.clipEditor.tapSave();
    await app.harness.settleUntil(
      () => result.popped,
      reason: 'the new take is saved and both editors leave',
    );

    expect(result.value!.ref, _clip);
    expect(result.value!.replaced, isTrue);
    app.shell.expectAt(AppRoute.today);
    app.recording.expectReleased();
    // The first take was given up, the second filed.
    expect(File(firstTake).existsSync(), isFalse);
    expect(File(secondTake).existsSync(), isFalse);
    app.expectNoPluginChannel();
  });

  testWidgets('with "Force native camera", the editor\'s Record again records '
      'with the phone\'s camera app and keeps the replace', (
    WidgetTester tester,
  ) async {
    late String firstTake;
    late String recorded;
    final AppRobot app = await _launch(
      tester,
      extraPrefs: const <String, Object>{'forceNativeCamera': true},
      seed: (AppPaths paths) async {
        final File first = File('${paths.temporaryDir}/VID_first.mp4');
        final File second = File('${paths.temporaryDir}/VID_20240105.mp4');
        await first.create(recursive: true);
        await first.writeAsBytes(fakeVideoBytes);
        await second.writeAsBytes(fakeVideoBytes);
        firstTake = first.path;
        recorded = second.path;
      },
      configure: (FakeGateways gateways) =>
          gateways.picker.cameraAnswers.add(Picked(recorded)),
    );
    final RouteResult<SavedClip> result = await app.shell
        .openForResult<SavedClip>(_editorOn(firstTake));
    await app.clipEditor.waitForTheSource();
    await app.clipEditor.tapCut(1);
    await app.clipEditor.pressBack();

    await app.clipEditor.tapRecordAgain();
    await app.harness.settleUntil(
      () => app.recording.picker.cameraOpened,
      reason: "the phone's camera app records",
    );

    expect(app.recording.camera.sessions, isEmpty, reason: 'no in-app lens');
    app.shell
      ..expectOpenedWith(_editorOn(recorded))
      ..expectNoPageOf(AppRoute.record);

    // Left without a clip (back asks, and Discard gives the new take up),
    // the first editor is as it was.
    await app.clipEditor.discardAbove();
    expect(File(recorded).existsSync(), isFalse);
    app.clipEditor
      ..expectShown()
      ..expectSelectedCut(1);
    await app.clipEditor.discard();
    expect(result.value, isNull);
  });
}
