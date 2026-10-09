import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';

import '../harness/app_harness.dart';
import '../harness/settle.dart';

/// The saved snackbar (`SavedClipSnackbar`) as the user sees it, over
/// [AppHarness]: `app.savedSnackbar`. Today and the Diary show it after a
/// save.
class SavedSnackbarRobot {
  SavedSnackbarRobot(this.harness);

  final AppHarness harness;

  WidgetTester get tester => harness.tester;

  Finder get _surface => find.byKey(OsdSnackbar.surfaceKey);

  Finder get _title => find.descendant(
    of: _surface,
    matching: find.text(Strings.videoSavedTitle),
  );

  /// "Video saved" shows, with [subtitle] under it (none when null) and no
  /// action: a save has no Undo.
  void expectShown({required String? subtitle}) {
    expect(_title, findsOneWidget);
    final Iterable<String> lines = tester
        .widgetList<Text>(
          find.descendant(of: _surface, matching: find.byType(Text)),
        )
        .map((Text text) => text.data ?? '');
    expect(lines, <String>[Strings.videoSavedTitle, ?subtitle]);
  }

  /// Lets the snackbar time out and leave.
  Future<void> waitItOut() async {
    await tester.pump(const Duration(seconds: 11));
    await settle(tester);
  }

  void expectGone() => expect(_surface, findsNothing);

  /// Where the snackbar sits on the screen.
  Rect get bounds => tester.getRect(_surface);
}
