import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/shared/widgets/buttons/circle_icon_button.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hit_slop.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_overflow_hit_area.dart';
import 'package:one_second_diary/theme/osd_design_system.dart';

import '../support/osd_widget_harness.dart';

void main() {
  testWidgets('taps in the overflow reach the button, the top-most wins where '
      'two overlap, and the tap-target guidelines see 48 boxes', (
    tester,
  ) async {
    final taps = <String>[];
    await pumpOsd(
      tester,
      Padding(
        padding: const EdgeInsets.all(20),
        child: OsdHitSlop(
          slop: const EdgeInsets.all(5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: <Widget>[
              OsdOverflowHitArea(
                child: CircleIconButton(
                  icon: OsdIcons.chevronLeft,
                  tooltip: 'Previous month',
                  onPressed: () => taps.add('previous'),
                ),
              ),
              OsdOverflowHitArea(
                child: CircleIconButton(
                  icon: OsdIcons.chevronRight,
                  tooltip: 'Next month',
                  onPressed: () => taps.add('next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final left = tester.getRect(find.byType(OsdOverflowHitArea).first);

    await tester.tapAt(left.topCenter - const Offset(0, 4));
    await tester.tapAt(left.centerLeft - const Offset(4, 0));
    await tester.tapAt(left.centerRight + const Offset(4, 0));
    expect(taps, <String>['previous', 'previous', 'next']);
    await expectTapTargetGuidelines(tester);
  });
}
