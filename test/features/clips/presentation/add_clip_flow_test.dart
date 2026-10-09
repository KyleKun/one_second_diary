// The add-clip flow: Record, Add video or Add photo for a day and profile,
// through the camera or ImportFlow and the clip editor, back to the opener
// with the saved clip. Shared by Today and the Diary.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_clip_flow.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_clip_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../shared/harness/fake_gateways.dart';
import '../../../shared/harness/settle.dart';
import '../../../shared/robots/app_robot.dart';
import '../../../shared/robots/shell_robot.dart';
import '../../../support/support.dart';

final LocalDay _today = LocalDay(2024, 1, 5);
const ProfileKey _default = ProfileKey.defaultProfile;

void main() {
  late AppRobot app;

  Future<void> launch(
    WidgetTester tester, {
    Map<String, Object> extra = const <String, Object>{},
    void Function(FakeGateways gateways)? configure,
  }) async {
    app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(extra: extra),
      isAndroid: true,
      configureGateways: configure,
    );
  }

  BuildContext page() => app.shell.pageElement(AppRoute.today);

  Future<RouteResult<SavedClip>> start(
    AddClipSource source, {
    LocalDay? day,
    ClipSaveMode mode = const AddClip(),
  }) async {
    final RouteResult<SavedClip> result = RouteResult<SavedClip>(
      AddClipFlow.start(
        page(),
        source: source,
        day: day ?? _today,
        profile: _default,
        mode: mode,
      ),
    );
    await settle(app.tester);
    return result;
  }

  group('Record', () {
    // A take belongs to the day it ends, as in the in-app camera. The flow
    // started on the 4th (Today just before midnight); the phone's camera
    // app came back on the 5th.
    testWidgets("the phone's camera app: the clip is the day it came back "
        'on', (tester) async {
      await launch(
        tester,
        extra: const <String, Object>{'forceNativeCamera': true},
        configure: (FakeGateways gateways) =>
            gateways.picker.cameraAnswers.add(const Picked('/tmp/REC.mp4')),
      );

      await start(AddClipSource.record, day: LocalDay(2024, 1, 4));
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
    });
  });
}
