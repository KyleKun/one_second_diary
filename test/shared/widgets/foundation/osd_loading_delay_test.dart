import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_loading_delay.dart';

import '../support/osd_widget_harness.dart';

const Key _loading = Key('loading');
const Key _idle = Key('idle');

Widget _delay({required bool loading}) => OsdLoadingDelay(
  loading: loading,
  builder: (context, show) =>
      show ? const SizedBox(key: _loading) : const SizedBox(key: _idle),
);

void main() {
  testWidgets('the loading visual waits 150 ms (§4.2), never shows for quick '
      'work and hides as soon as loading ends', (tester) async {
    await pumpOsd(tester, _delay(loading: true));
    await tester.pump(const Duration(milliseconds: 100));
    await pumpOsd(tester, _delay(loading: false));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(_loading), findsNothing, reason: 'quick work');

    await pumpOsd(tester, _delay(loading: true));
    await tester.pump(const Duration(milliseconds: 149));
    expect(find.byKey(_idle), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(_loading), findsOneWidget);

    await pumpOsd(tester, _delay(loading: false));
    expect(find.byKey(_idle), findsOneWidget);
  });
}
