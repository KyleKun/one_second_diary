import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/shared/widgets/progress/animated_count.dart';
import 'package:one_second_diary/theme/osd_design_system.dart';

import '../support/osd_widget_harness.dart';

String _days(int value) => '$value of 28 days';

String _shown(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(AnimatedCount.valueKey)).data!;

int _shownNumber(WidgetTester tester) =>
    int.parse(_shown(tester).split(' ').first);

Widget _count(int value, {bool countUpOnAppear = true}) => AnimatedCount(
  value: value,
  format: _days,
  duration: OsdMotion.countUpShort,
  countUpOnAppear: countUpOnAppear,
);

void main() {
  testWidgets('it counts up from 0 on first show and tweens from the old '
      'value to a new one, while screen readers only hear the final value; '
      'under reduced motion it renders final', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpOsd(tester, _count(25));
    expect(_shown(tester), '0 of 28 days');
    expect(find.bySemanticsLabel('25 of 28 days'), findsOneWidget);
    expect(find.bySemanticsLabel('0 of 28 days'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_shownNumber(tester), inExclusiveRange(0, 25));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_shown(tester), '25 of 28 days');

    await pumpOsd(tester, _count(20, countUpOnAppear: false));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_shownNumber(tester), inExclusiveRange(20, 25));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_shown(tester), '20 of 28 days');
    handle.dispose();

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpOsd(tester, _count(25), disableAnimations: true);
    expect(_shown(tester), '25 of 28 days');
    expect(tester.hasRunningAnimations, isFalse);
  });
}
