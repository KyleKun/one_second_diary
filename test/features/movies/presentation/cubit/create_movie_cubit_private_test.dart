// Private clips in the Create movie flow: left out of every range until the
// confirmation's switch includes them; picked by hand as any other clip.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../../shared/fakes/clip_index_fixture.dart';
import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../shared/fakes/fake_free_space_gateway.dart';
import '../../../../shared/fakes/fake_profiles_repository.dart';
import '../../../../support/support.dart';
import '../../support/pausable_backfill.dart';

const ProfileKey _default = ProfileKey.defaultProfile;
const ProfileKey _kids = ProfileKey('Kids');

ClipRef _clip(int day) => ClipRef(
  profile: _default,
  relPath: '${LocalDay(2026, 9, day).fileStem}.mp4',
);

void main() {
  late FakeProfilesRepository profiles;
  late FakeClipRepository clips;
  late FakeFreeSpaceGateway freeSpace;

  /// September 1–5, the 2nd and the 5th private.
  final ClipIndex september = clipIndexOf(_default, <LocalDay>[
    for (int day = 1; day <= 5; day++) LocalDay(2026, 9, day),
  ]).withPrivate(<String>{_clip(2).relPath, _clip(5).relPath});

  setUp(() {
    freeSpace = FakeFreeSpaceGateway();
    profiles = FakeProfilesRepository();
    clips = FakeClipRepository()..publish(september);
  });

  tearDown(() => clips.close());

  CreateMovieCubit build() {
    final CreateMovieCubit cubit = CreateMovieCubit(
      profiles: profiles,
      clips: clips,
      clock: FakeClock(DateTime(2026, 9, 28, 10)),
      freeSpace: freeSpace,
      backfill: PausableBackfill(),
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test(
    'every range counts without the private clips; the switch includes '
    'them, the draft and the request say so; a new profile starts without',
    () async {
      final CreateMovieCubit cubit = build();

      expect(cubit.state.presetClips, 3);
      expect(cubit.state.isOpen(2026, 9), isTrue);
      cubit.confirmPreset();
      expect(cubit.state.draft?.clips, hasLength(3));
      expect(cubit.state.draft?.privateLeftOut, 2);

      cubit.setIncludePrivate(include: true);

      expect(cubit.state.presetClips, 5);
      expect(cubit.state.draft?.clips, hasLength(5));
      expect(cubit.state.draft?.privateIncluded, 2);
      await cubit.startMovie(title: 'September 2026');
      expect(cubit.state.request?.includePrivate, isTrue);

      // A clip marked private meanwhile leaves a range that excludes them.
      cubit.setIncludePrivate(include: false);
      clips.privacyKnown(_clip(1).relPath, private: true);
      await pumpEventQueue();
      expect(cubit.state.presetClips, 2);
      expect(cubit.state.draft?.privateLeftOut, 3);

      cubit.setIncludePrivate(include: true);
      cubit.chooseProfile(_kids);
      expect(cubit.state.includePrivate, isFalse);
    },
  );

  test('Select all picks the clips that are not private; a private clip '
      'picked by hand stays picked and counts for the movie; Deselect all '
      'unpicks every clip', () {
    final CreateMovieCubit cubit = build()..togglePick(_clip(5));

    cubit.toggleAll();

    expect(cubit.state.allPicked, isTrue);
    expect(cubit.state.picks.clips, <ClipRef>{
      _clip(1),
      _clip(3),
      _clip(4),
      _clip(5),
    });
    cubit.confirmPicks();
    expect(cubit.state.draft?.clips, hasLength(4));
    expect(cubit.state.draft?.privateIncluded, 1);
    expect(cubit.state.draft?.privateInRange, 0);

    cubit.toggleAll();
    expect(cubit.state.picks.count, 0);
    expect(cubit.state.allPicked, isFalse);
  });
}
