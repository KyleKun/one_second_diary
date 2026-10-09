import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/today/presentation/widgets/record_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_icon_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/round_action_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/tinted_pill_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/viewer_action_tile.dart';
import 'package:one_second_diary/shared/widgets/controls/month_tile.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_switch.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_action_row.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

import '../support/osd_widget_harness.dart';

/// A control that turns off keeps its subtree. A wrapper toggled around it
/// would rebuild it, and an animation running inside would restart.
void main() {
  testWidgets('a control keeps its state when it turns off', (tester) async {
    final Map<String, Widget Function(VoidCallback? onPressed)> controls = {
      'PrimaryButton': (onPressed) =>
          PrimaryButton(label: 'Save', onPressed: onPressed),
      'OsdIconButton': (onPressed) => OsdIconButton(
        icon: OsdIcons.close,
        tooltip: 'Close',
        onPressed: onPressed,
        fadeWhenDisabled: true,
      ),
      'RoundActionButton': (onPressed) => RoundActionButton(
        icon: OsdIcons.videoLibrary,
        label: 'Add video',
        onPressed: onPressed,
      ),
      'TintedPillButton': (onPressed) =>
          TintedPillButton(label: 'Make movie', onPressed: onPressed),
      'ViewerActionTile': (onPressed) => ViewerActionTile(
        icon: OsdIcons.share,
        label: 'Share',
        onPressed: onPressed,
      ),
      'OsdSwitch': (onPressed) => OsdSwitch(
        value: true,
        onChanged: onPressed == null ? null : (_) => onPressed(),
        semanticsLabel: 'Sound',
      ),
      'MonthTile': (onPressed) => MonthTile(
        month: 'May',
        count: '3 videos',
        selected: false,
        onTap: onPressed,
      ),
      'OsdActionRow': (onPressed) =>
          OsdActionRow(icon: OsdIcons.share, label: 'Share', onTap: onPressed),
      'RecordButton': (onPressed) =>
          RecordButton(onPressed: onPressed, semanticsLabel: 'Record'),
    };

    for (final MapEntry(key: name, value: build) in controls.entries) {
      await pumpOsd(tester, SizedBox(width: 200, child: build(() {})));
      final State<OsdPressable> before = tester.state(
        find.byType(OsdPressable),
      );

      await pumpOsd(tester, SizedBox(width: 200, child: build(null)));

      expect(
        tester.state(find.byType(OsdPressable)),
        same(before),
        reason: name,
      );
      // A different control next: start from an empty tree.
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
