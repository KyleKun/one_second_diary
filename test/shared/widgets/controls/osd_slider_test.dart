import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_slider.dart';
import 'package:one_second_diary/theme/osd_design_system.dart';

import '../support/osd_widget_harness.dart';

/// Keeps the slider's value in a parent, as a page would.
class _Host extends StatefulWidget {
  const _Host({required this.changes, required this.ends});

  final List<double> changes;
  final List<double> ends;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  double _value = 2;

  @override
  Widget build(BuildContext context) => OsdForcedDark(
    child: SizedBox(
      width: 320,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: OsdSlider(
          value: _value,
          min: 2,
          max: 10,
          divisions: 8,
          marks: const <OsdSliderMark>[
            OsdSliderMark(value: 2, label: '2s'),
            OsdSliderMark(value: 10, label: '10s'),
          ],
          semanticsLabel: 'Clip length',
          semanticsValue: (value) => '${value.round()} seconds',
          onChanged: (value) {
            widget.changes.add(value);
            setState(() => _value = value);
          },
          onChangeEnd: widget.ends.add,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a drag steps through whole divisions with selectionClick and '
      'ends on release; a tap jumps; a screen reader reads and steps the '
      'value', (tester) async {
    final handle = tester.ensureSemantics();
    final haptics = recordHaptics(tester);
    final changes = <double>[];
    final ends = <double>[];
    await pumpOsd(tester, _Host(changes: changes, ends: ends));

    final track = tester.getRect(find.byKey(OsdSlider.trackKey));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(OsdSlider.thumbKey)),
    );
    await gesture.moveTo(Offset(track.left + 40, track.center.dy));
    await gesture.moveTo(Offset(track.left + 42, track.center.dy));
    await gesture.moveTo(Offset(track.left + 120, track.center.dy));
    await gesture.up();
    await tester.pump();
    expect(changes, <double>[3, 5]);
    expect(haptics, <String>['selectionClick', 'selectionClick']);
    expect(ends, <double>[5]);

    await tester.tapAt(Offset(track.right - 2, track.center.dy));
    await tester.pump();
    expect(changes.last, 10);
    expect(ends.last, 10);

    final node = tester.getSemantics(find.byKey(OsdSlider.touchKey));
    expect(
      node,
      isSemantics(
        label: 'Clip length',
        value: '10 seconds',
        decreasedValue: '9 seconds',
        isSlider: true,
        hasDecreaseAction: true,
      ),
    );
    node.owner!.performAction(node.id, SemanticsAction.decrease);
    await tester.pump();
    expect(changes.last, 9);
    handle.dispose();
  });
}
