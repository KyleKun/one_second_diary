// The transition between clips in the Create movie flow: a choice for
// this movie, None by default; with one, the clips that cannot be cut at a
// keyframe (saved before 2.1) and those not read yet are counted from the
// metadata cache, and the older-clips switch has them re-encoded first.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_keyframes.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/stamped_clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/movies/domain/movie_preset.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../../shared/fakes/clip_index_fixture.dart';
import '../../../../shared/fakes/fake_clip_caches.dart';
import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../shared/fakes/fake_free_space_gateway.dart';
import '../../../../shared/fakes/fake_profiles_repository.dart';
import '../../../../support/support.dart';
import '../../support/pausable_backfill.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

/// A clip saved from 2.1 on: keyframes 10 in and 10 before the end.
const ClipKeyframes _ready = ClipKeyframes(
  frameCount: 45,
  indices: <int>[0, 10, 35],
);

/// A clip saved before: one keyframe, at 0.
const ClipKeyframes _older = ClipKeyframes(frameCount: 45, indices: <int>[0]);

ClipRef _clip(int day) => ClipRef(
  profile: _default,
  relPath: '${LocalDay(2026, 9, day).fileStem}.mp4',
);

void main() {
  late FakeProfilesRepository profiles;
  late FakeClipRepository clips;
  late FakeClipMetadataCache metadata;
  late PausableBackfill backfill;

  /// September 1–5.
  final ClipIndex september = clipIndexOf(_default, <LocalDay>[
    for (int day = 1; day <= 5; day++) LocalDay(2026, 9, day),
  ]);

  setUp(() {
    profiles = FakeProfilesRepository();
    clips = FakeClipRepository()..publish(september);
    metadata = FakeClipMetadataCache();
    backfill = PausableBackfill();
  });

  tearDown(() => clips.close());

  void cache(int day, ClipKeyframes? keyframes, {FileStamp? stamp}) {
    metadata.entries[_clip(day).relPath] = StampedClipMeta(
      stamp: stamp ?? september.stampOf(_clip(day))!,
      meta: ClipMeta(durationMs: 1500, keyframes: keyframes),
    );
  }

  CreateMovieCubit build() {
    final CreateMovieCubit cubit = CreateMovieCubit(
      profiles: profiles,
      clips: clips,
      clock: FakeClock(DateTime(2026, 9, 28, 10)),
      freeSpace: FakeFreeSpaceGateway(),
      backfill: backfill,
      metadata: metadata,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('None by default and nothing counted; a transition counts the older '
      'clips and the ones not read yet (no entry, a stale entry, an entry '
      'without keyframes); the switch and the choice go to the request; '
      'another movie starts at None again', () async {
    cache(1, _ready);
    cache(2, _older);
    cache(3, null); // read before 2.1: no keyframes
    cache(4, _ready, stamp: const FileStamp(sizeBytes: 1, modifiedMs: 1));
    // The 5th has no entry at all.
    final CreateMovieCubit cubit = build()..confirmPreset();

    expect(cubit.state.transition, isNull);
    expect(cubit.state.olderClips, 0);
    expect(cubit.state.unreadClips, 0);

    cubit.setTransition(MovieTransition.fadeBlack);
    expect(cubit.state.olderClips, 1);
    expect(cubit.state.unreadClips, 3);
    expect(cubit.state.upgradeOlderClips, isFalse);

    cubit.setUpgradeOlderClips(upgrade: true);
    await cubit.startMovie(title: 'September 2026');
    expect(cubit.state.request?.transition, MovieTransition.fadeBlack);
    expect(cubit.state.request?.upgradeOlderClips, isTrue);

    // Another transition drops the switch; None drops the counts.
    cubit.setTransition(MovieTransition.crossfade);
    expect(cubit.state.upgradeOlderClips, isFalse);
    expect(cubit.state.olderClips, 1);
    cubit.setTransition(null);
    expect(cubit.state.transition, isNull);
    expect(cubit.state.olderClips, 0);
    expect(cubit.state.unreadClips, 0);

    // Another movie (a new range, a new profile) starts at None.
    cubit
      ..setTransition(MovieTransition.crossfade)
      ..setUpgradeOlderClips(upgrade: true)
      ..choosePreset(MoviePreset.allTime)
      ..confirmPreset();
    expect(cubit.state.transition, isNull);
    expect(cubit.state.upgradeOlderClips, isFalse);
    cubit
      ..setTransition(MovieTransition.crossfade)
      ..chooseProfile(const ProfileKey('Kids'));
    expect(cubit.state.transition, isNull);
  });

  test('the counts follow the backfill: a clip read while the flow is open '
      'leaves the unread count once the backfill is idle', () async {
    cache(1, _ready);
    final CreateMovieCubit cubit = build()
      ..confirmPreset()
      ..setTransition(MovieTransition.crossfade);
    expect(cubit.state.unreadClips, 4);

    backfill.startReading();
    await pumpEventQueue();
    for (int day = 2; day <= 5; day++) {
      cache(day, day == 5 ? _older : _ready);
    }
    backfill.finishReading();
    await pumpEventQueue();

    expect(cubit.state.isReadingClips, isFalse);
    expect(cubit.state.unreadClips, 0);
    expect(cubit.state.olderClips, 1);
    expect(cubit.state.transition, MovieTransition.crossfade);
  });
}
