import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_area.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_field.dart';

import '../support/osd_widget_harness.dart';

void main() {
  testWidgets('maxLength: a field cuts the text with no counter; an area '
      'shows "n/max" from 100 characters and plays one heavy impact at the '
      'limit', (tester) async {
    final field = TextEditingController();
    addTearDown(field.dispose);
    await pumpOsd(
      tester,
      SizedBox(
        width: 350,
        child: OsdTextField(
          controller: field,
          hint: 'Profile name',
          maxLength: 5,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Weekends');
    expect(field.text, 'Weeke');
    expect(find.textContaining('/5'), findsNothing);

    final haptics = recordHaptics(tester);
    final area = TextEditingController();
    addTearDown(area.dispose);
    await pumpOsd(
      tester,
      SizedBox(
        width: 350,
        child: OsdTextArea(
          controller: area,
          hint: 'What happened in this second?',
          maxLength: 120,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'a' * 99);
    await tester.pump();
    expect(find.byKey(OsdTextArea.counterKey), findsNothing);

    await tester.enterText(find.byType(TextField), 'a' * 100);
    await tester.pump();
    expect(find.text('100/120'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'a' * 130);
    await tester.pump();
    expect(area.text.length, 120);
    expect(find.text('120/120'), findsOneWidget);
    expect(haptics, <String>['heavyImpact']);

    await tester.enterText(find.byType(TextField), 'a' * 125);
    await tester.pump();
    expect(haptics, <String>['heavyImpact'], reason: 'only once');
  });
}
