// The app is portrait; the pages that may turn let the phone turn the screen
// while they are open, and portrait comes back as they close.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/router/landscape_while_open.dart';

import '../../shared/fakes/fake_screen_orientation_gateway.dart';

void main() {
  testWidgets('landscape while the page is open; portrait from the moment it '
      'starts to close', (WidgetTester tester) async {
    final FakeScreenOrientationGateway orientation =
        FakeScreenOrientationGateway();
    final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigator, home: const SizedBox()),
    );

    navigator.currentState!
        .push(
          MaterialPageRoute<void>(
            builder: (BuildContext context) => LandscapeWhileOpen(
              orientation: orientation,
              child: const Text('viewer'),
            ),
          ),
        )
        .ignore();
    await tester.pumpAndSettle();
    expect(orientation.landscapeAllowed, isTrue);

    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('viewer'), findsOneWidget, reason: 'still closing');
    expect(orientation.landscapeAllowed, isFalse);

    await tester.pumpAndSettle();
    expect(orientation.changes, <String>[
      FakeScreenOrientationGateway.landscape,
      FakeScreenOrientationGateway.portrait,
    ]);
  });
}
