import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/movies/domain/movie_tags.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

void main() {
  test('a movie is described as clips=<n>;from=<day>;to=<day> and read back '
      'in any order; a description not whole or not ours says nothing '
      '(decision O9)', () {
    expect(
      MovieTags.describe(
        clips: 25,
        from: LocalDay(2026, 9, 1),
        to: LocalDay(2026, 9, 28),
      ),
      'clips=25;from=2026-09-01;to=2026-09-28',
    );

    const MovieTags tags = MovieTags(
      description: 'to=2026-09-28;clips=25;from=2026-09-01',
    );
    expect(
      (tags.clipCount, tags.from, tags.to),
      (25, LocalDay(2026, 9, 1), LocalDay(2026, 9, 28)),
    );

    for (final String? description in <String?>[
      null,
      '',
      'Shot on my phone',
      'clips=25;from=2026-09-01',
      'clips=many;from=2026-09-01;to=2026-09-28',
      'clips=0;from=2026-09-01;to=2026-09-28',
      'clips=2;from=2026-02-30;to=2026-03-01',
      'clips=2;from=2026-03-02;to=2026-03-01',
    ]) {
      final MovieTags other = MovieTags(description: description);
      expect(
        (other.clipCount, other.from, other.to),
        (null, null, null),
        reason: '$description',
      );
    }
  });

  test('a v3 movie names its profile by key in its comment, `profile=` being '
      'Default (decision D3); the title is trimmed; the canvas follows the '
      'frame', () {
    final Map<String?, ProfileKey?> profiles = <String?, ProfileKey?>{
      'profile=Kids': const ProfileKey('Kids'),
      'profile=': ProfileKey.defaultProfile,
      'profile=Mom/Dad': const ProfileKey('Mom/Dad'),
      null: null,
      '': null,
      'origin=gallery': null,
      'Profile=Kids': null,
      'my profile=Kids': null,
    };
    for (final MapEntry<String?, ProfileKey?>(key: comment, value: profile)
        in profiles.entries) {
      expect(MovieTags(comment: comment).profile, profile, reason: comment);
    }

    expect(const MovieTags(title: ' 2025 ').title, '2025');
    expect(const MovieTags(title: '  ').title, isNull);

    expect(
      const MovieTags(width: 1920, height: 1080).orientation,
      VideoOrientation.landscape,
    );
    expect(
      const MovieTags(width: 1080, height: 1920).orientation,
      VideoOrientation.portrait,
    );
    expect(const MovieTags(width: 1080).orientation, isNull);
    expect(const MovieTags(width: 0, height: 0).orientation, isNull);
  });

  test('a movie made with a tag filter says its tags and the ones left out '
      'in its description, sorted by fold key, a ";" in a tag made a '
      'space, and reads them back; a description without them has none', () {
    expect(
      MovieTags.describe(
        clips: 4,
        from: LocalDay(2026, 9, 1),
        to: LocalDay(2026, 9, 5),
        privateClips: 1,
        tags: <String>['trip', 'Kids', 'sour; dough'],
        without: <String>['work'],
      ),
      'clips=4;from=2026-09-01;to=2026-09-05;private=1'
      ';tags=Kids,sour  dough,trip;without=work',
    );
    expect(
      MovieTags.describe(
        clips: 2,
        from: LocalDay(2026, 9, 1),
        to: LocalDay(2026, 9, 3),
        tags: <String>[],
        without: <String>['', ' '],
      ),
      'clips=2;from=2026-09-01;to=2026-09-03',
    );

    const MovieTags tags = MovieTags(
      description:
          'without=work;clips=4;from=2026-09-01;to=2026-09-05'
          ';tags=Kids,trip',
    );
    expect(tags.tags, <String>['Kids', 'trip']);
    expect(tags.without, <String>['work']);
    expect(tags.clipCount, 4);

    for (final String? description in <String?>[
      null,
      'clips=4;from=2026-09-01;to=2026-09-05',
      'tags=;without=,',
    ]) {
      final MovieTags other = MovieTags(description: description);
      expect(other.tags, isEmpty, reason: '$description');
      expect(other.without, isEmpty, reason: '$description');
    }
  });

  test('the transition the engine appended to a description '
      '(transition=<tag>, MovieTransition.descriptionPart) reads back; a '
      'description never carries one by itself, and an unknown tag reads as '
      'none (D27)', () {
    expect(MovieTransition.fadeBlack.descriptionPart, 'transition=black');
    expect(
      MovieTags.describe(
        clips: 4,
        from: LocalDay(2026, 9, 1),
        to: LocalDay(2026, 9, 5),
        without: <String>['work'],
      ),
      'clips=4;from=2026-09-01;to=2026-09-05;without=work',
    );
    for (final (String? description, MovieTransition? read)
        in <(String?, MovieTransition?)>[
          (
            'clips=4;from=2026-09-01;to=2026-09-05;transition=fade',
            MovieTransition.crossfade,
          ),
          (
            'transition=white;clips=4;from=2026-09-01;to=2026-09-05',
            MovieTransition.fadeWhite,
          ),
          ('clips=4;from=2026-09-01;to=2026-09-05', null),
          ('clips=4;from=2026-09-01;to=2026-09-05;transition=wipe', null),
          (null, null),
        ]) {
      expect(
        MovieTags(description: description).transition,
        read,
        reason: '$description',
      );
    }
  });

  test('a movie made with music says music=on last; withMusic rewrites just '
      'that part in place or appends it; musicOn reads on, off, or none for '
      'no part or an unknown value (D28)', () {
    expect(
      MovieTags.describe(
        clips: 4,
        from: LocalDay(2026, 9, 1),
        to: LocalDay(2026, 9, 5),
        tags: <String>['trip'],
        withMusic: true,
      ),
      'clips=4;from=2026-09-01;to=2026-09-05;tags=trip;music=on',
    );
    expect(
      MovieTags.withMusic(
        'clips=4;from=2026-09-01;to=2026-09-05;music=on;transition=fade',
        on: false,
      ),
      'clips=4;from=2026-09-01;to=2026-09-05;music=off;transition=fade',
    );
    expect(
      MovieTags.withMusic('clips=4;from=2026-09-01;to=2026-09-05', on: true),
      'clips=4;from=2026-09-01;to=2026-09-05;music=on',
    );
    expect(MovieTags.withMusic(null, on: false), 'music=off');
    for (final (String? description, bool? read) in <(String?, bool?)>[
      ('clips=4;from=2026-09-01;to=2026-09-05;music=on', true),
      ('music=off;clips=4;from=2026-09-01;to=2026-09-05', false),
      ('clips=4;from=2026-09-01;to=2026-09-05', null),
      ('clips=4;from=2026-09-01;to=2026-09-05;music=loud', null),
      (null, null),
    ]) {
      expect(
        MovieTags(description: description).musicOn,
        read,
        reason: '$description',
      );
    }
  });
}
