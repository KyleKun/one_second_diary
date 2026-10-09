import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/presentation/subtitles/subtitle_sheet.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_area.dart';

import '../harness/app_harness.dart';
import '../harness/settle.dart';

/// The subtitles sheet (`SubtitleSheet`) as the user drives it, over
/// [AppHarness]: `app.subtitleSheet`. The clip editor's Subtitles tab, the
/// Diary and the viewer and Today's Edit sheet open it.
class SubtitleSheetRobot {
  SubtitleSheetRobot(this.harness);

  final AppHarness harness;

  WidgetTester get tester => harness.tester;

  Finder get _field => find.descendant(
    of: find.byKey(SubtitleSheet.bodyKey),
    matching: find.byType(EditableText),
  );

  String get text => tester.widget<EditableText>(_field).controller.text;

  void expectOpen() =>
      expect(find.byKey(SubtitleSheet.bodyKey), findsOneWidget);

  void expectClosed() =>
      expect(find.byKey(SubtitleSheet.bodyKey), findsNothing);

  void expectText(String expected) => expect(text, expected);

  /// Types [value] over the text.
  Future<void> enterText(String value) async {
    await tester.enterText(_field, value);
    await tester.pump();
  }

  /// Whether Reset can be pressed.
  bool get resetEnabled =>
      tester
          .widget<NeutralButton>(find.byKey(SubtitleSheet.resetKey))
          .onPressed !=
      null;

  Future<void> tapReset() async {
    await tester.tap(find.byKey(SubtitleSheet.resetKey));
    await settle(tester);
  }

  /// Taps Save. Without a save of its own the sheet closes at once; with
  /// one, wait for its effect with `harness.settleUntil`.
  Future<void> tapSave() async {
    await tester.tap(find.byKey(SubtitleSheet.saveKey));
    await settle(tester);
  }

  /// Closes it with the system back button.
  Future<void> pressBack() async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  /// The field's box, for layout checks.
  Rect get fieldRect => tester.getRect(find.byKey(OsdTextArea.boxKey));
}
