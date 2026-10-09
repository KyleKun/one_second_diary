import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_app_bar.dart';

import '../support/osd_widget_harness.dart';

const Key _open = Key('open');
const Key _flow = Key('flow');

void main() {
  // The Create movie flow: a shell route whose pages live in a navigator of
  // their own. Its first page has nothing under it there, so its back
  // arrow must take the whole flow off the root navigator.
  testWidgets('back on the first page of a nested navigator pops the flow '
      'off the root navigator', (WidgetTester tester) async {
    await pumpOsd(
      tester,
      Builder(
        builder: (BuildContext context) => TextButton(
          key: _open,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Navigator(
                key: _flow,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(appBar: OsdAppBar(title: 'Create movie')),
                ),
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.byKey(_open));
    await tester.pumpAndSettle();
    expect(find.byKey(_flow), findsOneWidget);

    await tester.tap(find.byKey(OsdAppBar.leadingKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_flow), findsNothing);
    expect(find.byKey(_open), findsOneWidget);
  });
}
