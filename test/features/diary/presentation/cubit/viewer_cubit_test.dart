// The viewer's state: the clip shown, stepping to the previous or next
// recorded clip (a day's own clips first, missed days skipped, months
// crossed), the sound (the user's last choice), and deleting the clip shown
// (the viewer moves on, or closes when none is left).

import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/diary/data/clip_captions.dart';
import 'package:one_second_diary/features/diary/data/clip_filtering.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/viewer_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/viewer_state.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../shared/fakes/fake_profiles_repository.dart';
import '../../../../support/support.dart';
import '../../support/diary_fixtures.dart';
import '../../support/fake_clip_store.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

ClipRef clipOf(LocalDay day, {int ordinal = 1}) =>
    diaryClip(_default, day, ordinal: ordinal);

LocalDay sep(int day) => LocalDay(2026, 9, day);

void main() {
  late FakeClipRepository clips;
  late FakeProfilesRepository profiles;
  late FakeClipStore store;
  late FakeShareGateway share;
  late SettingsRepository settings;
  late ClipMetadataCache metadata;
  final List<ViewerCubit> made = <ViewerCubit>[];

  setUp(() async {
    clips = FakeClipRepository();
    profiles = FakeProfilesRepository();
    store = FakeClipStore(clips);
    share = FakeShareGateway();
    settings = SettingsRepository(prefs: await openLegacyPrefs(legacyPrefs()));
    metadata = ClipMetadataCache(
      paths: AppPaths.forTest(Directory('/osd')),
      logger: memoryLogger(MemoryLogSink()),
    );
  });

  tearDown(() async {
    for (final ViewerCubit cubit in made) {
      await cubit.close();
    }
    made.clear();
    await clips.close();
    await profiles.close();
  });

  ViewerCubit viewer(ClipRef clip) {
    final ViewerCubit cubit = ViewerCubit(
      args: ViewerArgs(clip: clip),
      profiles: profiles,
      clips: clips,
      captions: ClipCaptions(clips: clips, metadata: metadata),
      filtering: ClipFiltering(metadata: metadata),
      store: store,
      share: share,
      paths: AppPaths.forTest(Directory('/osd')),
      settings: settings,
      logger: memoryLogger(MemoryLogSink()),
    );
    made.add(cubit);
    return cubit;
  }

  group('stepping (Q-D4)', () {
    test('goes through a day\'s clips first ("2 of 3"), then skips to the '
        'closest recorded days, across months', () {
      clips.publish(
        diaryIndex(_default, <LocalDay, int>{
          LocalDay(2026, 8, 31): 1,
          sep(2): 3,
          sep(9): 1,
        }),
      );
      final ViewerCubit cubit = viewer(clipOf(sep(2)));

      expect(cubit.state.previous, clipOf(LocalDay(2026, 8, 31)));
      expect(cubit.state.step, ViewerStep.none);
      expect(cubit.state.dayPosition, (position: 1, count: 3));
      cubit.showNext();
      expect(cubit.state.clip, clipOf(sep(2), ordinal: 2));
      expect(cubit.state.dayPosition, (position: 2, count: 3));
      expect(cubit.state.step, ViewerStep.forward);
      cubit
        ..showNext()
        ..showNext();
      expect(cubit.state.clip, clipOf(sep(9)));
      expect(cubit.state.next, isNull);
      cubit.showNext();
      expect(cubit.state.clip, clipOf(sep(9)));

      for (int i = 0; i < 4; i++) {
        cubit.showPrevious();
      }
      expect(cubit.state.clip, clipOf(LocalDay(2026, 8, 31)));
      expect(cubit.state.step, ViewerStep.backward);
      expect(cubit.state.previous, isNull);
      expect(cubit.state.moved, isTrue);
    });
  });

  group('sound', () {
    test('plays with sound as the user last chose (v1.7 default: on); the '
        'toggle mutes, and the Diary hears it', () async {
      clips.publish(diaryIndex(_default, <LocalDay, int>{sep(2): 1}));
      final ViewerCubit cubit = viewer(clipOf(sep(2)));
      expect(cubit.state.muted, isFalse);

      await cubit.toggleSound();

      expect(cubit.state.muted, isTrue);
      expect(settings.calendarAutoSound.value, isFalse);
    });
  });

  test('shares the clip\'s file as it is stored (Q-D10)', () async {
    clips.publish(diaryIndex(_default, <LocalDay, int>{sep(2): 1}));

    await viewer(clipOf(sep(2))).share(origin: const Rect.fromLTWH(1, 2, 3, 4));

    expect(share.sharedFiles.single, <String>[
      AppPaths.forTest(
        Directory('/osd'),
      ).absoluteFromVideos(clipOf(sep(2)).relPath),
    ]);
    expect(share.lastOrigin, const Rect.fromLTWH(1, 2, 3, 4));
  });

  group('deleting the clip shown (D5 from D4, §5.8)', () {
    test('moves on to the next recorded clip and says so, back to the '
        'previous one after the last, and closes when none is left', () async {
      clips.publish(
        diaryIndex(_default, <LocalDay, int>{sep(2): 1, sep(9): 1, sep(12): 1}),
      );
      final ViewerCubit cubit = viewer(clipOf(sep(9)));

      await cubit.deleteShown();
      await pumpEventQueue();
      expect(store.deleted, <ClipRef>[clipOf(sep(9))]);
      expect(cubit.state.deletion, ClipDeletion.deleted);
      expect(cubit.state.deletedClip, clipOf(sep(9)));
      expect(cubit.state.clip, clipOf(sep(12)));
      expect(cubit.state.closed, isFalse);

      await cubit.deleteShown();
      await pumpEventQueue();
      expect(cubit.state.clip, clipOf(sep(2)));
      expect(cubit.state.closed, isFalse);

      await cubit.deleteShown();
      await pumpEventQueue();
      expect(cubit.state.closed, isTrue);
    });

    test('a refusal keeps the clip, and says so every time', () async {
      clips.publish(diaryIndex(_default, <LocalDay, int>{sep(2): 1}));
      store.refuse = true;
      final ViewerCubit cubit = viewer(clipOf(sep(2)));
      final List<ClipDeletion> seen = <ClipDeletion>[];
      cubit.stream.listen((ViewerState state) => seen.add(state.deletion));

      await cubit.deleteShown();
      await cubit.deleteShown();
      await pumpEventQueue();

      expect(seen, <ClipDeletion>[
        ClipDeletion.deleting,
        ClipDeletion.failed,
        ClipDeletion.deleting,
        ClipDeletion.failed,
      ]);
      expect(cubit.state.clip, clipOf(sep(2)));
    });
  });

  test('a clip deleted elsewhere moves the viewer on', () async {
    clips.publish(diaryIndex(_default, <LocalDay, int>{sep(2): 1, sep(9): 1}));
    final ViewerCubit cubit = viewer(clipOf(sep(2)));

    clips.publish(diaryIndex(_default, <LocalDay, int>{sep(9): 1}));
    await pumpEventQueue();

    expect(cubit.state.clip, clipOf(sep(9)));
  });
}
