// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/platform/app_permission.dart';
import 'package:one_second_diary/core/platform/app_permission_status.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/harness/seeds.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

void main() {
  const ProfileKey trip = ProfileKey('Trip');
  late String recording;

  Future<AppRobot> launch(
    WidgetTester tester, {
    Map<String, Object> extra = const <String, Object>{},
    void Function(FakeGateways gateways)? configure,
  }) => AppRobot.launch(
    tester,
    prefs: prefsWithProfiles(const <ProfileSeed>[
      ProfileSeed('Trip', orientation: 'portrait'),
    ], extra: extra),
    seed: (AppPaths paths) async {
      final File video = File('${paths.temporaryDir}/REC_1.mp4');
      await video.create(recursive: true);
      await video.writeAsBytes(fakeVideoBytes);
      recording = video.path;
    },
    configureGateways: (FakeGateways gateways) {
      gateways.players.duration = const Duration(seconds: 4);
      configure?.call(gateways);
    },
  );

  EditClipArgs editRecording() => EditClipArgs(
    source: VideoSource(path: recording, ownership: ClipOwnership.cameraTemp),
    day: LocalDay(2024, 1, 5),
    profile: ProfileKey.defaultProfile,
  );

  Future<void> openEditor(AppRobot app) async {
    await app.shell.open(editRecording());
    await app.clipEditor.waitForTheSource();
  }

  testWidgets('"Change" sends this clip to another profile; the app stays '
      'on its own, the preview takes the portrait canvas', (tester) async {
    final AppRobot app = await launch(tester);
    await openEditor(app);
    expect(app.clipEditor.profileName, Strings.defaultProfile);

    await app.clipEditor.tapChangeProfile();
    app.profileSheet
      ..expectShown(title: Strings.saveVideoSavingInto)
      ..expectSelected(ProfileKey.defaultProfile);
    await app.profileSheet.tap(trip);

    expect(app.clipEditor.profileName, 'Trip');
    expect(app.clipEditor.previewHeight, 300);
    expect(
      app.clipEditor.fitNote,
      Strings.saveVideoOrientationFitNote(
        orientation: Strings.cameraOrientationWordPortrait,
      ),
    );
    expect(app.clipEditor.appProfile, ProfileKey.defaultProfile);
    app.expectNoPluginChannel();
  });

  testWidgets('the date stamp: every change shows at once on the preview, '
      'and the next clip starts with it', (tester) async {
    final AppRobot app = await launch(tester);
    await openEditor(app);
    expect(app.clipEditor.dateStampValue, '01/05/2024');
    expect(app.clipEditor.previewDate, '01/05/2024');

    await app.clipEditor.openDateStamp();
    await app.clipEditor.pickDateFormat('January 5, 2024');
    await app.clipEditor.pickStampColor(Strings.colorCoral);
    await app.clipEditor.toggleOutline();

    expect(app.clipEditor.previewDate, 'January 5, 2024');
    expect(app.clipEditor.previewStampColor, const Color(0xFFEF5558));
    expect(app.clipEditor.previewOutline, isFalse);
    await app.clipEditor.tapDateStampDone();
    expect(app.clipEditor.dateStampValue, 'January 5, 2024');
    await app.clipEditor.discard();

    await openEditor(app);
    expect(app.clipEditor.dateStampValue, 'January 5, 2024');
    expect(app.clipEditor.previewStampColor, const Color(0xFFEF5558));
    expect(app.clipEditor.previewOutline, isFalse);
  });

  testWidgets('"Show my location" finds the place, stamps it, and stays on '
      'for the next clip', (tester) async {
    final AppRobot app = await launch(tester);
    await openEditor(app);
    await app.clipEditor.openLocationTab();
    expect(app.clipEditor.locationValue, Strings.saveVideoLocationOffValue);
    expect(find.text(Strings.saveVideoLocationDisclosure), findsOneWidget);

    await app.clipEditor.tapShowMyLocation();

    expect(app.clipEditor.locationOn, isTrue);
    expect(app.clipEditor.locationValue, 'Tokyo, Japan');
    expect(app.clipEditor.previewPlace, 'Tokyo, Japan');
    expect(app.harness.gateways.location.localesRequested, <String>['en']);
    await app.clipEditor.discard();

    await openEditor(app);
    await app.clipEditor.openLocationTab();
    await app.clipEditor.waitForTheLocation();
    expect(app.clipEditor.locationOn, isTrue);
    expect(app.clipEditor.previewPlace, 'Tokyo, Japan');
  });

  testWidgets('a place typed instead turns the switch off and has no '
      'coordinates; turned on again, the place found replaces it, and Undo '
      'brings it back', (tester) async {
    final AppRobot app = await launch(tester);
    await openEditor(app);
    await app.clipEditor.openLocationTab();
    await app.clipEditor.tapShowMyLocation();

    await app.clipEditor.typePlace('Grandma’s garden');

    expect(app.clipEditor.typedPlace, 'Grandma’s garden');
    expect(app.clipEditor.locationOn, isFalse);
    expect(app.clipEditor.previewPlace, 'Grandma’s garden');
    expect(app.clipEditor.clipLocation.latitude, isNull);
    expect(app.clipEditor.clipLocation.longitude, isNull);

    await app.clipEditor.tapShowMyLocation();

    expect(app.clipEditor.typedPlace, isNull);
    expect(app.clipEditor.previewPlace, 'Tokyo, Japan');
    expect(find.text(Strings.saveVideoTypedLocationRemoved), findsOneWidget);
    await app.clipEditor.undoTypedPlaceRemoval();

    expect(app.clipEditor.typedPlace, 'Grandma’s garden');
    expect(app.clipEditor.previewPlace, 'Grandma’s garden');
  });

  testWidgets('offline, no place comes back: the switch stays on and a '
      'place can be typed', (tester) async {
    final AppRobot app = await launch(
      tester,
      configure: (FakeGateways gateways) => gateways.location.placeResults
        ..add(const SocketException('offline'))
        ..add(const SocketException('offline'))
        ..add(const SocketException('offline')),
    );
    await openEditor(app);
    await app.clipEditor.openLocationTab();

    await app.clipEditor.tapShowMyLocation();

    expect(app.clipEditor.locationOn, isTrue);
    expect(app.clipEditor.locationValue, Strings.saveVideoLocationUnavailable);
    expect(app.clipEditor.previewPlace, isNull);

    await app.clipEditor.typePlace('Kyoto');
    expect(app.clipEditor.previewPlace, 'Kyoto');
  });

  testWidgets('location blocked: the switch stays off, and the dialog opens '
      "the phone's settings", (tester) async {
    final AppRobot app = await launch(
      tester,
      configure: (FakeGateways gateways) =>
          gateways.permissions.answers[AppPermission.location] =
              AppPermissionStatus.permanentlyDenied,
    );
    await openEditor(app);
    await app.clipEditor.openLocationTab();

    await app.clipEditor.tapShowMyLocation();

    expect(app.clipEditor.locationOn, isFalse);
    expect(app.clipEditor.locationValue, Strings.saveVideoLocationAllow);
    app.clipEditor.expectLocationDialog(
      Strings.locationPermissionPermanentlyDenied,
    );
    await app.clipEditor.tapOpenSettings();

    expect(app.harness.gateways.permissions.settingsOpened, isTrue);
  });

  testWidgets('a subtitle: the first visit opens V4; saved, it is on the '
      'card (the preview never draws it)', (tester) async {
    final AppRobot app = await launch(tester);
    await openEditor(app);

    await app.clipEditor.openSubtitlesTab();
    app.subtitleSheet.expectOpen();
    await app.subtitleSheet.enterText('First time at Senso-ji');
    await app.subtitleSheet.tapSave();

    expect(app.clipEditor.subtitlesValue, 'First time at Senso-ji');

    await app.clipEditor.openSubtitles();
    app.subtitleSheet.expectText('First time at Senso-ji');
    await app.subtitleSheet.pressBack();
    expect(app.clipEditor.subtitlesValue, 'First time at Senso-ji');
    app.expectNoPluginChannel();
  });
}
