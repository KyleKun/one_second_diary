// A private clip is covered (its picture and caption hidden) until the
// user uncovers it: in the viewer, unless it is the clip opened on; in the
// Diary's player, until its tap.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/diary/domain/diary_month.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/viewer_state.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../../shared/fakes/clip_index_fixture.dart';
import '../../../../shared/fakes/fake_profiles_repository.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

ClipRef _clip(int day) => ClipRef(
  profile: _default,
  relPath: '${LocalDay(2026, 9, day).fileStem}.mp4',
);

void main() {
  /// September 1–3, the 2nd and the 3rd private.
  final ClipIndex index = clipIndexOf(_default, <LocalDay>[
    LocalDay(2026, 9, 1),
    LocalDay(2026, 9, 2),
    LocalDay(2026, 9, 3),
  ]).withPrivate(<String>{_clip(2).relPath, _clip(3).relPath});

  test('the viewer covers a private clip stepped to, never the one it '
      'opened on, and not one uncovered since', () {
    final ViewerState state = ViewerState(
      profile: testProfile(),
      clip: _clip(2),
      opened: _clip(2),
      index: index,
    );

    expect(state.isCovered(_clip(2)), isFalse, reason: 'opened on it');
    expect(state.isCovered(_clip(3)), isTrue);
    expect(state.isCovered(_clip(1)), isFalse, reason: 'public');
    expect(
      state.copyWith(revealed: <ClipRef>{_clip(3)}).isCovered(_clip(3)),
      isFalse,
    );
    expect(
      state.copyWith(index: null).isCovered(_clip(3)),
      isFalse,
      reason: 'nothing known yet',
    );
  });

  test("the Diary's player covers a private clip until it is uncovered, "
      'one clip at a time', () {
    final DiaryState state = DiaryState(
      profile: testProfile(),
      today: LocalDay(2026, 9, 28),
      month: const DiaryMonth(2026, 9),
      index: index,
    );

    expect(state.isCovered(_clip(2)), isTrue);
    expect(state.isCovered(_clip(1)), isFalse);
    final DiaryState revealed = state.withRevealed(_clip(2));
    expect(revealed.isCovered(_clip(2)), isFalse);
    expect(revealed.isCovered(_clip(3)), isTrue);
    expect(revealed.withRevealed(_clip(3)).isCovered(_clip(2)), isTrue);
  });
}
