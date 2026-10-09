// The editor's page around the Save: a save pops with the SavedClip the
// opener shows; back is blocked while it runs; back asks before the fresh
// clip is discarded; a failure says nothing in the diary changed and offers
// Report error and Close, or says the phone is full.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clip_editor/presentation/dialogs/discard_clip_dialog.dart';
import 'package:one_second_diary/features/clip_editor/presentation/dialogs/save_failed_dialog.dart';
import 'package:one_second_diary/features/clip_editor/presentation/pages/edit_clip_page.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/save_bar.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_dialog.dart';

import '../../../../shared/harness/settle.dart';
import '../../../../shared/robots/shell_robot.dart';
import '../../support/edit_clip_harness.dart';
import '../../support/fake_clip_saver.dart';

void main() {
  late EditClipHarness editor;

  setUp(() => editor = EditClipHarness());
  tearDown(() => editor.dispose());

  Future<RouteResult<SavedClip>> open(WidgetTester tester) async {
    await editor.open(editorRecording);
    final RouteResult<SavedClip> result = await editor.pushPage(tester);
    await editor.ready(tester);
    return result;
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.byKey(SaveBar.saveKey));
    await settle(tester);
  }

  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  testWidgets('back does nothing while the clip saves; the save pops with '
      'the clip it wrote', (tester) async {
    final RouteResult<SavedClip> result = await open(tester);
    await tapSave(tester);

    await pressBack(tester);

    expect(result.popped, isFalse);
    expect(find.byType(EditClipPage), findsOneWidget);
    expect(find.byType(OsdDialog), findsNothing);

    editor.saver.finish();
    await settle(tester);

    expect(result.value, savedJanuary5);
    expect(find.byType(EditClipPage), findsNothing);
  });

  // The take is fresh (the camera it came from is gone, so back would land
  // on the tab), so back asks even with nothing changed.
  testWidgets('back asks even with nothing changed; "Discard" leaves without '
      'the clip and gives the recording up', (tester) async {
    final RouteResult<SavedClip> result = await open(tester);

    await pressBack(tester);

    expect(result.popped, isFalse);
    expect(find.text(Strings.discardVideoTitle), findsOneWidget);
    await tester.tap(find.byKey(DiscardClipDialog.discardKey));
    await settle(tester);

    expect(result.value, isNull);
    expect(editor.saver.discarded, <Object>[editorRecording]);
  });

  // A full phone is nothing to report.
  testWidgets('a full phone says so, with Close alone; another failure says '
      'nothing in the diary changed, and Report error opens an email with '
      'the logs; the clip stays as it was, to try again', (tester) async {
    final RouteResult<SavedClip> result = await open(tester);
    await editor.cubit.quickCut(1000);
    await tapSave(tester);
    editor.saver.fail(
      const FileSystemException(
        'Cannot write the clip',
        '/scratch/2024-01-05.mp4',
        OSError('No space left on device', 28),
      ),
    );
    await settle(tester);

    expect(find.text(Strings.notEnoughStorage), findsOneWidget);
    expect(find.byKey(SaveFailedDialog.reportKey), findsNothing);
    await tester.tap(find.byKey(SaveFailedDialog.closeKey));
    await settle(tester);
    expect(find.byType(OsdDialog), findsNothing);

    await tapSave(tester);
    editor.saver.fail();
    await settle(tester);

    expect(find.text(Strings.saveVideoErrorBody), findsOneWidget);
    await tester.tap(find.byKey(SaveFailedDialog.reportKey));
    await settle(tester);

    expect(editor.reports.bodies, <String>[Strings.errorMailBody]);
    expect(find.byType(OsdDialog), findsNothing);
    expect(result.popped, isFalse);
    expect(editor.cubit.state.trim?.lengthMs, 1000);
    expect(editor.saver.calls, hasLength(2));
  });
}
