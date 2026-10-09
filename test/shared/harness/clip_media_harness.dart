import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../support/support.dart';
import '../fakes/fake_clip_caches.dart';
import '../fakes/fake_clip_repository.dart';
import '../widgets/support/osd_widget_harness.dart';

const ProfileKey mediaProfile = ProfileKey.defaultProfile;
const FileStamp mediaStamp = FileStamp(sizeBytes: 8, modifiedMs: 1000);

/// The clip of January [day], 2024.
ClipRef mediaClip(int day) => ClipRef(
  profile: mediaProfile,
  relPath: '${LocalDay(2024, 1, day).fileStem}.mp4',
);

/// A widget-test harness for pages and widgets that show clips
/// (`ClipThumbnailView`, `ClipPlayerView`): what they
/// read from the tree, faked: the paths, the index (a [FakeClipRepository]
/// the test publishes), the thumbnails (a [FakeThumbnailRepository] the
/// test scripts) and a real [PlayerPool] over fake [players].
///
/// ```dart
/// final ClipMediaHarness media = ClipMediaHarness()..index(<int>[4, 5]);
/// addTearDown(media.dispose);
/// await media.pump(tester, ClipPlayerView(clip: mediaClip(5)));
/// ```
final class ClipMediaHarness {
  ClipMediaHarness()
    : paths = AppPaths.forTest(Directory('/osd')),
      clips = FakeClipRepository(),
      thumbnails = FakeThumbnailRepository(),
      players = FakePlayerFactory() {
    pool = PlayerPool(
      factory: players,
      logger: memoryLogger(MemoryLogSink()),
      muted: true,
    );
  }

  final AppPaths paths;
  final FakeClipRepository clips;
  final FakeThumbnailRepository thumbnails;
  final FakePlayerFactory players;
  late PlayerPool pool;

  /// Publishes an index of [days] of January 2024, each at [stamp].
  void index(List<int> days, {FileStamp stamp = mediaStamp}) => clips.publish(
    ClipIndex(
      profile: mediaProfile,
      clips: <IndexedClip>[
        for (final int day in days)
          IndexedClip(ref: mediaClip(day), stamp: stamp),
      ],
    ),
  );

  String pathOf(ClipRef clip) => paths.absoluteFromVideos(clip.relPath);

  /// The player the pool made for [clip], the last one.
  FakePlayerHandle playerOf(ClipRef clip) => players.created.lastWhere(
    (FakePlayerHandle handle) => handle.path == pathOf(clip),
  );

  /// Pumps [child] with the services, [size] logical pixels big.
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(358, 196),
    bool disableAnimations = false,
  }) => pumpOsd(
    tester,
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppPaths>.value(value: paths),
        RepositoryProvider<ClipRepository>.value(value: clips),
        RepositoryProvider<ThumbnailRepository>.value(value: thumbnails),
        RepositoryProvider<PlayerPool>.value(value: pool),
      ],
      child: SizedBox.fromSize(size: size, child: child),
    ),
    disableAnimations: disableAnimations,
  );

  Future<void> dispose() async {
    await pool.dispose();
    await clips.close();
  }
}
