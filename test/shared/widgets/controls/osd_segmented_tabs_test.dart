import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_segmented_tabs.dart';
import 'package:one_second_diary/theme/osd_design_system.dart';

import '../support/osd_widget_harness.dart';

void main() {
  testWidgets('each tab is a selected-or-not button "Tab i of n"; tapping '
      'another tab reports it with selectionClick, the current one does '
      'nothing', (tester) async {
    final handle = tester.ensureSemantics();
    final haptics = recordHaptics(tester);
    final picked = <int>[];
    await pumpOsd(
      tester,
      SizedBox(
        width: 358,
        child: OsdSegmentedTabs(
          segments: <OsdSegment>[
            OsdSegment(
              icon: OsdIcons.tune,
              accent: OsdColors.dark.co,
              label: 'General',
            ),
            OsdSegment(
              icon: OsdIcons.place,
              accent: OsdColors.dark.purple,
              label: 'Location',
            ),
            OsdSegment(
              icon: OsdIcons.subtitles,
              accent: OsdColors.dark.yellow,
              label: 'Subtitles',
            ),
          ],
          index: 1,
          onChanged: picked.add,
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byKey(OsdSegmentedTabs.segmentKey(1))),
      isSemantics(
        label: 'Location',
        hint: 'Tab 2 of 3',
        isSelected: true,
        isButton: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(OsdSegmentedTabs.segmentKey(0))),
      isSemantics(label: 'General', hint: 'Tab 1 of 3', isSelected: false),
    );
    await expectTapTargetGuidelines(tester);

    await tester.tap(find.text('General'));
    await tester.tap(find.text('Location'));
    expect(picked, <int>[0]);
    expect(haptics, <String>['selectionClick']);
    handle.dispose();
  });
}
