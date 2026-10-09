import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tags_sheet.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_input.dart';
import 'package:one_second_diary/shared/widgets/controls/tag_chip.dart';

import '../harness/app_harness.dart';
import '../harness/settle.dart';

/// The tags sheet (`TagsSheet`) as the user drives it, over [AppHarness]:
/// `app.tagsSheet`. The clip editor's tags card, the Diary, the viewer,
/// Memories and Today's Edit sheet open it.
class TagsSheetRobot {
  TagsSheetRobot(this.harness);

  final AppHarness harness;

  WidgetTester get tester => harness.tester;

  Finder get _field => find.descendant(
    of: find.byKey(TagsSheet.fieldKey),
    matching: find.byType(EditableText),
  );

  void expectOpen() => expect(find.byKey(TagsSheet.bodyKey), findsOneWidget);

  void expectClosed() => expect(find.byKey(TagsSheet.bodyKey), findsNothing);

  /// The clip's chips, as the sheet shows them.
  List<String> get chips => <String>[
    for (final Element element in find.byType(TagChip).evaluate())
      if ((element.widget as TagChip).onRemove != null)
        (element.widget as TagChip).label,
  ];

  /// Whether the sheet shows [tag] as one of the clip's tags.
  bool hasChip(String tag) =>
      find.byKey(TagsSheet.chipKey(tag)).evaluate().isNotEmpty;

  /// The error under the field, or null (the hint inside the input is not
  /// one).
  String? get errorText {
    final Finder texts = find.descendant(
      of: find.byKey(TagsSheet.fieldKey),
      matching: find.byType(Text),
    );
    for (final Element element in texts.evaluate()) {
      if (element.findAncestorWidgetOfExactType<OsdTextInput>() != null) {
        continue;
      }
      final Text text = element.widget as Text;
      if (text.data != null && text.data!.isNotEmpty) return text.data;
    }
    return null;
  }

  /// Types [value] into the field and presses Enter: the tag is added, or
  /// the field says why not.
  Future<void> addTag(String value) async {
    await tester.enterText(_field, value);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
  }

  /// Types [value] into the field without submitting.
  Future<void> typeTag(String value) async {
    await tester.enterText(_field, value);
    await tester.pump();
  }

  /// Taps the × of [tag]'s chip.
  Future<void> removeTag(String tag) async {
    await tester.tap(
      find.descendant(
        of: find.byKey(TagsSheet.chipKey(tag)),
        matching: find.byKey(TagChip.removeKey),
      ),
    );
    await settle(tester);
  }

  /// Taps [tag] among the suggestions.
  Future<void> tapSuggestion(String tag) async {
    await tester.tap(find.byKey(TagsSheet.suggestionKey(tag)));
    await settle(tester);
  }

  /// Whether Save can be pressed.
  bool get saveEnabled =>
      tester.widget<PrimaryButton>(find.byKey(TagsSheet.saveKey)).onPressed !=
      null;

  /// Taps Save. Without a save of its own the sheet closes at once; with
  /// one, wait for its effect with `harness.settleUntil`.
  Future<void> tapSave() async {
    await tester.tap(find.byKey(TagsSheet.saveKey));
    await settle(tester);
  }

  /// Closes it with the system back button.
  Future<void> pressBack() async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }
}
