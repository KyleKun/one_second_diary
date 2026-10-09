// The viewer opened from a filtered Diary steps through the clips the
// filter keeps only, and moves on to a kept clip when the one shown goes.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/diary/data/clip_captions.dart';
import 'package:one_second_diary/features/diary/data/clip_filtering.dart';
import 'package:one_second_diary/features/diary/domain/clip_filter.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/viewer_cubit.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../shared/fakes/fake_profiles_repository.dart';
import '../../../../support/support.dart';
import '../../../journey/support/journey_fakes.dart';
import '../../support/diary_fixtures.dart';
import '../../support/fake_clip_store.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

ClipRef clipOf(LocalDay day, {int ordinal = 1}) =>
    diaryClip(_default, day, ordinal: ordinal);

LocalDay sep(int day) => LocalDay(2026, 9, day);

/// September 2, 5 (two clips), 9 and 28: "trip" on the 2nd, the 5th's
/// second clip and the 28th.
ClipIndex septemberIndex() =>
    diaryIndex(_default, <LocalDay, int>{
      sep(2): 1,
      sep(5): 2,
      sep(9): 1,
      sep(28): 1,
    }).withClipTags(<String, List<String>>{
      clipOf(sep(2)).relPath: <String>['trip'],
      clipOf(sep(5), ordinal: 2).relPath: <String>['trip'],
      clipOf(sep(28)).relPath: <String>['trip'],
    });

final ClipFilter trips = ClipFilter(tags: TagFilter(anyOf: <String>{'trip'}));

void main() {
  late FakeClipRepository clips;
  late FakeProfilesRepository profiles;
  late FakeClipStore store;
  late FakeShareGateway share;
  late SettingsRepository settings;
  late MapClipMetadataCache metadata;
  final List<ViewerCubit> made = <ViewerCubit>[];

  setUp(() async {
    clips = FakeClipRepository();
    profiles = FakeProfilesRepository();
    store = FakeClipStore(clips);
    share = FakeShareGateway();
    settings = SettingsRepository(prefs: await openLegacyPrefs(legacyPrefs()));
    metadata = MapClipMetadataCache();
  });

  tearDown(() async {
    for (final ViewerCubit cubit in made) {
      await cubit.close();
    }
    made.clear();
    await clips.close();
    await profiles.close();
  });

  ViewerCubit viewer(ClipRef clip, {required ClipFilter filter}) {
    final ViewerCubit cubit = ViewerCubit(
      args: ViewerArgs(clip: clip, filter: filter),
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

  test('Previous and Next skip the clips the filter leaves out; "N of M" '
      'counts the kept clips of the day', () {
    clips.publish(septemberIndex());
    final ViewerCubit cubit = viewer(clipOf(sep(2)), filter: trips);

    expect(cubit.state.previous, isNull);
    cubit.showNext();
    expect(cubit.state.clip, clipOf(sep(5), ordinal: 2));
    expect(cubit.state.dayPosition, (position: 1, count: 1));
    cubit.showNext();
    expect(cubit.state.clip, clipOf(sep(28)), reason: 'the 9th is left out');
    expect(cubit.state.next, isNull);
    cubit.showPrevious();
    expect(cubit.state.clip, clipOf(sep(5), ordinal: 2));
  });

  test('without a filter every clip is stepped through', () {
    clips.publish(septemberIndex());
    final ViewerCubit cubit = viewer(
      clipOf(sep(5), ordinal: 2),
      filter: const ClipFilter.none(),
    );

    expect(cubit.state.filteredIndex, same(cubit.state.index));
    cubit.showNext();
    expect(cubit.state.clip, clipOf(sep(9)));
  });

  test('a new snapshot is filtered again: the clip shown deleted elsewhere '
      'moves on to the next kept clip', () async {
    clips.publish(septemberIndex());
    final ViewerCubit cubit = viewer(clipOf(sep(5), ordinal: 2), filter: trips);

    clips.publish(
      diaryIndex(_default, <LocalDay, int>{
        sep(2): 1,
        sep(5): 1,
        sep(9): 1,
        sep(28): 1,
      }).withClipTags(<String, List<String>>{
        clipOf(sep(2)).relPath: <String>['trip'],
        clipOf(sep(28)).relPath: <String>['trip'],
      }),
    );
    await pumpEventQueue();

    expect(cubit.state.clip, clipOf(sep(28)));
    expect(cubit.state.previous, clipOf(sep(2)));
  });
}
