// ignore_for_file: file_names

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/features/onboarding/presentation/pages/phone_check_page.dart';
import 'package:one_second_diary/features/onboarding/presentation/widgets/phone_check_result_card.dart';
import 'package:one_second_diary/features/settings/presentation/pages/settings_tab_page.dart';

import '../../shared/robots/app_robot.dart';
import '../../support/support.dart';

void main() {
  // "Check again": the phone check page from Settings runs the check when none was
  // stored and shows its result with "Check again".
  testWidgets('Settings › Check again opens the phone check, which runs on '
      'an install never checked and shows its result; back returns to '
      'Settings', (WidgetTester tester) async {
    final AppRobot app = await AppRobot.launch(tester, prefs: legacyPrefs());

    await app.settings.tapRow(SettingsTabPage.phoneCheckRowKey);

    app.shell.expectAt(AppRoute.phoneCheck);
    await app.harness.settleUntil(
      () => find.byType(PhoneCheckResultCard).evaluate().isNotEmpty,
      reason: 'the check runs over the fakes and shows its result',
    );
    expect(find.byKey(PhoneCheckPage.againKey), findsOneWidget);
    expect(find.text(Strings.phoneCheckRunAgain), findsWidgets);
    expect(
      app.harness.gateways.ffmpeg.executed.any(
        (List<String> run) => run.contains('lavfi'),
      ),
      isTrue,
      reason: 'the synthetic encode tests ran',
    );
    expect(
      (await app.harness.storedPrefs).getString('deviceMediaProfile'),
      isNotEmpty,
    );

    await app.shell.pressBack();
    app.shell.expectAt(AppRoute.settings);
    app.expectNoPluginChannel();
  });
}
