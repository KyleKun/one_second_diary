import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_clip_source.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_source_sheet.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet_title.dart';

import '../harness/app_harness.dart';
import '../harness/settle.dart';

/// The add-source sheet (`AddSourceSheet`: Record / Add video / Add photo)
/// as the user drives it, over [AppHarness]: `app.addSource`. Today's "Add
/// another" opens it through `AddClipFlow.choose`.
class AddSourceSheetRobot {
  AddSourceSheetRobot(this.harness);

  final AppHarness harness;

  WidgetTester get tester => harness.tester;

  void expectShown({required String title}) {
    expect(find.byKey(AddSourceSheet.bodyKey), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(OsdSheetTitle.titleKey)).data, title);
  }

  void expectClosed() =>
      expect(find.byKey(AddSourceSheet.bodyKey), findsNothing);

  /// The rows, top to bottom.
  void expectSources(List<AddClipSource> sources) => expect(<AddClipSource>[
    for (final AddClipSource source in AddClipSource.values)
      if (find.byKey(AddSourceSheet.rowKey(source)).evaluate().isNotEmpty)
        source,
  ], sources);

  /// Taps [source]'s row; the sheet closes and the flow goes on.
  Future<void> tap(AddClipSource source) async {
    await tester.tap(find.byKey(AddSourceSheet.rowKey(source)));
    await settle(tester);
  }

  /// Closes it with the system back button.
  Future<void> pressBack() async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }
}
