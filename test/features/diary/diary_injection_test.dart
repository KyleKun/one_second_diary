import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/di/injection_container.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/diary/presentation/diary_opener.dart';

import '../../shared/harness/test_container.dart';

void main() {
  late TestContainer container;

  setUp(() async {
    container = await TestContainer.create();
  });

  tearDown(() => container.dispose());

  test('each Diary tab gets its own cubit, on this month; J1 asks it '
      "for this month's calendar through the one opener of the app", () async {
    final DiaryCubit diary = sl<DiaryCubit>();
    final DiaryCubit other = sl<DiaryCubit>();
    expect(other, isNot(same(diary)));
    expect(diary.state.month, diary.state.thisMonth);
    expect(diary.state.view, DiaryView.calendar);

    diary
      ..showPreviousMonth()
      ..showView(DiaryView.memories);
    sl<DiaryOpener>().showThisMonthsCalendar();
    await pumpEventQueue();

    expect(sl<DiaryOpener>(), same(sl<DiaryOpener>()));
    expect(diary.state.view, DiaryView.calendar);
    expect(diary.state.month, diary.state.thisMonth);
    await diary.close();
    await other.close();
  });
}
