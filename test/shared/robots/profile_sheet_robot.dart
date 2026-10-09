import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/profile_switch_sheet.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet_title.dart';
import 'package:one_second_diary/shared/widgets/controls/profile_option_tile.dart';

import '../harness/app_harness.dart';
import '../harness/settle.dart';

/// The profile switch sheet (`ProfileSwitchSheet`) as the user drives it,
/// over [AppHarness]: `app.profileSheet`. Today's profile chip, the clip
/// editor's "Change" and the movie flow's profile chip open it.
class ProfileSheetRobot {
  ProfileSheetRobot(this.harness);

  final AppHarness harness;

  WidgetTester get tester => harness.tester;

  Finder _row(ProfileKey profile) =>
      find.byKey(ProfileSwitchSheet.rowKey(profile));

  void expectShown({required String title}) {
    expect(find.byKey(ProfileSwitchSheet.bodyKey), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(OsdSheetTitle.titleKey)).data, title);
  }

  void expectClosed() =>
      expect(find.byKey(ProfileSwitchSheet.bodyKey), findsNothing);

  /// Whether it offers "Create new profile" (not in the movie flow).
  bool get offersCreate =>
      find.byKey(ProfileSwitchSheet.createKey).evaluate().isNotEmpty;

  /// The rows' names, top to bottom.
  List<String> get names => tester
      .widgetList<ProfileOptionTile>(
        find.descendant(
          of: find.byKey(ProfileSwitchSheet.bodyKey),
          matching: find.byType(ProfileOptionTile),
        ),
      )
      .map((ProfileOptionTile tile) => tile.name)
      .toList();

  ProfileOptionTile _tile(ProfileKey profile) =>
      tester.widget<ProfileOptionTile>(
        find.descendant(
          of: _row(profile),
          matching: find.byType(ProfileOptionTile),
          matchRoot: true,
        ),
      );

  /// "Landscape · 2 videos".
  String subtitleOf(ProfileKey profile) => _tile(profile).subtitle;

  /// The row of [profile] is the checked one.
  void expectSelected(ProfileKey profile) {
    expect(_tile(profile).selected, isTrue);
    expect(
      find.descendant(
        of: _row(profile),
        matching: find.byKey(ProfileOptionTile.checkKey),
      ),
      findsOneWidget,
    );
  }

  /// The photo the row of [profile] shows, if any.
  ImageProvider? photoOf(ProfileKey profile) => _tile(profile).photo;

  /// Taps the row of [profile]; the sheet shows the choice, then closes.
  Future<void> tap(ProfileKey profile) async {
    await tester.tap(_row(profile));
    await settle(tester);
  }

  /// Long-presses the row of [profile] (Edit profile, from Today).
  Future<void> longPress(ProfileKey profile) async {
    await tester.longPress(_row(profile));
    await settle(tester);
  }

  /// Taps "Create new profile": this sheet closes and New profile opens.
  Future<void> tapCreate() async {
    await tester.tap(find.byKey(ProfileSwitchSheet.createKey));
    await settle(tester);
  }

  /// Closes it with the system back button.
  Future<void> pressBack() async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }
}
