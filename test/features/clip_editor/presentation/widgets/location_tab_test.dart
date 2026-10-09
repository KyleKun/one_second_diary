// The Location tab: the line that says the place is looked up through the
// phone's location service, and "Show my location" finding the place in the
// app language.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/location_tab.dart';

import '../../../../theme/support/load_osd_fonts.dart';
import '../../support/edit_clip_harness.dart';
import '../../support/fake_location_service.dart';

void main() {
  late EditClipHarness editor;

  setUpAll(loadOsdFonts);
  setUp(() => editor = EditClipHarness());
  tearDown(() => editor.dispose());

  testWidgets('discloses that the place is looked up through the phone\'s '
      'location service; a tap on the card finds the place in the app '
      'language', (tester) async {
    await editor.open(editorRecording);
    await editor.pump(tester, const LocationTab());

    expect(find.text(Strings.saveVideoLocationDisclosure), findsOneWidget);
    expect(find.text(Strings.saveVideoLocationOffValue), findsOneWidget);

    await tester.tap(find.byKey(LocationTab.geotagKey));
    await tester.pump();
    expect(find.text(Strings.saveVideoLocationFinding), findsOneWidget);

    editor.locations.answerNow(tokyo);
    await tester.pump();

    expect(find.text('Tokyo, Japan'), findsOneWidget);
    expect(editor.locations.locales, <String>['en']);
  });
}
