import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_bottom_nav.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/shared/widgets/chrome/snackbar_action_pill.dart';
import 'package:one_second_diary/shared/widgets/foundation/snackbar_anchor.dart';
import 'package:one_second_diary/theme/osd_design_system.dart';

import '../support/osd_widget_harness.dart';

const List<OsdNavDestination> _tabs = <OsdNavDestination>[
  OsdNavDestination(icon: OsdIcons.radioButtonChecked, label: 'Today'),
  OsdNavDestination(icon: OsdIcons.autoStories, label: 'Diary'),
  OsdNavDestination(icon: OsdIcons.movie, label: 'Journey'),
  OsdNavDestination(icon: OsdIcons.settings, label: 'Settings'),
];

Finder get _surface => find.byKey(OsdSnackbar.surfaceKey);

/// A shell: a host over a page and the nav, with an optional page anchor.
Widget _shell({Widget? anchorBody}) => OsdSnackbarHost(
  child: Column(
    children: <Widget>[
      Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: anchorBody ?? const SizedBox.shrink(),
        ),
      ),
      OsdBottomNav(destinations: _tabs, index: 0, onSelect: (_) {}),
    ],
  ),
);

/// The shell on the reference frame (390 × 844).
Future<void> _pumpShell(
  WidgetTester tester, {
  Widget? anchorBody,
  bool accessibleNavigation = false,
}) => pumpOsd(
  tester,
  _shell(anchorBody: anchorBody),
  scaffold: false,
  size: kOsdFrame,
  accessibleNavigation: accessibleNavigation,
);

BuildContext _context(WidgetTester tester) =>
    tester.element(find.byType(Column).first);

/// Shows a snackbar and lets its 240 ms entrance finish.
Future<void> _show(
  WidgetTester tester, {
  String title = 'Video saved',
  String? subtitle = 'See you tomorrow',
  String? actionLabel,
  Future<void> Function()? onAction,
  String? actionErrorTitle,
  VoidCallback? onDismissed,
}) async {
  OsdSnackbar.show(
    _context(tester),
    kind: OsdSnackKind.success,
    title: title,
    subtitle: subtitle,
    actionLabel: actionLabel,
    onAction: onAction,
    actionErrorTitle: actionErrorTitle,
    onDismissed: onDismissed,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 240));
}

/// Shows a snackbar with Undo and records each time its onDismissed runs.
Future<List<String>> _showTracked(
  WidgetTester tester, {
  String title = 'Video saved',
  Future<void> Function()? onAction,
}) async {
  final List<String> dismissed = <String>[];
  await _show(
    tester,
    title: title,
    actionLabel: 'Undo',
    onAction: onAction ?? () async {},
    actionErrorTitle: "Couldn't undo",
    onDismissed: () => dismissed.add(title),
  );
  return dismissed;
}

void main() {
  testWidgets('it stays 4 s, 5 s with an action, 10 s with a screen reader; '
      'pressing it pauses the countdown', (tester) async {
    for (final (bool action, bool screenReader, int seconds)
        in <(bool, bool, int)>[
          (false, false, 4),
          (true, false, 5),
          (false, true, 10),
        ]) {
      await _pumpShell(tester, accessibleNavigation: screenReader);
      await _show(
        tester,
        actionLabel: action ? 'Undo' : null,
        onAction: action ? () async {} : null,
      );

      await tester.pump(Duration(milliseconds: seconds * 1000 - 400));
      expect(_surface, findsOneWidget, reason: '$seconds s');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(_surface, findsNothing, reason: '$seconds s');
    }

    await _pumpShell(tester);
    await _show(tester);
    final gesture = await tester.startGesture(tester.getCenter(_surface));
    await tester.pump(const Duration(seconds: 6));
    expect(_surface, findsOneWidget, reason: 'held down');
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 3500));
    expect(_surface, findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(_surface, findsNothing);
  });

  testWidgets('a new snackbar replaces the current one', (tester) async {
    await _pumpShell(tester);
    await _show(tester, title: 'First');
    await _show(tester, title: 'Second');

    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    expect(_surface, findsOneWidget);
  });

  testWidgets('it sits above the highest anchor of the active tab and follows '
      'it when the anchor grows or changes its gap', (tester) async {
    final ValueNotifier<(double, double)> anchor =
        ValueNotifier<(double, double)>((56, 4));
    addTearDown(anchor.dispose);
    await _pumpShell(
      tester,
      anchorBody: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // An anchor in an inactive tab is ignored, however tall.
          const TickerMode(
            enabled: false,
            child: SnackbarAnchor(
              gap: 4,
              child: SizedBox(height: 300, width: 358),
            ),
          ),
          ValueListenableBuilder<(double, double)>(
            valueListenable: anchor,
            builder: (context, value, _) => SnackbarAnchor(
              gap: value.$2,
              child: SizedBox(height: value.$1, width: 358),
            ),
          ),
        ],
      ),
    );
    await _show(tester);
    // nav 78 + anchor 56 + gap 4.
    expect(844 - tester.getRect(_surface).bottom, 138);

    anchor.value = (90, 4);
    await tester.pump();
    await tester.pump();
    expect(844 - tester.getRect(_surface).bottom, 172);

    anchor.value = (90, 12);
    await tester.pump();
    await tester.pump();
    expect(844 - tester.getRect(_surface).bottom, 180);
  });

  testWidgets('Undo: the pill spins while the action runs, then it leaves', (
    tester,
  ) async {
    final undo = Completer<void>();
    var calls = 0;
    await _pumpShell(tester);
    await _show(
      tester,
      actionLabel: 'Undo',
      onAction: () {
        calls++;
        return undo.future;
      },
    );

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.tap(find.byKey(SnackbarActionPill.surfaceKey));
    await tester.pump();
    expect(calls, 1, reason: 'a second tap while it runs is ignored');
    expect(find.byKey(SnackbarActionPill.spinnerKey), findsOneWidget);

    await tester.pump(const Duration(seconds: 8));
    expect(_surface, findsOneWidget, reason: 'the timer waits for the action');

    undo.complete();
    await tester.pumpAndSettle();
    expect(_surface, findsNothing);
  });

  testWidgets('a failed Undo swaps in the error kind with no action', (
    tester,
  ) async {
    await _pumpShell(tester);
    final dismissed = await _showTracked(
      tester,
      onAction: () async => throw StateError('gone'),
    );

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump();

    expect(find.text("Couldn't undo"), findsOneWidget);
    expect(find.byIcon(OsdIcons.error), findsOneWidget);
    expect(find.byType(SnackbarActionPill), findsNothing);
    expect(dismissed, isEmpty, reason: 'the error still shows');

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(_surface, findsNothing);
    expect(dismissed, <String>['Video saved']);
  });

  // The saved clip's Undo is offered while the snackbar shows; when it
  // goes any other way, the save is committed (the clip store purges its
  // backup in onDismissed), so it must run exactly once.
  group('onDismissed', () {
    testWidgets('runs exactly once on a timeout, a swipe, hide(), a '
        'replacement, the app going to the background, or the host going '
        'away', (tester) async {
      await _pumpShell(tester);

      final timedOut = await _showTracked(tester, title: 'timeout');
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));
      expect(timedOut, <String>['timeout']);

      final swiped = await _showTracked(tester, title: 'swiped');
      await tester.drag(_surface, const Offset(0, 60));
      await tester.pumpAndSettle();
      expect(swiped, <String>['swiped']);

      final sideways = await _showTracked(tester, title: 'sideways');
      await tester.drag(_surface, const Offset(160, 0));
      await tester.pumpAndSettle();
      expect(sideways, <String>['sideways']);

      final hidden = await _showTracked(tester, title: 'hidden');
      OsdSnackbar.hide(_context(tester));
      await tester.pumpAndSettle();
      expect(hidden, <String>['hidden']);

      final replaced = await _showTracked(tester, title: 'replaced');
      final next = await _showTracked(tester, title: 'next');
      expect(replaced, <String>['replaced']);

      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(_surface, findsNothing);
      expect(next, <String>['next']);
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      final orphaned = await _showTracked(tester, title: 'orphaned');
      await tester.pumpWidget(const SizedBox.shrink());
      expect(orphaned, <String>['orphaned']);
    });

    testWidgets('never runs after its action succeeded', (tester) async {
      await _pumpShell(tester);
      final dismissed = await _showTracked(tester);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 6));

      expect(_surface, findsNothing);
      expect(dismissed, isEmpty);
    });

    testWidgets('replaced while its action runs, it waits for the action: a '
        'success never runs it, a failure runs it', (tester) async {
      for (final bool succeeds in <bool>[true, false]) {
        final Completer<void> action = Completer<void>();
        await _pumpShell(tester);
        final dismissed = await _showTracked(
          tester,
          onAction: () => action.future,
        );
        await tester.tap(find.text('Undo'));
        await tester.pump();

        await _show(tester, title: 'Next');
        expect(dismissed, isEmpty, reason: 'the action still runs');
        if (succeeds) {
          action.complete();
        } else {
          action.completeError(StateError('gone'));
        }
        await tester.pump();

        expect(
          dismissed,
          succeeds ? isEmpty : <String>['Video saved'],
          reason: succeeds ? 'success' : 'failure',
        );
        OsdSnackbar.hide(_context(tester));
        await tester.pumpAndSettle();
      }
    });
  });

  testWidgets('it announces title and sub-line in a live region', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final announcements = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (message) async {
        final map = message! as Map<Object?, Object?>;
        if (map['type'] == 'announce') {
          final data = map['data']! as Map<Object?, Object?>;
          announcements.add(data['message']! as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            null,
          ),
    );
    await _pumpShell(tester);
    await _show(tester);

    expect(announcements, <String>['Video saved. See you tomorrow']);
    expect(tester.getSemantics(_surface), isSemantics(isLiveRegion: true));
    handle.dispose();
  });
}
