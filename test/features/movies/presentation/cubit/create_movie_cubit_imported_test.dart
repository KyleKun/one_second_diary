// The movie confirmation counts the clips the cache says are converted
// first (foreign, legacy or copied in: not the profile's format) with their
// length, for "12 videos will be converted first (about 4 min)", and the
// movie's length for "12 min · 365 clips". A clip not read yet counts for neither.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/stamped_clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
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

/// A clip the app saved in the legacy format: joined as it is.
const ClipMeta _own = ClipMeta(
  durationMs: 2000,
  isOsdV15: true,
  hasAudio: true,
  hasSubtitleStream: false,
  width: 1920,
  height: 1080,
  codec: 'h264',
  schema: ClipSchema.v15,
);

/// An iPhone export dropped into the folder: converted first.
const ClipMeta _foreign = ClipMeta(
  durationMs: 30000,
  isOsdV15: false,
  hasAudio: true,
  hasSubtitleStream: false,
  width: 1280,
  height: 720,
  codec: 'hevc',
  schema: ClipSchema.other,
);

ClipRef _clip(int day) => ClipRef(
  profile: _default,
  relPath: '${LocalDay(2026, 9, day).fileStem}.mp4',
);

void main() {
  late FakeClipRepository clips;
  late FakeClipMetadataCache metadata;
  late PausableBackfill backfill;

  /// September 1–4.
  final ClipIndex september = clipIndexOf(_default, <LocalDay>[
    for (int day = 1; day <= 4; day++) LocalDay(2026, 9, day),
  ]);

  setUp(() {
    clips = FakeClipRepository()..publish(september);
    metadata = FakeClipMetadataCache();
    backfill = PausableBackfill();
  });

  tearDown(() => clips.close());

  void cache(int day, ClipMeta meta) {
    metadata.entries[_clip(day).relPath] = StampedClipMeta(
      stamp: september.stampOf(_clip(day))!,
      meta: meta,
    );
  }

  CreateMovieCubit build() {
    final CreateMovieCubit cubit = CreateMovieCubit(
      profiles: FakeProfilesRepository(),
      clips: clips,
      clock: FakeClock(DateTime(2026, 9, 28, 10)),
      freeSpace: FakeFreeSpaceGateway(),
      backfill: backfill,
      metadata: metadata,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('two own clips, one foreign and one not read: one video will be '
      'converted (30 s); the length counts the unread clip as the average '
      'read one; nothing counted before the draft', () {
    cache(1, _own);
    cache(2, _own);
    cache(3, _foreign);
    // The 4th has no entry.
    final CreateMovieCubit cubit = build();

    expect(cubit.state.foreignClips, 0);
    expect(cubit.state.draftDurationMs, isNull);

    cubit.confirmPreset();

    expect(cubit.state.foreignClips, 1);
    expect(cubit.state.foreignDurationMs, 30000);
    // (2 000 + 2 000 + 30 000) / 3 read × 4 clips.
    expect(cubit.state.draftDurationMs, 45333);
  });

  test('a draft nobody has read has no length and nothing to convert', () {
    final CreateMovieCubit cubit = build()..confirmPreset();

    expect(cubit.state.foreignClips, 0);
    expect(cubit.state.foreignDurationMs, 0);
    expect(cubit.state.draftDurationMs, isNull);
  });
}
