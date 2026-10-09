// What a clip says about itself under the Diary's player, on a Memories
// card and in the viewer: its subtitle and its place, read from the
// metadata cache in memory, never from the file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/diary/data/clip_captions.dart';
import 'package:one_second_diary/features/diary/domain/clip_caption.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../shared/fakes/fake_clip_repository.dart';
import '../../../support/support.dart';
import '../support/diary_fixtures.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

void main() {
  late FakeClipRepository clips;
  late ClipMetadataCache metadata;
  late ClipCaptions captions;
  final LocalDay day = LocalDay(2026, 9, 16);
  final ClipRef clip = diaryClip(_default, day);

  setUp(() {
    clips = FakeClipRepository()
      ..publish(diaryIndex(_default, <LocalDay, int>{day: 1}));
    metadata = ClipMetadataCache(
      paths: AppPaths.forTest(Directory('/osd')),
      logger: memoryLogger(MemoryLogSink()),
    );
    captions = ClipCaptions(clips: clips, metadata: metadata);
  });

  tearDown(() => clips.close());

  void describe(ClipMeta meta, {FileStamp stamp = diaryStamp}) =>
      metadata.put(relPath: clip.relPath, stamp: stamp, meta: meta);

  test('are the clip\'s subtitle and place as the cache knows them', () {
    describe(
      const ClipMeta(
        subtitleText: 'Walk around Asakusa before the rain',
        locationText: 'Tokyo, Japan',
      ),
    );

    expect(
      captions.of(clip),
      const ClipCaption(
        subtitle: 'Walk around Asakusa before the rain',
        location: 'Tokyo, Japan',
      ),
    );
  });

  test('are none for a blank subtitle and place, for a clip the cache '
      'describes at another version, or not at all', () {
    describe(const ClipMeta(subtitleText: '', locationText: '  '));
    expect(captions.of(clip), ClipCaption.none);

    describe(
      const ClipMeta(subtitleText: 'old'),
      stamp: const FileStamp(sizeBytes: 1, modifiedMs: 1),
    );
    expect(captions.of(clip), ClipCaption.none);

    expect(
      captions.of(diaryClip(_default, LocalDay(2026, 9, 17))),
      ClipCaption.none,
    );
  });
}
