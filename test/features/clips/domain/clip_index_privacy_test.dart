import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

IndexedClip _clip(String relPath) => IndexedClip(
  ref: ClipRef(profile: _default, relPath: relPath),
  stamp: const FileStamp(sizeBytes: 8, modifiedMs: 0),
);

ClipRef _ref(String relPath) => ClipRef(profile: _default, relPath: relPath);

ClipIndex _index(List<String> relPaths, {Set<String> private = const {}}) =>
    ClipIndex(
      profile: _default,
      clips: <IndexedClip>[
        for (final String relPath in relPaths) _clip(relPath),
      ],
      private: private,
    );

List<String> _paths(Iterable<ClipRef> clips) => <String>[
  for (final ClipRef clip in clips) clip.relPath,
];

void main() {
  final DayRange september = DayRange(
    first: LocalDay(2026, 9, 1),
    last: LocalDay(2026, 9, 30),
  );

  test('a private clip is a clip like any other for the calendar; the '
      'shareable view has every count and range without it, and keeps a '
      'duplicate hidden by a private clip hidden', () {
    final ClipIndex index = _index(
      <String>[
        '2026-09-01.mp4',
        '2026-09-02.mp4',
        '2026-09-02-2.mp4',
        'Old/2026-09-02.mp4', // hidden behind 2026-09-02.mp4
        '2026-09-05.mp4',
      ],
      private: <String>{'2026-09-02.mp4', '2026-09-05.mp4', 'not-a-clip.mp4'},
    );

    expect(index.isPrivate(_ref('2026-09-02.mp4')), isTrue);
    expect(index.isPrivate(_ref('2026-09-01.mp4')), isFalse);
    expect(index.privateCount, 2);
    expect(index.clipCount, 4);
    expect(index.dayCount, 3);
    expect(index.hasDay(LocalDay(2026, 9, 5)), isTrue);

    final ClipIndex shareable = index.shareable;
    expect(identical(shareable, index.shareable), isTrue, reason: 'once');
    expect(shareable.clipCount, 2);
    expect(shareable.privateCount, 0);
    expect(_paths(shareable.clipsIn(september)), <String>[
      '2026-09-01.mp4',
      '2026-09-02-2.mp4',
    ]);
    expect(shareable.countClipsIn(september), 2);
    expect(shareable.hasDay(LocalDay(2026, 9, 5)), isFalse);
    expect(shareable.hiddenDuplicates, isEmpty);
    expect(shareable.skippedDays(september, today: LocalDay(2026, 9, 6)), [
      LocalDay(2026, 9, 3),
      LocalDay(2026, 9, 4),
      LocalDay(2026, 9, 5),
      LocalDay(2026, 9, 6),
    ]);
    expect(identical(shareable.shareable, shareable), isTrue);

    // Without private clips the shareable view is the index itself.
    final ClipIndex public = _index(<String>['2026-09-01.mp4']);
    expect(identical(public.shareable, public), isTrue);
  });

  test(
    'marking a file private or public keeps the files and their order, '
    'and is the same snapshot when nothing changes; a rewritten clip stays '
    'private, a removed one is forgotten, and the backfills see no change',
    () {
      final ClipIndex index = _index(<String>[
        '2026-09-01.mp4',
        '2026-09-02.mp4',
      ]);

      expect(
        identical(index.withPrivacy('2026-09-01.mp4', private: false), index),
        isTrue,
      );
      expect(
        identical(index.withPrivacy('nope.mp4', private: true), index),
        isTrue,
      );
      expect(identical(index.withPrivate(const <String>{}), index), isTrue);

      final ClipIndex marked = index.withPrivacy(
        '2026-09-01.mp4',
        private: true,
      );
      expect(marked.isPrivate(_ref('2026-09-01.mp4')), isTrue);
      expect(marked.privateCount, 1);
      expect(marked.hasSameFilesAs(index), isTrue);
      expect(marked.changedSince(index), isEmpty);
      expect(_paths(marked.newestFirst), _paths(index.newestFirst));
      expect(
        identical(marked.withPrivacy('2026-09-01.mp4', private: true), marked),
        isTrue,
      );
      expect(
        identical(
          marked.withPrivate(<String>{'2026-09-01.mp4', 'x.mp4'}),
          marked,
        ),
        isTrue,
      );

      final ClipIndex all = marked.withPrivate(<String>{
        '2026-09-01.mp4',
        '2026-09-02.mp4',
      });
      expect(all.privateCount, 2);
      expect(all.shareable.clipCount, 0);
      expect(all.shareable.isEmpty, isTrue);

      // Rewritten in place (a new stamp): still private.
      final ClipIndex rewritten = marked.withClip(
        IndexedClip(
          ref: _ref('2026-09-01.mp4'),
          stamp: const FileStamp(sizeBytes: 9, modifiedMs: 1),
        ),
      );
      expect(rewritten.isPrivate(_ref('2026-09-01.mp4')), isTrue);

      // Removed: forgotten, so a later file of that name is not private.
      final ClipIndex removed = marked.withoutClip('2026-09-01.mp4');
      expect(removed.privateCount, 0);
      expect(
        removed
            .withClip(_clip('2026-09-01.mp4'))
            .isPrivate(_ref('2026-09-01.mp4')),
        isFalse,
      );

      // Public again.
      expect(
        marked.withPrivacy('2026-09-01.mp4', private: false).privateCount,
        0,
      );
    },
  );
}
