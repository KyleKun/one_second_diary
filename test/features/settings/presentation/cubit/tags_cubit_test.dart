// Settings › Tags: the list follows the libraries, a batch shows its
// progress and refreshes the list when it ends, Stop reaches the batch, and
// a colour choice is stored and repaints the chips.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/tag_batch.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/domain/tag_batch_event.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/tags_cubit.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/tags_state.dart';

import '../../../../shared/fakes/clip_index_fixture.dart';
import '../../../../shared/fakes/fake_clip_repository.dart';
import '../../../../shared/fakes/fake_clip_tags.dart';
import '../../../../shared/fakes/fake_profiles_repository.dart';
import '../../../../support/support.dart';

/// A [TagBatch] the test drives: each [rename] / [remove] records its
/// arguments in [calls] and reports what the test adds to [events].
class _ScriptedTagBatch extends Fake implements TagBatch {
  final List<({String kind, String from, String? to, CancelToken token})>
  calls = <({String kind, String from, String? to, CancelToken token})>[];

  late StreamController<TagBatchEvent> events;

  Future<void> dispose() async {
    if (calls.isNotEmpty && !events.isClosed) await events.close();
  }

  @override
  Stream<TagBatchEvent> rename(
    String from,
    String to, {
    required CancelToken cancelToken,
  }) {
    calls.add((kind: 'rename', from: from, to: to, token: cancelToken));
    events = StreamController<TagBatchEvent>();
    return events.stream;
  }

  @override
  Stream<TagBatchEvent> remove(String tag, {required CancelToken cancelToken}) {
    calls.add((kind: 'remove', from: tag, to: null, token: cancelToken));
    events = StreamController<TagBatchEvent>();
    return events.stream;
  }
}

const ProfileKey _work = ProfileKey('Work');

void main() {
  late FakeClipRepository clips;
  late FakeClipTags tags;
  late _ScriptedTagBatch batch;
  late PrefsStore prefs;
  late TagColors colors;
  late TagsCubit cubit;

  const List<TagCount> vocabulary = <TagCount>[
    TagCount(name: 'trip', count: 3),
    TagCount(name: 'bread', count: 1),
  ];

  setUp(() async {
    clips = FakeClipRepository();
    addTearDown(clips.close);
    tags = FakeClipTags(clips, suggestions: <TagCount>[...vocabulary]);
    batch = _ScriptedTagBatch();
    addTearDown(batch.dispose);
    prefs = await openLegacyPrefs(<String, Object>{});
    colors = TagColors(prefs: prefs, logger: memoryLogger(MemoryLogSink()));
    addTearDown(colors.dispose);
    final FakeProfilesRepository profiles = FakeProfilesRepository(
      profiles: <Profile>[
        testProfile(),
        testProfile(key: _work),
      ],
    );
    addTearDown(profiles.close);
    cubit = TagsCubit(
      tags: tags,
      batch: batch,
      colors: colors,
      clips: clips,
      profiles: profiles,
      logger: memoryLogger(MemoryLogSink()),
    );
    addTearDown(cubit.close);
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  test('load lists the vocabulary, and lists it again whenever a loaded '
      "profile's library publishes a snapshot", () async {
    cubit.load();

    expect(cubit.state.loaded, isTrue);
    expect(cubit.state.tags, vocabulary);
    expect(cubit.state.batch, isNull);

    tags.suggestions
      ..clear()
      ..add(const TagCount(name: 'kids', count: 2));
    clips.publish(clipIndexOf(_work, <LocalDay>[LocalDay(2024, 1, 5)]));
    await pump();

    expect(cubit.state.tags, const <TagCount>[
      TagCount(name: 'kids', count: 2),
    ]);
  });

  test('a rename runs as a batch: its progress shows clip by clip, and once '
      'it has finished the list is read again', () async {
    cubit.load();

    final Future<void> run = cubit.rename('trip', 'journey');

    expect(batch.calls.single.kind, 'rename');
    expect(batch.calls.single.from, 'trip');
    expect(batch.calls.single.to, 'journey');
    expect(cubit.state.isBatchRunning, isTrue);
    expect(cubit.state.batch?.kind, TagBatchKind.rename);
    expect(cubit.state.batch?.tag, 'trip');

    batch.events.add(const TagBatchProgress(done: 0, total: 3));
    await pump();
    expect(cubit.state.batch?.total, 3);
    expect(cubit.state.batch?.progress, 0);

    batch.events.add(const TagBatchProgress(done: 2, total: 3));
    await pump();
    expect(cubit.state.batch?.done, 2);
    expect(cubit.state.batch?.progress, closeTo(2 / 3, 1e-9));

    // A second batch while one runs is ignored.
    await cubit.remove('bread');
    expect(batch.calls, hasLength(1));

    tags.suggestions
      ..clear()
      ..add(const TagCount(name: 'journey', count: 3))
      ..add(const TagCount(name: 'bread', count: 1));
    batch.events.add(
      const TagBatchFinished(updated: 3, failed: 0, stopped: false),
    );
    await batch.events.close();
    await run;

    expect(cubit.state.isBatchRunning, isFalse);
    expect(
      cubit.state.batch?.finished,
      const TagBatchFinished(updated: 3, failed: 0, stopped: false),
    );
    expect(cubit.state.tags.first, const TagCount(name: 'journey', count: 3));
  });

  test('Stop cancels the token the batch runs on; the batch then reports '
      'that it stopped', () async {
    cubit.load();
    final Future<void> run = cubit.remove('trip');
    batch.events.add(const TagBatchProgress(done: 1, total: 3));
    await pump();

    cubit.stopBatch();

    expect(batch.calls.single.kind, 'remove');
    expect(batch.calls.single.token.isCancelled, isTrue);

    batch.events.add(
      const TagBatchFinished(updated: 1, failed: 0, stopped: true),
    );
    await batch.events.close();
    await run;

    expect(cubit.state.batch?.finished?.stopped, isTrue);
    expect(cubit.state.isBatchRunning, isFalse);
  });

  test('a colour choice is stored and bumps the version so chips repaint; '
      'a store that fails is counted so the page can say so', () async {
    cubit.load();
    final int version = cubit.state.colorsVersion;

    await cubit.setColor('trip', 9);
    await pump();

    expect(prefs.read(PrefKeys.tagColors), '{"trip":9}');
    expect(cubit.state.colorsVersion, version + 1);
    expect(cubit.state.colorSaveFailures, 0);

    await cubit.setColor('trip', 0);

    expect(cubit.state.colorSaveFailures, 1);
    expect(prefs.read(PrefKeys.tagColors), '{"trip":9}');
  });
}
