import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hit_slop.dart';

import '../support/osd_widget_harness.dart';

const Key _target = Key('target');

void main() {
  testWidgets('a tap inside the slop reaches the child, a tap past it misses, '
      'and the slop takes no layout space', (tester) async {
    for (final (EdgeInsets slop, List<Offset> hits, List<Offset> misses)
        in <(EdgeInsets, List<Offset>, List<Offset>)>[
          (
            const EdgeInsets.symmetric(vertical: 3),
            <Offset>[const Offset(20, -2.5), const Offset(20, 44.5)],
            <Offset>[const Offset(20, -4), const Offset(-1, 21)],
          ),
          (
            const EdgeInsets.symmetric(horizontal: 5),
            <Offset>[const Offset(-4, 21), const Offset(44, 21)],
            <Offset>[const Offset(-6, 21), const Offset(20, -1)],
          ),
        ]) {
      var taps = 0;
      await pumpOsd(
        tester,
        Center(
          child: OsdHitSlop(
            slop: slop,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps++,
              child: const SizedBox(key: _target, width: 40, height: 42),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(OsdHitSlop)), const Size(40, 42));
      final origin = tester.getTopLeft(find.byKey(_target));

      for (final Offset at in hits) {
        await tester.tapAt(origin + at);
      }
      expect(taps, hits.length, reason: '$slop: inside');
      for (final Offset at in misses) {
        await tester.tapAt(origin + at);
      }
      expect(taps, hits.length, reason: '$slop: past it');
    }
  });
}
