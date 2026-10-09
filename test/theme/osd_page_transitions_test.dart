import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/theme/osd_theme.dart';

import '../shared/widgets/support/osd_widget_harness.dart';

const Key _home = Key('home');
const Key _next = Key('next');

final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

/// A plain app on the OSD theme, reduced motion or not, showing [_home].
Future<void> _pumpApp(WidgetTester tester, {required bool reduced}) async {
  tester.view
    ..physicalSize = kOsdFrame * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: _navigator,
      theme: OsdTheme.dark(reducedMotion: reduced),
      home: const ColoredBox(
        key: _home,
        color: Color(0xFF000000),
        child: SizedBox.expand(),
      ),
    ),
  );
}

void _push() => _navigator.currentState!
    .push(
      MaterialPageRoute<void>(
        builder: (_) => const ColoredBox(
          key: _next,
          color: Color(0xFFFFFFFF),
          child: SizedBox.expand(),
        ),
      ),
    )
    .ignore();

Rect get _screen => Offset.zero & kOsdFrame;

/// The transition of the route showing [_next].
Animation<double> _transition(WidgetTester tester) =>
    ModalRoute.of(tester.element(find.byKey(_next)))!.animation!;

void main() {
  group('under reduced motion (COMPONENTS §4.4)', () {
    testWidgets('a push and a pop are linear crossfades of 150 ms: nothing '
        'slides, zooms or moves underneath', (WidgetTester tester) async {
      await _pumpApp(tester, reduced: true);

      _push();
      await tester.pump();
      for (final (int ms, double opacity) in <(int, double)>[
        (0, 0),
        (75, .5),
        (75, 1),
      ]) {
        await tester.pump(Duration(milliseconds: ms));
        expect(opacityOf(tester, find.byKey(_next)), closeTo(opacity, .01));
        expect(tester.getRect(find.byKey(_next)), _screen);
        expect(tester.getRect(find.byKey(_home)), _screen);
      }
      await tester.pump(const Duration(milliseconds: 1));
      expect(_transition(tester).status, AnimationStatus.completed);

      final Animation<double> transition = _transition(tester);
      _navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      expect(opacityOf(tester, find.byKey(_next)), closeTo(.5, .01));
      expect(tester.getRect(find.byKey(_next)), _screen);
      await tester.pump(const Duration(milliseconds: 76));
      expect(transition.status, AnimationStatus.dismissed);
      await tester.pump();
      expect(find.byKey(_next), findsNothing);
    });

    testWidgets('the iOS back swipe still pops, fading with the finger', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, reduced: true);
      _push();
      await tester.pumpAndSettle();

      final TestGesture swipe = await tester.startGesture(const Offset(5, 400));
      await swipe.moveBy(const Offset(20, 0));
      await swipe.moveBy(const Offset(175, 0));
      await tester.pump();
      expect(opacityOf(tester, find.byKey(_next)), inExclusiveRange(0, 1));
      expect(tester.getRect(find.byKey(_next)), _screen, reason: 'no slide');
      await swipe.moveBy(const Offset(150, 0));
      await swipe.up();
      await tester.pumpAndSettle();
      expect(find.byKey(_next), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
