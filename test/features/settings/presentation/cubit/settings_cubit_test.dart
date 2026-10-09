// The Settings tab's own state: the app version (About) and sharing the
// app. Its links: link_cubit_test.dart.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/settings_cubit.dart';

import '../../../../shared/fakes/fake_app_info_gateway.dart';
import '../../../../support/support.dart';

void main() {
  test('reads the app version at runtime; sharing the app hands its text to '
      'the share sheet, anchored on the row (iPad)', () async {
    final FakeShareGateway share = FakeShareGateway();
    final SettingsCubit settings = SettingsCubit(
      appInfo: FakeAppInfoGateway(appVersion: '2.0.0'),
      share: share,
    );
    addTearDown(settings.close);
    const Rect row = Rect.fromLTWH(16, 400, 358, 54);

    await settings.loadVersion();
    await settings.shareApp(text: 'Check out this app', origin: row);

    expect(settings.state.version, '2.0.0');
    expect(share.sharedTexts, <String>['Check out this app']);
    expect(share.lastOrigin, row);
  });
}
