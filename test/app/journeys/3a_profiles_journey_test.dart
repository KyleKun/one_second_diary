// ignore_for_file: file_names

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/picker_gateway.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/profile_photo_sheet.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/profile_sheets.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/profile_switch_sheet.dart';
import 'package:one_second_diary/features/settings/presentation/pages/settings_tab_page.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/harness/fake_gateways.dart';
import '../../shared/harness/seeds.dart';
import '../../shared/robots/app_robot.dart';
import '../../shared/robots/shell_robot.dart';
import '../../support/support.dart';

void main() {
  Future<String> photoToPick(AppRobot app) async {
    final File photo = File('${app.harness.paths.temporaryDir}/pick.png');
    await app.tester.runAsync(() async {
      await photo.parent.create(recursive: true);
      await photo.writeAsBytes(onePixelPng);
    });
    return photo.path;
  }

  Future<Map<String, Object?>> profileMeta() async =>
      jsonDecode(
            (await SharedPreferences.getInstance()).getString('profileMeta') ??
                '{}',
          )
          as Map<String, Object?>;

  Finder snackbarText(String text) =>
      find.descendant(of: find.byType(OsdSnackbar), matching: find.text(text));

  testWidgets('a user creates a profile with a photo, switches to it and '
      'back, renames it and deletes it', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    const ProfileKey viagem = ProfileKey('Viagem');

    await app.settings.openProfiles();
    await app.profiles.openNew();
    app.harness.gateways.picker.photoAnswers.add(
      Picked(await photoToPick(app)),
    );
    await app.profiles.choosePhoto(ProfilePhotoChoice.gallery);
    await app.profiles.enterName('Viagem');
    await app.profiles.pickOrientation(VideoOrientation.portrait);
    await app.profiles.submit();

    expect(app.profiles.names, <String>[Strings.defaultProfile, 'Viagem']);
    expect(app.profiles.activeTile, 'Viagem');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('profiles'), <String>['Default', 'Viagem']);
    expect(prefs.getInt('selectedProfileIndex'), 1);
    expect(prefs.getString('orientation_Viagem'), 'portrait');
    final String photo =
        ((await profileMeta())['Viagem']!
                as Map<String, Object?>)['avatarRelPath']!
            as String;
    final File photoFile = File('${app.harness.paths.internal}/$photo');
    expect(photoFile.existsSync(), isTrue);
    expect(
      Directory(app.harness.paths.profileVideos(viagem)).existsSync(),
      isTrue,
    );

    await app.profiles.tapTile(ProfileKey.defaultProfile);
    expect(app.profiles.activeTile, Strings.defaultProfile);
    expect(prefs.getInt('selectedProfileIndex'), 0);
    await app.profiles.tapTile(viagem);
    expect(app.profiles.activeTile, 'Viagem');
    expect(prefs.getInt('selectedProfileIndex'), 1);

    // Rename: only the display name changes.
    await app.profiles.openEdit(viagem);
    await app.profiles.enterName('Viagem ✈');
    await app.profiles.submit();
    expect(app.profiles.names, <String>[Strings.defaultProfile, 'Viagem ✈']);
    expect(prefs.getStringList('profiles'), <String>['Default', 'Viagem']);
    expect((await profileMeta())['Viagem'], <String, Object?>{
      'displayName': 'Viagem ✈',
      'avatarRelPath': photo,
    });
    await app.shell.pressBack();
    expect(app.settings.valueOf(SettingsTabPage.profilesRowKey), 'Viagem ✈');

    await app.settings.openProfiles();
    await app.profiles.openEdit(viagem);
    await app.profiles.delete();

    expect(app.profiles.names, <String>[Strings.defaultProfile]);
    expect(app.profiles.activeTile, Strings.defaultProfile);
    expect(snackbarText(Strings.profileDeleted), findsOneWidget);
    expect(prefs.getStringList('profiles'), <String>['Default']);
    expect(prefs.getInt('selectedProfileIndex'), 0);
    expect(prefs.containsKey('orientation_Viagem'), isFalse);
    expect(await profileMeta(), isEmpty);
    expect(photoFile.existsSync(), isFalse);
    app.expectNoPluginChannel();
  });

  testWidgets('deleting a profile deletes its clips on the phone', (
    WidgetTester tester,
  ) async {
    const ProfileKey travel = ProfileKey('Travel');
    late List<File> clips;
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: prefsWithProfiles(<ProfileSeed>[const ProfileSeed('Travel')]),
      seed: (AppPaths paths) async => clips = await seedDayClips(
        paths,
        travel,
        LocalDay(2024, 1, 4),
        count: 2,
      ),
    );
    await app.settings.openProfiles();
    await app.harness.settleUntil(
      () => app.profiles.subtitleOf(travel).contains('2'),
      reason: 'S4 counts the clips of Travel',
    );

    await app.profiles.openEdit(travel);
    await app.profiles.delete();

    expect(app.profiles.names, <String>[Strings.defaultProfile]);
    expect(clips.map((File clip) => clip.existsSync()), <bool>[false, false]);
    expect(snackbarText(Strings.profileDeleted), findsOneWidget);
    expect(snackbarText(Strings.profileDeletedKeptVideos(1)), findsNothing);
    expect(app.profiles.found, isEmpty);
  });

  testWidgets('clips the phone keeps (the user declines Android\'s consent '
      'for a previous install\'s clips) stay; S4 offers them back, and "Add '
      'back" makes the profile again', (WidgetTester tester) async {
    const ProfileKey travel = ProfileKey('Travel');
    late List<File> clips;
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: prefsWithProfiles(<ProfileSeed>[
        const ProfileSeed('Travel', orientation: 'portrait'),
      ]),
      seed: (AppPaths paths) async => clips = await seedDayClips(
        paths,
        travel,
        LocalDay(2024, 1, 4),
        count: 2,
      ),
      configureGateways: (FakeGateways gateways) =>
          gateways.mediaStore.deleteResults.add(false),
    );
    await app.settings.openProfiles();

    await app.profiles.openEdit(travel);
    await app.profiles.delete();

    expect(app.profiles.names, <String>[Strings.defaultProfile]);
    expect(snackbarText(Strings.profileDeleted), findsOneWidget);
    expect(snackbarText(Strings.profileDeletedKeptVideos(1)), findsOneWidget);
    expect(clips.where((File clip) => clip.existsSync()), hasLength(1));
    await app.profiles.expectFound(<String>['Travel']);

    await app.profiles.addBack(travel);
    expect(app.profiles.names, <String>[Strings.defaultProfile, 'Travel']);
    expect(app.profiles.activeTile, Strings.defaultProfile);
    await app.harness.settleUntil(
      () =>
          app.profiles.subtitleOf(travel) ==
          Strings.profileRowSubtitle(1, orientation: Strings.portrait),
      reason: 'the profile added back is portrait again, with its clip',
    );
    expect(
      (await SharedPreferences.getInstance()).getStringList('profiles'),
      <String>['Default', 'Travel'],
    );
    app.expectNoPluginChannel();
  });

  testWidgets('from Today\'s profile sheet (T6), "Create new profile" opens '
      'New profile; the sheet gives the new profile back, already active', (
    WidgetTester tester,
  ) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    final RouteResult<ProfileKey> picked = RouteResult<ProfileKey>(
      ProfileSwitchSheet.show(
        app.shell.pageElement(AppRoute.today),
        selected: ProfileKey.defaultProfile,
        editable: true,
      ),
    );
    await app.harness.settleUntil(
      () => find.byKey(ProfileSwitchSheet.bodyKey).evaluate().isNotEmpty,
      reason: 'T6 shows',
    );

    await app.profileSheet.tapCreate();
    expect(find.byKey(ProfileSheets.newProfileKey), findsOneWidget);
    await app.profiles.enterName('Kids');
    await app.profiles.pickOrientation(VideoOrientation.landscape);
    await app.profiles.submit();

    expect(picked.value, const ProfileKey('Kids'));
    app.profiles.expectActiveName('Kids');
    expect(
      snackbarText(Strings.profileActivated(name: 'Kids')),
      findsOneWidget,
    );
  });

  testWidgets('a long press in Today\'s profile sheet (T6) opens Edit '
      'profile for that profile', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(
      tester,
      prefs: prefsWithProfiles(<ProfileSeed>[const ProfileSeed('Travel')]),
    );
    final RouteResult<ProfileKey> picked = RouteResult<ProfileKey>(
      ProfileSwitchSheet.show(
        app.shell.pageElement(AppRoute.today),
        selected: ProfileKey.defaultProfile,
        editable: true,
      ),
    );
    await app.harness.settleUntil(
      () => find.byKey(ProfileSwitchSheet.bodyKey).evaluate().isNotEmpty,
      reason: 'T6 shows',
    );

    await app.profileSheet.longPress(const ProfileKey('Travel'));

    expect(find.byKey(ProfileSheets.editProfileKey), findsOneWidget);
    expect(app.profiles.nameText, 'Travel');
    await app.profiles.pressBack();
    expect(picked.value, isNull);
  });
}
