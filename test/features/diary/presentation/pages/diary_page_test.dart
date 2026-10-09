// The Diary tab's calendar, as the user meets it: the selected day plays
// under the grid on its own, muted so it never stops the user's music, and
// the full-screen viewer takes the player that is already warm. What the
// page shows is the DiaryCubit's state, pinned in diary_cubit_test.dart;
// the performance guards are in diary_page_performance_test.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/diary_mini_player.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../../shared/harness/settle.dart';
import '../../../../support/support.dart';
import '../../support/diary_fixtures.dart';
import '../../support/diary_page_harness.dart';

void main() {
  testWidgets('the selected day plays on its own, muted and mixing with the '
      "user's audio (Q-D8); expand hands that warm player to the viewer, and "
      'the Diary plays the clip again once the viewer closes', (tester) async {
    final DiaryPageHarness diary = DiaryPageHarness()
      ..publish(<LocalDay, int>{sep(2): 1, sep(28): 1});
    await diary.pump(tester);
    await settle(tester);

    final FakePlayerHandle player = diary.media.playerOf(
      diaryClip(ProfileKey.defaultProfile, sep(28)),
    );
    expect(player.value.value.playing, isTrue);
    expect(player.volume, 0);
    expect(player.mixWithOthers, isTrue);

    await tester.tap(find.byKey(DiaryMiniPlayer.expandKey));
    await settle(tester);
    expect(find.byKey(DiaryPageHarness.viewerKey), findsOneWidget);
    expect(diary.viewerArgs!.warmPlayer!.handle, same(player));

    diary.router.pop();
    await settle(tester);
    final FakePlayerHandle again = diary.media.playerOf(
      diaryClip(ProfileKey.defaultProfile, sep(28)),
    );
    expect(again, isNot(same(player)));
    expect(again.value.value.playing, isTrue);
  });
}
