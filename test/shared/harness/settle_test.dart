import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'settle.dart';

void main() {
  testWidgets('settle finishes a transition, as pumpAndSettle would, and '
      'returns after its budget on an animation that never ends', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const _Fade(repeat: false));
    await settle(tester);
    expect(_opacity(tester), 1);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(const _Fade(repeat: true, key: Key('endless')));
    final DateTime start = tester.binding.clock.now();
    await settle(tester, budget: const Duration(seconds: 1));
    expect(
      tester.binding.clock.now().difference(start),
      lessThanOrEqualTo(const Duration(milliseconds: 1100)),
    );
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  group('settleUntil', () {
    testWidgets('waiting for real IO beside an endless animation, the fake '
        'clock never runs ahead of the wall clock', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const _Fade(repeat: true));
      final Stopwatch wall = Stopwatch()..start();
      final DateTime start = tester.binding.clock.now();
      bool ioDone = false;
      await tester.runAsync(() async {
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 300),
            () => ioDone = true,
          ),
        );
      });

      await settleUntil(tester, () => ioDone, reason: 'the IO to finish');

      // Fake time follows the wall clock while it waits (however slow the
      // machine), then settle's 2 s budget runs on the endless animation.
      expect(
        tester.binding.clock.now().difference(start),
        lessThanOrEqualTo(wall.elapsed + const Duration(milliseconds: 2100)),
      );
    });

    testWidgets('a condition that needs fake time (a timer) comes true, and '
        'a transition under way ends before it returns', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const _Fade(repeat: false));
      bool held = false;
      Timer(const Duration(milliseconds: 180), () => held = true);

      await settleUntil(tester, () => held, reason: 'the hold to end');

      expect(held, isTrue);
      expect(_opacity(tester), 1);
    });
  });
}

double _opacity(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;

class _Fade extends StatefulWidget {
  const _Fade({required this.repeat, super.key});

  final bool repeat;

  @override
  State<_Fade> createState() => _FadeState();
}

class _FadeState extends State<_Fade> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void initState() {
    super.initState();
    if (widget.repeat) {
      _controller.repeat(reverse: true);
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _controller,
    child: const SizedBox.square(dimension: 10),
  );
}
