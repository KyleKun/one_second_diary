import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';

import '../support/osd_widget_harness.dart';

const Key _box = Key('box');

Finder get _pressable => find.byType(OsdPressable);

void main() {
  testWidgets('a tap, or Enter once focused, runs onTap with its haptic; it '
      'is a button named by its label', (tester) async {
    final handle = tester.ensureSemantics();
    final haptics = recordHaptics(tester);
    var taps = 0;
    await pumpOsd(
      tester,
      OsdPressable(
        onTap: () => taps++,
        haptic: OsdHaptic.light,
        semanticsLabel: 'Save',
        child: const SizedBox(key: _box, width: 120, height: 52),
      ),
    );

    expect(
      tester.getSemantics(_pressable),
      isSemantics(
        label: 'Save',
        isButton: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(_pressable);
    expect(taps, 1);
    expect(haptics, <String>['lightImpact']);

    Focus.of(tester.element(find.byKey(_box))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 2);
    handle.dispose();
  });

  testWidgets('disabled: disabled semantics, skipped by focus, and only '
      'onDisabledTap hears the tap', (tester) async {
    final handle = tester.ensureSemantics();
    var disabledTaps = 0;
    await pumpOsd(
      tester,
      OsdPressable(
        onDisabledTap: () => disabledTaps++,
        semanticsLabel: 'Go',
        child: const SizedBox(key: _box, width: 120, height: 52),
      ),
    );

    await tester.tap(_pressable);
    await tester.pump();
    expect(disabledTaps, 1);
    expect(
      tester.getSemantics(_pressable),
      isSemantics(label: 'Go', isButton: true, isEnabled: false),
    );
    expect(Focus.of(tester.element(find.byKey(_box))).canRequestFocus, isFalse);
    handle.dispose();
  });

  testWidgets('a small visual gets a 48 × 48 hit area around its centre', (
    tester,
  ) async {
    var taps = 0;
    await pumpOsd(
      tester,
      OsdPressable(
        onTap: () => taps++,
        semanticsLabel: 'Close',
        child: const SizedBox(key: _box, width: 20, height: 20),
      ),
    );

    final visual = tester.getRect(find.byKey(_box));
    await tester.tapAt(visual.center - const Offset(22, 22));
    await tester.tapAt(visual.center + const Offset(22, 22));
    expect(taps, 2);
    await expectTapTargetGuidelines(tester);
  });
}
