import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_text_scale_clamp.dart';

/// Pumps [child] under a system text scale of [factor] and returns the
/// scaler a descendant of [child] sees.
Future<TextScaler> _scalerUnder(
  WidgetTester tester,
  double factor,
  Widget Function(Widget probe) wrap,
) async {
  late TextScaler seen;
  final probe = Builder(
    builder: (context) {
      seen = MediaQuery.textScalerOf(context);
      return const SizedBox();
    },
  );
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(factor)),
      child: wrap(probe),
    ),
  );
  return seen;
}

void main() {
  testWidgets('the root clamp stops at 2.0, and a role caps a larger scale '
      'and passes a smaller one', (tester) async {
    final cases = <(OsdTextScaleRole, double, double, double)>[
      // role, system scale, font size, scaled size
      (OsdTextScaleRole.root, 3.0, 15, 30),
      (OsdTextScaleRole.navLabel, 2.0, 12, 12 * 1.2),
      (OsdTextScaleRole.display, 1.1, 30, 33),
    ];
    for (final (role, factor, size, expected) in cases) {
      final scaler = await _scalerUnder(
        tester,
        factor,
        (probe) => OsdTextScaleClamp(role: role, child: probe),
      );
      expect(scaler.scale(size), closeTo(expected, 1e-9), reason: '$role');
    }
  });

  testWidgets('stamps, video subtitles and artwork are never scaled', (
    tester,
  ) async {
    final clamped = await _scalerUnder(
      tester,
      2.0,
      (probe) =>
          OsdTextScaleClamp(role: OsdTextScaleRole.unscaled, child: probe),
    );
    late TextScaler read;
    await _scalerUnder(
      tester,
      1.8,
      (probe) => Builder(
        builder: (context) {
          read = OsdTextScale.scalerFor(context, OsdTextScaleRole.unscaled);
          return probe;
        },
      ),
    );

    expect(clamped, TextScaler.noScaling);
    expect(read, TextScaler.noScaling);
  });
}
