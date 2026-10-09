import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

const Duration _ms100 = Duration(milliseconds: 100);
const Duration _ms150 = Duration(milliseconds: 150);

/// Runs [read] under `MediaQuery.disableAnimations` = [reduced].
Future<T> _under<T>(
  WidgetTester tester, {
  required bool reduced,
  required T Function(BuildContext) read,
}) async {
  late T value;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Builder(
        builder: (context) {
          value = read(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return value;
}

void main() {
  // With the system's reduce-motion setting on, motion becomes a short
  // linear crossfade and decorative motion stops.
  testWidgets('reduced motion caps durations at a 150 ms linear crossfade '
      'and stops loops, staggers and deep press scales', (tester) async {
    final reduced = await _under(
      tester,
      reduced: true,
      read: (c) => (
        durations: (
          OsdMotion.d(c, OsdMotion.emphasized),
          OsdMotion.d(c, _ms100),
          OsdMotion.d(c, OsdMotion.countUp),
        ),
        curve: OsdMotion.curve(c, Curves.easeOutBack),
        loops: OsdMotion.loopsEnabled(c),
        stagger: OsdMotion.entranceDelay(c, 0),
        press: <double>[
          for (final category in OsdPressScale.values)
            OsdMotion.pressScale(c, category),
        ],
      ),
    );
    final normal = await _under(
      tester,
      reduced: false,
      read: (c) => (
        duration: OsdMotion.d(c, OsdMotion.countUp),
        curve: OsdMotion.curve(c, Curves.easeOutBack),
        loops: OsdMotion.loopsEnabled(c),
        stagger: <Duration?>[
          for (var i = 0; i < 8; i++) OsdMotion.entranceDelay(c, i),
        ],
      ),
    );

    expect(reduced.durations, (_ms150, _ms100, _ms150));
    expect(reduced.curve, Curves.linear);
    expect(reduced.loops, isFalse);
    expect(reduced.stagger, isNull);
    expect(reduced.press.every((scale) => scale >= .97), isTrue);

    expect(normal.duration, OsdMotion.countUp);
    expect(normal.curve, Curves.easeOutBack);
    expect(normal.loops, isTrue);
    expect(normal.stagger.whereType<Duration>(), hasLength(6));
    expect(normal.stagger.skip(6), everyElement(isNull));
  });
}
