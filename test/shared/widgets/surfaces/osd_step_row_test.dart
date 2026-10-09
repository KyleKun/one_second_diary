import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_step_row.dart';

import '../support/osd_widget_harness.dart';

void main() {
  testWidgets('a numbered step reads as one node; its button, when it has '
      'one, taps and meets the tap target guideline; without onAction it '
      'is disabled', (tester) async {
    final handle = tester.ensureSemantics();
    int taps = 0;
    await pumpOsd(
      tester,
      OsdStepRow(
        number: 2,
        text: 'Tap Open in Files.',
        actionLabel: 'Open in Files',
        onAction: () => taps++,
      ),
    );

    expect(find.text('2'), findsOneWidget);
    expect(find.text('Tap Open in Files.'), findsOneWidget);
    await tester.tap(find.byKey(OsdStepRow.actionKey));
    expect(taps, 1);
    await expectTapTargetGuidelines(tester);

    await pumpOsd(
      tester,
      const OsdStepRow(
        number: 3,
        text: 'A step without a button.',
        note: 'Nothing new in OneSecondDiary',
      ),
      brightness: Brightness.light,
    );
    expect(find.byKey(OsdStepRow.actionKey), findsNothing);
    expect(find.text('Nothing new in OneSecondDiary'), findsOneWidget);
    handle.dispose();
  });
}
