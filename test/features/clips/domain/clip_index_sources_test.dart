// A clip whose original recording is kept beside the diary is marked in the
// index from the Originals folder's names, so the
// sheets offer "Edit again" without touching the disk.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

IndexedClip _clip(String relPath) => IndexedClip(
  ref: ClipRef(profile: _default, relPath: relPath),
  stamp: const FileStamp(sizeBytes: 8, modifiedMs: 0),
);

ClipRef _ref(String relPath) => ClipRef(profile: _default, relPath: relPath);

void main() {
  final ClipIndex index = ClipIndex(
    profile: _default,
    clips: <IndexedClip>[
      _clip('2026-09-01.mp4'),
      _clip('2026-09-02.mp4'),
      _clip('2026-09-05.mp4'),
    ],
    tags: <String, List<String>>{
      '2026-09-02.mp4': <String>['trip'],
    },
    sources: <String>{'2026-09-02.mp4', 'nope.mp4'},
  );

  test('hasSource comes from the names given, unknown files left out; the '
      'mark survives a file patch, a filtered view and a privacy patch', () {
    expect(index.hasSource(_ref('2026-09-02.mp4')), isTrue);
    expect(index.hasSource(_ref('2026-09-01.mp4')), isFalse);

    final ClipIndex patched = index
        .withClip(_clip('2026-09-06.mp4'))
        .withoutClip('2026-09-01.mp4')
        .withPrivacy('2026-09-02.mp4', private: true);
    expect(patched.hasSource(_ref('2026-09-02.mp4')), isTrue);
    expect(patched.hasSource(_ref('2026-09-06.mp4')), isFalse);
    expect(
      index
          .filtered(TagFilter(anyOf: <String>{'trip'}))
          .hasSource(_ref('2026-09-02.mp4')),
      isTrue,
    );
  });

  test('withSources replaces the marks wholesale (a scan), withSource '
      'patches one; both are identity when nothing changes, and an '
      'unknown file is ignored', () {
    expect(
      identical(index.withSources(<String>{'2026-09-02.mp4'}), index),
      isTrue,
    );
    expect(
      identical(index.withSource('2026-09-02.mp4', has: true), index),
      isTrue,
    );
    expect(identical(index.withSource('nope.mp4', has: true), index), isTrue);

    final ClipIndex scanned = index.withSources(<String>{'2026-09-05.mp4'});
    expect(scanned.hasSource(_ref('2026-09-02.mp4')), isFalse);
    expect(scanned.hasSource(_ref('2026-09-05.mp4')), isTrue);
    expect(scanned.clipCount, 3);
    expect(scanned.tagsOf(_ref('2026-09-02.mp4')), <String>['trip']);

    final ClipIndex removed = scanned.withSource('2026-09-05.mp4', has: false);
    expect(removed.hasSource(_ref('2026-09-05.mp4')), isFalse);
    expect(
      scanned.withSources(const <String>{}).hasSource(_ref('2026-09-05.mp4')),
      isFalse,
    );

    // The same file: not listed as changed.
    expect(scanned.changedSince(index), isEmpty);
  });
}
