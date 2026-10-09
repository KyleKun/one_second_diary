import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet_title.dart';

import '../support/osd_widget_harness.dart';

const Key _open = Key('open');

Finder get _surface => find.byKey(OsdSheet.surfaceKey);

/// A page with a button that opens a sheet; [results] collects what the
/// sheet returns.
Widget _opener({Widget? child, List<Object?>? results}) => Builder(
  builder: (context) => TextButton(
    key: _open,
    onPressed: () async {
      final result = await showOsdSheet<String>(
        context,
        title: 'Switch profile',
        child:
            child ??
            NeutralButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).pop('done'),
            ),
      );
      results?.add(result);
    },
    child: const Text('open'),
  ),
);

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(_open));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('it returns the value it closes with; the scrim or a drag down '
      'dismisses it with null', (tester) async {
    final results = <Object?>[];
    await pumpOsd(tester, _opener(results: results));

    await _openSheet(tester);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await _openSheet(tester);
    await tester.tapAt(const Offset(195, 100));
    await tester.pumpAndSettle();

    await _openSheet(tester);
    await tester.drag(find.byKey(OsdSheetTitle.titleKey), const Offset(0, 200));
    await tester.pumpAndSettle();

    expect(_surface, findsNothing);
    expect(results, <Object?>['done', null, null]);
  });

  testWidgets('a busy sheet ignores the scrim, drags and back', (tester) async {
    await pumpOsd(
      tester,
      _opener(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => OsdSheetRoute.setBusy(context, busy: true),
            child: const Text('save'),
          ),
        ),
      ),
    );
    await _openSheet(tester);
    await tester.tap(find.text('save'));
    await tester.pump();

    await tester.tapAt(const Offset(195, 100));
    await tester.pumpAndSettle();
    expect(_surface, findsOneWidget);
    await tester.drag(find.byKey(OsdSheetTitle.titleKey), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(_surface, findsOneWidget);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(_surface, findsOneWidget);
  });
}
