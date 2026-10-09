// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_edit_sheet.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

/// `AppHarness.defaultNow`: Friday 5 January 2024.
final ClipRef _todays = ClipRef(
  profile: ProfileKey.defaultProfile,
  relPath: '2024-01-05.mp4',
);

/// What ffmpeg writes for the first save, then for the second.
const List<int> _first = <int>[4, 2];
const List<int> _second = <int>[9, 9, 9];

void main() {
  // With "Keep original recordings" the take is kept beside the diary under the clip's
  // name, the recipe in the sidecar; "Edit again" reopens the editor on that take,
  // and its save takes the clip's place and leaves the take where it is.
  testWidgets('with "Keep original recordings" on, a recording saved at 1 s '
      'keeps its take; Edit again opens the editor on the take with the '
      '1 s cut pre-filled, and saving at 2 s replaces the clip, the take '
      'still there', (WidgetTester tester) async {
    late AppPaths paths;
    late List<int> rendered;
    rendered = _first;
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(extra: <String, Object>{'keepOriginals': true}),
      seed: (AppPaths at) async => paths = at,
      configureGateways: (FakeGateways gateways) {
        gateways.players.duration = const Duration(seconds: 4);
        gateways.ffmpeg.onExecute = (List<String> arguments) async {
          final File output = File(arguments[arguments.length - 2]);
          await output.parent.create(recursive: true);
          await output.writeAsBytes(rendered);
        };
      },
    );
    final File clip = File('${paths.videos}${_todays.relPath}');
    final File original = File('${paths.originals}${_todays.relPath}');

    await app.today.tapRecord();
    await app.recording.pressShutter();
    await app.recording.wait(const Duration(seconds: 3));
    final File take = File(app.recording.camera.current!.recordings.single);
    await app.clipEditor.waitForTheSource();
    await app.clipEditor.tapCut(1);
    await app.clipEditor.tapSave();
    await app.clipEditor.waitUntilSaved();

    app.shell.expectAt(AppRoute.today);
    app.today.expectDayShows(_todays);
    expect(clip.readAsBytesSync(), _first);
    // The take moved beside the diary, under the clip's name.
    expect(original.existsSync(), isTrue);
    expect(take.existsSync(), isFalse);

    await app.today.waitForOriginal(_todays);
    await app.today.tapEdit();
    app.today.expectEditSheet();
    await app.today.pickEdit(TodayEditAction.editAgain);
    await app.clipEditor.waitForTheSource();

    // The editor opened on the take, which it does not own, with the
    // recipe's cut.
    expect(app.clipEditor.source.path, original.path);
    expect(app.clipEditor.source.owned, isFalse);
    app.clipEditor.expectSelectedCut(1);

    rendered = _second;
    await app.clipEditor.tapCut(2);
    await app.clipEditor.tapSave();
    await app.clipEditor.waitUntilSaved();

    app.shell.expectAt(AppRoute.today);
    app.today.expectDayShows(_todays);
    expect(clip.readAsBytesSync(), _second);
    expect(original.existsSync(), isTrue, reason: 'the take is never deleted');
    final List<List<String>> saves = <List<String>>[
      for (final List<String> run in app.harness.gateways.ffmpeg.executed)
        if (run.last == '-y') run,
    ];
    expect(saves, hasLength(2));
    expect(saves.first, containsAllInOrder(<String>['-to', '1000ms']));
    expect(saves.last, contains(original.path));
    expect(saves.last, containsAllInOrder(<String>['-to', '2000ms']));
    app.expectNoPluginChannel();
  });
}
