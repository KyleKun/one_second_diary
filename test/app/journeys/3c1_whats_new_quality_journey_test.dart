// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/profiles/presentation/sheets/whats_new_quality_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/harness/settle.dart';
import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

void main() {
  // An install that ran the first schema step (`osdSchemaVersion` 1) gets the one-time
  // "What's new: quality" sheet from step 2, shown on Today once the diary is read.
  // The harness seeds the current schema version for every other journey.
  testWidgets('an updated install sees "What\'s new: quality" once on '
      'Today; Not now closes it for good', (WidgetTester tester) async {
    AppRobot app = await AppRobot.launch(
      tester,
      prefs: legacyPrefs(extra: <String, Object>{'osdSchemaVersion': 1}),
    );

    await app.harness.settleUntil(
      () => find.byKey(WhatsNewQualitySheet.sheetKey).evaluate().isNotEmpty,
      reason: 'the sheet opens once the diary is read',
    );
    expect(find.text(Strings.whatsNewQualityTitle), findsOneWidget);
    expect(find.byKey(WhatsNewQualitySheet.newProfileKey), findsOneWidget);
    expect(find.byKey(WhatsNewQualitySheet.convertKey), findsOneWidget);

    await tester.tap(find.byKey(WhatsNewQualitySheet.notNowKey));
    await settle(tester);

    expect(find.byKey(WhatsNewQualitySheet.sheetKey), findsNothing);
    app.shell.expectAt(AppRoute.today);
    final SharedPreferences stored = await app.harness.storedPrefs;
    expect(stored.getInt('osdSchemaVersion'), 2);
    expect(stored.getBool('whatsNewQuality'), isFalse);
    // Existing profiles never change format: nothing was written for Default.
    expect(stored.containsKey('clipFormat_'), isFalse);

    // The next launch has nothing new to say.
    app = await app.relaunch();
    await settle(tester);
    app.shell.expectAt(AppRoute.today);
    expect(find.byKey(WhatsNewQualitySheet.sheetKey), findsNothing);
    app.expectNoPluginChannel();
  });
}
