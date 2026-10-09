// The Today page's own behaviour, beyond its cubit and the app journeys:
// a diary that cannot be read still lets the user record, and Edit opens
// one sheet however often it is tapped.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/today/presentation/widgets/clip_actions_row.dart';
import 'package:one_second_diary/features/today/presentation/widgets/record_button.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_edit_sheet.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_action_row.dart';

import '../../../../shared/harness/settle.dart';
import '../../support/today_page_harness.dart';

void main() {
  testWidgets('a diary that cannot be read still lets the user record', (
    tester,
  ) async {
    final TodayPageHarness today = await TodayPageHarness.pump(
      tester,
      diaries: const <ClipIndex>[],
    );

    today.clips.fail(todayDefault, const StorageException('Gone'));
    await settle(tester);

    expect(
      tester.widget<RecordButton>(find.byType(RecordButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('a second tap on Edit opens one sheet (CL-20), with Record '
      'again, Replace from gallery and Edit subtitles; closing it changes '
      'nothing', (tester) async {
    await TodayPageHarness.pump(
      tester,
      diaries: <ClipIndex>[
        todayDiary(todayDefault, <LocalDay, int>{LocalDay(2026, 9, 28): 1}),
      ],
    );

    await tester.tap(find.byKey(ClipActionsRow.editKey));
    await tester.tap(find.byKey(ClipActionsRow.editKey), warnIfMissed: false);
    await settle(tester);

    expect(find.byKey(TodayEditSheet.bodyKey), findsOneWidget);
    expect(find.text(Strings.todayEditSheetTitle), findsOneWidget);
    for (final TodayEditAction action in TodayEditAction.values) {
      expect(find.byKey(TodayEditSheet.rowKey(action)), findsOneWidget);
    }

    await tester.binding.handlePopRoute();
    await settle(tester);

    expect(find.byKey(TodayEditSheet.bodyKey), findsNothing);
    expect(find.byKey(ClipActionsRow.editKey), findsOneWidget);
  });

  testWidgets('the Edit sheet offers Mute, which asks first (a cancel mutes '
      'nothing); a muted clip reads "Muted" with nothing to tap (D28)', (
    tester,
  ) async {
    final TodayPageHarness today = await TodayPageHarness.pump(
      tester,
      diaries: <ClipIndex>[
        todayDiary(todayDefault, <LocalDay, int>{LocalDay(2026, 9, 28): 1}),
      ],
    );

    await tester.tap(find.byKey(ClipActionsRow.editKey));
    await settle(tester);
    expect(find.text(Strings.clipMute), findsOneWidget);

    await tester.tap(find.byKey(TodayEditSheet.rowKey(TodayEditAction.mute)));
    await settle(tester);
    expect(find.byKey(OsdConfirmDialog.confirmKey), findsOneWidget);
    await tester.tap(find.byKey(OsdConfirmDialog.cancelKey));
    await settle(tester);
    expect(today.audio.mutes, isEmpty);

    await tester.tap(find.byKey(ClipActionsRow.editKey));
    await settle(tester);
    await tester.tap(find.byKey(TodayEditSheet.rowKey(TodayEditAction.mute)));
    await settle(tester);
    await tester.tap(find.byKey(OsdConfirmDialog.confirmKey));
    await settle(tester);
    expect(today.audio.mutes, hasLength(1));
    expect(find.byKey(OsdSnackbar.surfaceKey), findsOneWidget);

    await tester.tap(find.byKey(ClipActionsRow.editKey));
    await settle(tester);
    expect(find.text(Strings.clipMuted), findsOneWidget);
    expect(
      tester
          .widget<OsdActionRow>(
            find.descendant(
              of: find.byKey(TodayEditSheet.rowKey(TodayEditAction.mute)),
              matching: find.byType(OsdActionRow),
            ),
          )
          .onTap,
      isNull,
    );
  });
}
