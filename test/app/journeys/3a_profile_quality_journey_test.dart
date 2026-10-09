// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/edit_profile_sheet.dart';
import 'package:one_second_diary/features/profiles/presentation/widgets/locked_quality_row.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

void main() {
  // The format belongs to the profile and is written once: the New profile sheet's
  // Quality row picks it; Edit profile shows it locked, with "Convert into a new
  // profile" as the only way to another quality.
  testWidgets('a user makes a portrait profile with the "Smaller files" '
      'quality: its format is stored once beside its canvas, and Edit '
      'profile shows it locked', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());
    const ProfileKey trip = ProfileKey('Trip');

    await app.settings.openProfiles();
    await app.profiles.openNew();
    await app.profiles.enterName('Trip');
    await app.profiles.pickOrientation(VideoOrientation.portrait);
    await app.profiles.pickQuality(ClipFormatPreset.smallerFiles);
    await app.profiles.submit();

    expect(app.profiles.activeTile, 'Trip');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('profiles'), <String>['Default', 'Trip']);
    expect(prefs.getString('orientation_Trip'), 'portrait');
    expect(prefs.getString('clipFormat_Trip'), '1080p30-hevc-stereo-sdr');

    await app.profiles.openEdit(trip);
    expect(find.byType(LockedQualityRow), findsOneWidget);
    expect(find.byKey(EditProfileSheet.convertKey), findsOneWidget);
    await app.profiles.pressBack();
    expect(app.profiles.sheetOpen, isFalse);
    app.expectNoPluginChannel();
  });
}
