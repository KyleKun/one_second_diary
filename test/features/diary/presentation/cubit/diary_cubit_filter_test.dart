// The Diary's filter: days without a kept clip dim and can't be selected,
// the player and Memories read the kept clips, "N videos match" follows,
// clearing gives the snapshot itself back, a profile switch clears, a new
// snapshot is filtered again, and a search reads subtitles and places from
// the metadata cache.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/core/time/midnight_ticker.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/diary/data/clip_captions.dart';
import 'package:one_second_diary/features/diary/data/clip_filtering.dart';
import 'package:one_second_diary/features/diary/domain/clip_filter.dart';
import 'package:one_second_diary/features/diary/domain/memories_feed.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_day.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/diary/presentation/diary_opener.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';

import '../../../../shared/fakes/clip_index_fixture.dart';
import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../shared/fakes/fake_profiles_repository.dart';
import '../../../../support/support.dart';
import '../../../journey/support/journey_fakes.dart';
import '../../support/diary_fixtures.dart';
import '../../support/fake_clip_store.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

/// Monday, September 28, 2026, 22:50.
final DateTime _now = DateTime(2026, 9, 28, 22, 50);

LocalDay sep(int day) => LocalDay(2026, 9, day);

ClipRef clipOf(LocalDay day, {int ordinal = 1}) =>
    diaryClip(_default, day, ordinal: ordinal);

/// September 2, 5 (two clips), 9 and 28: "trip" on the 2nd and the 5th's
/// second clip, "kids" on the 9th, nothing on the 28th (today).
ClipIndex septemberIndex() =>
    diaryIndex(_default, <LocalDay, int>{
      sep(2): 1,
      sep(5): 2,
      sep(9): 1,
      sep(28): 1,
    }).withClipTags(<String, List<String>>{
      clipOf(sep(2)).relPath: <String>['trip'],
      clipOf(sep(5), ordinal: 2).relPath: <String>['trip'],
      clipOf(sep(9)).relPath: <String>['kids'],
    });

final ClipFilter trips = ClipFilter(tags: TagFilter(anyOf: <String>{'Trip'}));

void main() {
  late FakeClock clock;
  late FakeProfilesRepository profiles;
  late FakeClipRepository clips;
  late SettingsRepository settings;
  late MapClipMetadataCache metadata;
  late FakeClipStore store;
  late FakeShareGateway share;
  late DiaryOpener opener;
  final AppPaths paths = AppPaths.forTest(Directory('/osd'));
  final List<DiaryCubit> made = <DiaryCubit>[];

  setUp(() async {
    clock = FakeClock(_now);
    profiles = FakeProfilesRepository();
    clips = FakeClipRepository();
    store = FakeClipStore(clips);
    share = FakeShareGateway();
    opener = DiaryOpener();
    settings = SettingsRepository(prefs: await openLegacyPrefs(legacyPrefs()));
    metadata = MapClipMetadataCache();
  });

  tearDown(() async {
    for (final DiaryCubit subject in made) {
      await subject.close();
    }
    made.clear();
    await profiles.close();
    await clips.close();
    await opener.dispose();
  });

  DiaryCubit cubit() {
    final DiaryCubit subject = DiaryCubit(
      profiles: profiles,
      clips: clips,
      settings: settings,
      midnight: MidnightTicker(clock: clock),
      captions: ClipCaptions(clips: clips, metadata: metadata),
      filtering: ClipFiltering(metadata: metadata),
      store: store,
      share: share,
      opener: opener,
      paths: paths,
      logger: memoryLogger(MemoryLogSink()),
    );
    made.add(subject);
    return subject;
  }

  test('without a filter the kept clips are the snapshot itself', () {
    clips.publish(septemberIndex());
    final DiaryState state = cubit().state;

    expect(state.isFiltered, isFalse);
    expect(state.filteredIndex, same(state.index));
    expect(state.matchCount, 5);
  });

  test('a tag filter dims the days without a kept clip, keeps their picture '
      'and makes them unselectable; the player shows the kept clips of a '
      'day; "N videos match" counts them', () {
    clips.publish(septemberIndex());
    final DiaryCubit subject = cubit()..setFilter(trips);

    final DiaryState state = subject.state;
    expect(state.isFiltered, isTrue);
    expect(state.matchCount, 2);
    expect(state.dayOf(sep(2)).kind, DiaryDayKind.recorded);
    final DiaryDay fifth = state.dayOf(sep(5));
    expect(fifth.kind, DiaryDayKind.recorded);
    expect(fifth.clip, clipOf(sep(5), ordinal: 2));
    expect(fifth.clipCount, 1);
    final DiaryDay ninth = state.dayOf(sep(9));
    expect(ninth.kind, DiaryDayKind.filteredOut);
    expect(ninth.clip, clipOf(sep(9)), reason: 'its picture stays, faint');
    expect(ninth.isSelectable, isFalse);
    expect(state.dayOf(sep(10)).kind, DiaryDayKind.missed);
    expect(state.dayOf(sep(1)).kind, DiaryDayKind.beforeFirstClip);

    subject.selectDay(sep(9));
    expect(subject.state.selected, isNot(sep(9)));
    subject.selectDay(sep(5));
    expect(subject.state.selectedClips, <ClipRef>[clipOf(sep(5), ordinal: 2)]);
    expect(subject.state.shownClip, clipOf(sep(5), ordinal: 2));
    expect(subject.state.neighboursOf(clipOf(sep(5), ordinal: 2)), (
      previous: clipOf(sep(2)),
      next: null,
    ));
  });

  test('a filter that leaves the selected day out moves the selection to '
      "the month's latest kept day; today left out is not selected", () {
    clips.publish(septemberIndex());
    final DiaryCubit subject = cubit();
    expect(subject.state.selected, sep(28));

    subject.setFilter(trips);
    expect(subject.state.dayOf(sep(28)).kind, DiaryDayKind.filteredOut);
    expect(subject.state.selected, sep(5));

    subject.clearFilter();
    expect(subject.state.selected, sep(5), reason: 'a selection stays');
  });

  test('Memories lists the kept days only, and is empty under a filter '
      'nothing matches; clearing gives the snapshot itself back', () {
    clips.publish(septemberIndex());
    final DiaryCubit subject = cubit()..setFilter(trips);

    final MemoriesFeed feed = MemoriesFeed.of(subject.state.filteredIndex!);
    expect(
      <LocalDay>[
        for (int i = 0; i < feed.length; i++)
          if (feed[i] case MemoriesDayRow(:final LocalDay day)) day,
      ],
      <LocalDay>[sep(5), sep(2)],
    );

    subject.setFilter(ClipFilter(tags: TagFilter(anyOf: <String>{'bread'})));
    expect(subject.state.matchCount, 0);
    expect(MemoriesFeed.of(subject.state.filteredIndex!).isEmpty, isTrue);

    subject.clearFilter();
    expect(subject.state.isFiltered, isFalse);
    expect(subject.state.filteredIndex, same(subject.state.index));
  });

  test('the kept clips are computed once per filter and snapshot: a new '
      'snapshot is filtered again, the same one keeps its sub-index', () async {
    clips.publish(septemberIndex());
    final DiaryCubit subject = cubit()..setFilter(trips);
    final ClipIndex? filtered = subject.state.filteredIndex;
    expect(filtered, isNotNull);

    subject.showPreviousMonth();
    expect(subject.state.filteredIndex, same(filtered));

    clips.publish(
      septemberIndex().withTags(clipOf(sep(9)).relPath, <String>['trip']),
    );
    await pumpEventQueue();
    expect(subject.state.filteredIndex, isNot(same(filtered)));
    expect(subject.state.matchCount, 3);
    expect(subject.state.dayOf(sep(9)).kind, DiaryDayKind.recorded);
  });

  test('a profile switch clears the filter', () async {
    const ProfileKey trip = ProfileKey('Trip');
    profiles.addProfile(testProfile(key: trip));
    clips
      ..publish(septemberIndex())
      ..publish(clipIndexOf(trip, <LocalDay>[sep(2), sep(28)]));
    final DiaryCubit subject = cubit()..setFilter(trips);

    await profiles.activate(trip);
    await pumpEventQueue();

    expect(subject.state.profile.key, trip);
    expect(subject.state.isFiltered, isFalse);
    expect(subject.state.matchCount, 2);
  });

  test('a search reads tags, subtitles and places from memory; a clip not '
      'read yet matches through its tags only', () {
    metadata.known[clipOf(sep(28)).relPath] = const ClipMeta(
      subtitleText: 'Swim at the beach',
      locationText: 'Praia do Rosa',
    );
    metadata.known[clipOf(sep(5)).relPath] = const ClipMeta(
      subtitleText: 'Bread day',
    );
    clips.publish(septemberIndex());
    final DiaryCubit subject = cubit();

    subject.setFilter(const ClipFilter(query: 'ROSA'));
    expect(subject.state.matchCount, 1);
    expect(subject.state.dayOf(sep(28)).kind, DiaryDayKind.recorded);

    subject.setFilter(const ClipFilter(query: 'trip'));
    expect(subject.state.matchCount, 2, reason: 'the tag, read or not');

    subject.setFilter(
      ClipFilter(tags: TagFilter(untaggedOnly: true), query: 'bread'),
    );
    expect(subject.state.matchCount, 1);
    expect(subject.state.dayOf(sep(5)).clip, clipOf(sep(5)));
  });

  test('a clip added from the Diary clears the filter and shows', () {
    clips.publish(septemberIndex());
    final DiaryCubit subject = cubit()
      ..setFilter(trips)
      ..addStarted()
      ..addFinished(saved: clipOf(sep(9)));

    expect(subject.state.isFiltered, isFalse);
    expect(subject.state.selected, sep(9));
    expect(subject.state.shownClip, clipOf(sep(9)));
  });
}
