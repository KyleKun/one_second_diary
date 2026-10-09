import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_frame.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_dialog.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_error_scope.dart';
import 'package:one_second_diary/theme/osd_design_system.dart';

import '../support/osd_widget_harness.dart';

const Key _open = Key('open');

Finder get _surface => find.byKey(OsdDialog.surfaceKey);

Widget _opener({Future<void> Function()? onConfirm, List<bool>? results}) =>
    Builder(
      builder: (context) => TextButton(
        key: _open,
        onPressed: () async {
          final confirmed = await OsdConfirmDialog.show(
            context,
            title: 'Delete this video?',
            body: 'It will be removed from the Default profile.',
            cancelLabel: 'Cancel',
            confirmLabel: 'Delete',
            destructive: true,
            badgeIcon: OsdIcons.delete,
            onConfirm: onConfirm,
          );
          results?.add(confirmed);
        },
        child: const Text('open'),
      ),
    );

Future<void> _openDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(_open));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Cancel and Esc pop false, Delete pops true', (tester) async {
    final results = <bool>[];
    await pumpOsd(tester, _opener(results: results));

    await _openDialog(tester);
    await tester.tap(find.byKey(OsdConfirmDialog.cancelKey));
    await tester.pumpAndSettle();

    await _openDialog(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await _openDialog(tester);
    await tester.tap(find.byKey(OsdConfirmDialog.confirmKey));
    await tester.pumpAndSettle();

    expect(results, <bool>[false, false, true]);
    expect(_surface, findsNothing);
  });

  testWidgets(
    'busy: a spinner in the confirm, both disabled, nothing dismisses; the '
    'confirm is double-tap guarded',
    (tester) async {
      final work = Completer<void>();
      var calls = 0;
      final results = <bool>[];
      await pumpOsd(
        tester,
        _opener(
          results: results,
          onConfirm: () {
            calls++;
            return work.future;
          },
        ),
      );
      await _openDialog(tester);

      await tester.tap(find.byKey(OsdConfirmDialog.confirmKey));
      await tester.pump();
      await tester.tap(
        find.byKey(OsdConfirmDialog.confirmKey),
        warnIfMissed: false,
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(calls, 1);
      expect(find.byKey(OsdButtonFrame.spinnerKey), findsOneWidget);
      expect(
        tester.widget<NeutralButton>(find.byType(NeutralButton)).onPressed,
        isNull,
      );

      await tester.tapAt(const Offset(10, 10));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_surface, findsOneWidget);

      work.complete();
      await tester.pumpAndSettle();
      expect(results, <bool>[true]);
    },
  );

  // The failure reaches the app's log file (the one Report error sends),
  // not only the debug console.
  testWidgets('a failed confirm is reported to the error scope', (
    tester,
  ) async {
    final List<(String, Object)> reported = <(String, Object)>[];
    await tester.pumpWidget(
      OsdErrorScope(
        onError: (message, {required error, required stackTrace}) =>
            reported.add((message, error)),
        child: MaterialApp(
          theme: OsdTheme.dark(),
          home: Scaffold(
            body: _opener(onConfirm: () async => throw StateError('disk full')),
          ),
        ),
      ),
    );
    await _openDialog(tester);

    await tester.tap(find.byKey(OsdConfirmDialog.confirmKey));
    await tester.pumpAndSettle();

    expect(reported, hasLength(1));
    expect(reported.single.$1, contains('"Delete"'));
    expect(reported.single.$2, isA<StateError>());
    // It stays open and idle, so the user can retry or cancel.
    expect(_surface, findsOneWidget);
    expect(find.byKey(OsdButtonFrame.spinnerKey), findsNothing);
    expect(
      tester.widget<NeutralButton>(find.byType(NeutralButton)).onPressed,
      isNotNull,
    );
  });
}
