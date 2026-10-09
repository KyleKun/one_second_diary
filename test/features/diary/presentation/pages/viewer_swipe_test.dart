// The viewer's swipe, as the user meets it: a swipe sideways steps through
// a day's clips, then to the neighbouring days (the cubit's order, pinned
// in viewer_cubit_test.dart); at the ends it does nothing; a drag down
// still closes the viewer, beside it.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/viewer_video.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../../shared/harness/settle.dart';
import '../../support/diary_fixtures.dart';
import '../../support/viewer_page_harness.dart';

LocalDay sep(int day) => LocalDay(2026, 9, day);

ClipRef clipOf(LocalDay day, {int ordinal = 1}) =>
    diaryClip(ProfileKey.defaultProfile, day, ordinal: ordinal);

/// A flick on the video, [dx] px sideways.
Future<void> flick(WidgetTester tester, double dx) async {
  await tester.fling(find.byType(ViewerVideo), Offset(dx, 0), 1000);
  await settle(tester);
}

void main() {
  testWidgets('a swipe left steps through the day, then to the next day, '
      'and does nothing past the last; a swipe right goes back the same '
      'way, and does nothing before the first', (tester) async {
    final ViewerPageHarness viewer = ViewerPageHarness()
      ..publish(<LocalDay, int>{sep(2): 2, sep(9): 1});
    await viewer.open(tester, clipOf(sep(2)));

    await flick(tester, -200);
    expect(viewer.cubit.state.clip, clipOf(sep(2), ordinal: 2));
    await flick(tester, -200);
    expect(viewer.cubit.state.clip, clipOf(sep(9)));

    // The last clip: a swipe on gives a little and stays.
    await flick(tester, -200);
    expect(viewer.cubit.state.clip, clipOf(sep(9)));
    expect(viewer.closed, isFalse);

    await flick(tester, 200);
    expect(viewer.cubit.state.clip, clipOf(sep(2), ordinal: 2));
    await flick(tester, 200);
    expect(viewer.cubit.state.clip, clipOf(sep(2)));

    // The first clip: a swipe back stays.
    await flick(tester, 200);
    expect(viewer.cubit.state.clip, clipOf(sep(2)));
    expect(viewer.closed, isFalse);
  });

  testWidgets('a slow drag past the distance steps too; a drag down still '
      'closes the viewer with the clip shown', (tester) async {
    final ViewerPageHarness viewer = ViewerPageHarness()
      ..publish(<LocalDay, int>{sep(2): 1, sep(9): 1});
    await viewer.open(tester, clipOf(sep(2)));

    await tester.drag(find.byType(ViewerVideo), const Offset(-160, 0));
    await settle(tester);
    expect(viewer.cubit.state.clip, clipOf(sep(9)));
    expect(viewer.closed, isFalse);

    await tester.drag(find.byType(ViewerVideo), const Offset(0, 300));
    await settle(tester);
    expect(viewer.closed, isTrue);
    expect(viewer.result, clipOf(sep(9)));
  });
}
