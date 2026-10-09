import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/app/wiring/app_lifecycle_states.dart';

void main() {
  testWidgets('reports each lifecycle change of the app', (
    WidgetTester tester,
  ) async {
    final AppLifecycleStates lifecycle = AppLifecycleStates();
    addTearDown(lifecycle.dispose);
    final List<AppLifecycleState> states = <AppLifecycleState>[];
    lifecycle.states.listen(states.add);

    // Away and back, as the engine reports it.
    const List<AppLifecycleState> away = <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ];
    away.forEach(tester.binding.handleAppLifecycleStateChanged);
    await tester.pump();

    expect(states, away);
  });
}
