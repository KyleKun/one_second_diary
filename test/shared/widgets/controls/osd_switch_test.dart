import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_switch.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';

import '../support/osd_widget_harness.dart';

void main() {
  testWidgets('standalone: a labelled toggle that reports the new value with '
      'selectionClick, on a 48 hit area; without onChanged it never toggles', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final haptics = recordHaptics(tester);
    final changes = <bool>[];
    await pumpOsd(
      tester,
      OsdSwitch(
        value: false,
        semanticsLabel: 'Dark mode',
        onChanged: changes.add,
      ),
    );

    expect(
      tester.getSemantics(find.byType(OsdSwitch)),
      isSemantics(
        label: 'Dark mode',
        hasToggledState: true,
        isToggled: false,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.byType(OsdSwitch));
    expect(changes, <bool>[true]);
    expect(haptics, <String>['selectionClick']);
    await expectTapTargetGuidelines(tester);

    await pumpOsd(tester, const OsdSwitch(value: true, semanticsLabel: 'X'));
    await tester.tap(find.byType(OsdSwitch));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byType(OsdSwitch)),
      isSemantics(hasToggledState: true, isToggled: true, isEnabled: false),
    );
    handle.dispose();
  });

  testWidgets('inside a row it is visual only: the row owns the gesture and '
      'the toggled state', (tester) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await pumpOsd(
      tester,
      SizedBox(
        width: 358,
        child: OsdListRow(
          title: 'Countdown',
          trailing: const OsdRowTrailing.custom(
            OsdSwitch(value: true, interactive: false),
          ),
          toggled: true,
          onTap: () => taps++,
        ),
      ),
    );

    await tester.tap(find.byType(OsdSwitch));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Countdown'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Countdown')),
      isSemantics(hasToggledState: true, isToggled: true),
    );
    handle.dispose();
  });
}
