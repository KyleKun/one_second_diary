import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/day_range.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/clips/domain/tag_filter.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

const ProfileKey _default = ProfileKey.defaultProfile;

IndexedClip _clip(String relPath) => IndexedClip(
  ref: ClipRef(profile: _default, relPath: relPath),
  stamp: const FileStamp(sizeBytes: 8, modifiedMs: 0),
);

ClipRef _ref(String relPath) => ClipRef(profile: _default, relPath: relPath);

ClipIndex _index(
  List<String> relPaths, {
  Set<String> private = const <String>{},
  Map<String, List<String>> tags = const <String, List<String>>{},
}) => ClipIndex(
  profile: _default,
  clips: <IndexedClip>[for (final String relPath in relPaths) _clip(relPath)],
  private: private,
  tags: tags,
);

List<String> _paths(Iterable<ClipRef> clips) => <String>[
  for (final ClipRef clip in clips) clip.relPath,
];

void main() {
  final DayRange september = DayRange(
    first: LocalDay(2026, 9, 1),
    last: LocalDay(2026, 9, 30),
  );

  test("a clip's tags are known at once; the vocabulary counts the visible "
      'clips only, most used first, each tag named as the newest clip '
      'spells it', () {
    final ClipIndex index = _index(
      <String>[
        '2026-09-01.mp4',
        '2026-09-02.mp4',
        'Old/2026-09-02.mp4', // hidden behind 2026-09-02.mp4
        '2026-09-05.mp4',
      ],
      tags: <String, List<String>>{
        '2026-09-01.mp4': <String>['trip', 'Bread'],
        '2026-09-02.mp4': <String>['bread'],
        'Old/2026-09-02.mp4': <String>['bread', 'hidden'],
        '2026-09-05.mp4': <String>['BREAD'],
        'not-a-clip.mp4': <String>['nowhere'],
      },
    );

    expect(index.tagsOf(_ref('2026-09-01.mp4')), <String>['Bread', 'trip']);
    expect(index.tagsOf(_ref('Old/2026-09-02.mp4')), <String>[
      'bread',
      'hidden',
    ]);
    expect(index.tagsOf(_ref('not-a-clip.mp4')), isEmpty);
    expect(index.tagsOf(_ref('2026-09-09.mp4')), isEmpty);
    expect(index.hasTags, isTrue);

    expect(index.tagCounts, const <TagCount>[
      TagCount(name: 'BREAD', count: 3),
      TagCount(name: 'trip', count: 1),
    ]);
    expect(identical(index.tagCounts, index.tagCounts), isTrue, reason: 'once');

    final ClipIndex untagged = _index(<String>['2026-09-01.mp4']);
    expect(untagged.hasTags, isFalse);
    expect(untagged.tagCounts, isEmpty);
  });

  test('the filtered view keeps every count, range and neighbour query for '
      'the matching clips only, with their privacy and tags, and composes '
      'with the shareable view either way; no filter is the index itself', () {
    final ClipIndex index = _index(
      <String>[
        '2026-09-01.mp4',
        '2026-09-02.mp4',
        '2026-09-02-2.mp4',
        'Old/2026-09-02.mp4', // hidden behind 2026-09-02.mp4
        '2026-09-05.mp4',
        '2026-09-10.mp4',
      ],
      private: <String>{'2026-09-01.mp4'},
      tags: <String, List<String>>{
        '2026-09-01.mp4': <String>['trip'],
        '2026-09-02.mp4': <String>['trip', 'bread'],
        '2026-09-02-2.mp4': <String>['bread'],
        'Old/2026-09-02.mp4': <String>['trip'],
        '2026-09-10.mp4': <String>['trip'],
      },
    );
    expect(identical(index.filtered(TagFilter.none), index), isTrue);

    final ClipIndex trips = index.filtered(TagFilter(anyOf: <String>{'TRIP'}));
    expect(_paths(trips.clipsIn(september)), <String>[
      '2026-09-01.mp4',
      '2026-09-02.mp4',
      '2026-09-10.mp4',
    ]);
    expect(trips.clipCount, 3);
    expect(trips.countClipsIn(september), 3);
    expect(trips.clipsPerMonth(2026)[8], 3);
    expect(trips.hasDay(LocalDay(2026, 9, 5)), isFalse);
    expect(trips.hiddenDuplicates, isEmpty);
    expect(trips.nextClip(_ref('2026-09-02.mp4')), _ref('2026-09-10.mp4'));
    expect(trips.previousClip(_ref('2026-09-10.mp4')), _ref('2026-09-02.mp4'));
    expect(trips.isPrivate(_ref('2026-09-01.mp4')), isTrue);
    expect(trips.privateCount, 1);
    expect(trips.tagsOf(_ref('2026-09-02.mp4')), <String>['bread', 'trip']);
    expect(trips.tagCounts, const <TagCount>[
      TagCount(name: 'trip', count: 3),
      TagCount(name: 'bread', count: 1),
    ]);

    // A movie of the trip clips: without the private one, both ways round.
    expect(_paths(trips.shareable.clipsIn(september)), <String>[
      '2026-09-02.mp4',
      '2026-09-10.mp4',
    ]);
    expect(
      _paths(
        index.shareable
            .filtered(TagFilter(anyOf: <String>{'trip'}))
            .clipsIn(september),
      ),
      <String>['2026-09-02.mp4', '2026-09-10.mp4'],
    );

    // "Every clip except the bread ones", and what is left to tag.
    expect(
      _paths(index.filtered(TagFilter(noneOf: <String>{'Bread'})).newestFirst),
      <String>['2026-09-10.mp4', '2026-09-05.mp4', '2026-09-01.mp4'],
    );
    expect(
      _paths(index.filtered(TagFilter(untaggedOnly: true)).newestFirst),
      <String>['2026-09-05.mp4'],
    );
    expect(
      _paths(
        index
            .where((ClipRef clip) => clip.day == LocalDay(2026, 9, 2))
            .newestFirst,
      ),
      <String>['2026-09-02-2.mp4', '2026-09-02.mp4'],
    );
  });

  test("setting a file's tags keeps the files and their order, is the same "
      'snapshot when nothing changes, and the backfills see no change; a '
      'rewritten clip stays tagged, a removed one is forgotten', () {
    final ClipIndex index = _index(<String>[
      '2026-09-01.mp4',
      '2026-09-02.mp4',
    ]);

    expect(
      identical(index.withTags('2026-09-01.mp4', const <String>[]), index),
      isTrue,
    );
    expect(
      identical(index.withTags('nope.mp4', const <String>['trip']), index),
      isTrue,
    );
    expect(
      identical(index.withClipTags(const <String, List<String>>{}), index),
      isTrue,
    );

    final ClipIndex tagged = index.withTags('2026-09-01.mp4', <String>[
      'trip',
      'Bread',
      'TRIP',
    ]);
    expect(tagged.tagsOf(_ref('2026-09-01.mp4')), <String>['Bread', 'trip']);
    expect(tagged.hasSameFilesAs(index), isTrue);
    expect(tagged.changedSince(index), isEmpty);
    expect(_paths(tagged.newestFirst), _paths(index.newestFirst));
    expect(
      identical(
        tagged.withTags('2026-09-01.mp4', <String>['Bread', 'trip']),
        tagged,
      ),
      isTrue,
    );
    expect(
      identical(
        tagged.withClipTags(<String, List<String>>{
          '2026-09-01.mp4': <String>['trip', 'Bread'],
        }),
        tagged,
      ),
      isTrue,
    );

    // The whole map replaced: a file not listed has none.
    final ClipIndex replaced = tagged.withClipTags(<String, List<String>>{
      '2026-09-02.mp4': <String>['kids'],
    });
    expect(replaced.tagsOf(_ref('2026-09-01.mp4')), isEmpty);
    expect(replaced.tagsOf(_ref('2026-09-02.mp4')), <String>['kids']);
    expect(replaced.changedSince(tagged), isEmpty);

    // Rewritten in place (a new stamp): still tagged.
    final ClipIndex rewritten = tagged.withClip(
      IndexedClip(
        ref: _ref('2026-09-01.mp4'),
        stamp: const FileStamp(sizeBytes: 9, modifiedMs: 1),
      ),
    );
    expect(rewritten.tagsOf(_ref('2026-09-01.mp4')), <String>['Bread', 'trip']);

    // Removed: forgotten, so a later file of that name has no tags.
    final ClipIndex removed = tagged.withoutClip('2026-09-01.mp4');
    expect(removed.hasTags, isFalse);
    expect(
      removed.withClip(_clip('2026-09-01.mp4')).tagsOf(_ref('2026-09-01.mp4')),
      isEmpty,
    );

    // All tags taken away.
    expect(
      tagged.withTags('2026-09-01.mp4', const <String>[]).hasTags,
      isFalse,
    );
  });
}
