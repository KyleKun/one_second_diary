// The full-screen viewer, as the user meets it: More opens the clip's
// actions sheet, whose rows run the flows the tiles ran (Mute asks first;
// Delete asks first, deletes for good and moves on); closing hands back
// the clip shown last. Stepping, sound and the delete outcomes are the
// ViewerCubit's, pinned in viewer_cubit_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/audio/mute_action_row.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/clip_actions_sheet.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/viewer_actions.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';

import '../../../../shared/harness/settle.dart';
import '../../support/diary_fixtures.dart';
import '../../support/viewer_page_harness.dart';

LocalDay sep(int day) => LocalDay(2026, 9, day);

ClipRef clipOf(LocalDay day) => diaryClip(ProfileKey.defaultProfile, day);

void main() {
  testWidgets('More opens the clip actions sheet (no Share row: the button '
      'shares); its Mute row asks first, mutes through ClipAudio, and says '
      'Muted next time (owner 2026-10-07)', (WidgetTester tester) async {
    final ViewerPageHarness viewer = ViewerPageHarness()
      ..publish(<LocalDay, int>{sep(2): 1});
    await viewer.open(tester, clipOf(sep(2)));
    expect(find.byKey(OsdSheet.surfaceKey), findsNothing);

    await tester.tap(find.byKey(ViewerActions.moreKey));
    await settle(tester);
    expect(find.byKey(OsdSheet.surfaceKey), findsOneWidget);
    expect(find.byKey(ClipActionsSheet.shareKey), findsNothing);
    expect(find.byKey(ClipActionsSheet.editAgainKey), findsNothing);
    expect(find.byKey(ClipActionsSheet.processImportKey), findsNothing);

    await tester.tap(find.byKey(ViewerActions.muteKey));
    await settle(tester);
    expect(find.byKey(OsdSheet.surfaceKey), findsNothing);
    expect(find.byKey(OsdConfirmDialog.confirmKey), findsOneWidget);
    expect(viewer.audio.mutes, isEmpty);

    await tester.tap(find.byKey(OsdConfirmDialog.confirmKey));
    await settle(tester);
    expect(viewer.audio.mutes, <ClipRef>[clipOf(sep(2))]);

    await tester.tap(find.byKey(ViewerActions.moreKey));
    await settle(tester);
    expect(
      tester.widget<MuteActionRow>(find.byType(MuteActionRow)).isMuted,
      isTrue,
    );
  });

  testWidgets('More, then Delete asks first, deletes for good, says so and '
      'shows the next clip (Q-D9); back closes with the clip shown last '
      '(CL-37)', (tester) async {
    final ViewerPageHarness viewer = ViewerPageHarness()
      ..publish(<LocalDay, int>{sep(2): 1, sep(9): 1});
    await viewer.open(tester, clipOf(sep(2)));

    await tester.tap(find.byKey(ViewerActions.moreKey));
    await settle(tester);
    await tester.tap(find.byKey(ViewerActions.deleteKey));
    await settle(tester);
    expect(find.byKey(OsdConfirmDialog.confirmKey), findsOneWidget);
    expect(viewer.store.deleted, isEmpty);

    await tester.tap(find.byKey(OsdConfirmDialog.confirmKey));
    await settle(tester);
    expect(viewer.store.deleted, <ClipRef>[clipOf(sep(2))]);
    expect(find.byKey(OsdSnackbar.surfaceKey), findsOneWidget);
    expect(viewer.cubit.state.clip, clipOf(sep(9)));
    expect(viewer.closed, isFalse);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(viewer.closed, isTrue);
    expect(viewer.result, clipOf(sep(9)));
  });
}
