// EditClipCubit and tags: a replace opens on the replaced clip's tags, the
// tags card's Save changes the draft, and the render request carries them.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_render_plan.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clips/data/saved_places.dart';
import 'package:one_second_diary/features/clips/domain/clip_ownership.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_save_mode.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../../../shared/fakes/clip_index_fixture.dart';
import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../support/support.dart';
import '../../support/fake_clip_saver.dart';
import '../../support/fake_location_service.dart';
import '../../support/fake_recent_places.dart';

void main() {
  final LocalDay day = LocalDay(2024, 1, 5);
  const VideoSource recording = VideoSource(
    path: '/tmp/REC.mp4',
    ownership: ClipOwnership.cameraTemp,
  );
  final ClipRef january5 = ClipRef(
    profile: ProfileKey.defaultProfile,
    relPath: '2024-01-05.mp4',
  );

  late FakeClipSaver saver;

  Future<EditClipCubit> editorOf({
    required ClipSaveMode mode,
    required FakeClipRepository clips,
  }) async {
    saver = FakeClipSaver();
    final EditClipCubit cubit = EditClipCubit(
      args: EditClipArgs(
        source: recording,
        day: day,
        profile: ProfileKey.defaultProfile,
        mode: mode,
      ),
      settings: SettingsRepository(prefs: await openLegacyPrefs(legacyPrefs())),
      clips: clips,
      locations: FakeLocationService(),
      savedPlaces: SavedPlaces(
        prefs: await openLegacyPrefs(legacyPrefs()),
        logger: memoryLogger(MemoryLogSink()),
      ),
      metadata: FakeRecentPlaces(),
      saver: saver,
      logger: memoryLogger(MemoryLogSink()),
    );
    addTearDown(cubit.close);
    cubit.sourceLoaded(const Duration(seconds: 4), aspectRatio: 16 / 9);
    return cubit;
  }

  test('a new clip opens without tags; a replace opens on the replaced '
      'clip\'s tags as the library knows them', () async {
    final FakeClipRepository clips = FakeClipRepository()
      ..publish(
        clipIndexOf(ProfileKey.defaultProfile, <LocalDay>[
          day,
        ]).withTags('2024-01-05.mp4', <String>['trip', 'kids']),
      );

    final EditClipCubit added = await editorOf(
      mode: const AddClip(),
      clips: clips,
    );
    expect(added.state.draft.tags, isEmpty);

    final EditClipCubit replaced = await editorOf(
      mode: ReplaceClip(january5),
      clips: clips,
    );
    expect(replaced.state.draft.tags, <String>['kids', 'trip']);
  });

  test('the tags sheet\'s Save changes the draft, and the render request '
      'carries the tags normalised', () async {
    final EditClipCubit cubit = await editorOf(
      mode: const AddClip(),
      clips: FakeClipRepository(),
    );

    cubit.tagsChanged(<String>['Trip', 'bread', 'trip']);
    expect(cubit.state.draft.tags, <String>['Trip', 'bread', 'trip']);

    await cubit.save(
      const ClipRenderLook(
        stampText: '2024-01-05',
        format: ClipFormat.legacy(VideoOrientation.landscape),
      ),
    );

    expect(saver.calls.single.request.tags, <String>['bread', 'Trip']);
  });

  test('"Save without sound" is off until switched, and the render request '
      'carries it (D28)', () async {
    final EditClipCubit cubit = await editorOf(
      mode: const AddClip(),
      clips: FakeClipRepository(),
    );
    expect(cubit.state.draft.mute, isFalse);

    cubit.muteChanged(mute: true);
    expect(cubit.state.draft.mute, isTrue);

    await cubit.save(
      const ClipRenderLook(
        stampText: '2024-01-05',
        format: ClipFormat.legacy(VideoOrientation.landscape),
      ),
    );

    expect(saver.calls.single.request.mute, isTrue);
  });
}
