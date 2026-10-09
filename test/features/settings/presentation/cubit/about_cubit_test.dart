// The installed version and its build number (read at runtime) and the
// copyright year (`Clock.now().year`).

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/about_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/about_state.dart';

import '../../../../shared/fakes/fake_app_info_gateway.dart';
import '../../../../support/support.dart';

void main() {
  test('the copyright year is the current one; the version, with its build '
      'number when there is one, is read when the page asks', () async {
    for (final (String? build, String label) in <(String?, String)>[
      ('57', '2.0.0 (57)'),
      (null, '2.0.0'),
    ]) {
      final AboutCubit about = AboutCubit(
        appInfo: FakeAppInfoGateway(appVersion: '2.0.0', appBuild: build),
        clock: FakeClock(DateTime(2027, 3, 14)),
      );
      addTearDown(about.close);
      expect(about.state, const AboutState(year: 2027));

      await about.loadVersion();

      expect(about.state.versionLabel, label);
    }
  });
}
