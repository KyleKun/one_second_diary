// A date-named file nobody made with the app (cached schema `other`) is a
// clip like any other for the calendar, but the index knows it is foreign:
// badged "Imported", counted for the movie
// confirmation and listed for the processing sheet.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
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
      _clip('Old/2026-09-02.mp4'), // hidden behind 2026-09-02.mp4
      _clip('2026-09-05.mp4'),
    ],
    foreign: <String>{'2026-09-02.mp4', 'Old/2026-09-02.mp4', 'nope.mp4'},
  );

  test('a foreign clip counts for the calendar as any clip; the flag, the '
      'visible count and the list newest first come from the files marked, '
      'hidden duplicates and unknown files left out', () {
    expect(index.isForeign(_ref('2026-09-02.mp4')), isTrue);
    expect(index.isForeign(_ref('2026-09-01.mp4')), isFalse);
    expect(index.foreignCount, 1);
    expect(index.clipCount, 3);
    expect(index.foreignClips, <ClipRef>[_ref('2026-09-02.mp4')]);
  });

  test('withSchema and withForeign patch the marks, keep them through a '
      'file patch and a filtered view, and are identity when nothing '
      'changes', () {
    final ClipIndex processed = index.withSchema(
      '2026-09-02.mp4',
      foreign: false,
    );
    expect(processed.foreignCount, 0);
    expect(
      identical(processed.withSchema('nope.mp4', foreign: true), processed),
      isTrue,
    );
    expect(
      identical(index.withSchema('2026-09-02.mp4', foreign: true), index),
      isTrue,
    );

    final ClipIndex two = index.withForeign(<String>{
      '2026-09-01.mp4',
      '2026-09-05.mp4',
    });
    expect(two.foreignClips.map((ClipRef c) => c.relPath), <String>[
      '2026-09-05.mp4',
      '2026-09-01.mp4',
    ]);
    expect(
      identical(
        two.withForeign(two.foreignClips.map((ClipRef c) => c.relPath).toSet()),
        two,
      ),
      isTrue,
    );

    // A rewritten file stays foreign until told otherwise; a removed one
    // leaves the count.
    expect(two.withClip(_clip('2026-09-05.mp4')).foreignCount, 2);
    expect(two.withoutClip('2026-09-05.mp4').foreignCount, 1);
    expect(
      two
          .where((ClipRef clip) => clip.relPath != '2026-09-01.mp4')
          .foreignCount,
      1,
    );
  });
}
