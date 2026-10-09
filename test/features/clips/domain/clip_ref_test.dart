import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

void main() {
  test('takes the day and ordinal from the file name, never from outside; '
      'any other name is no clip', () {
    final ClipRef clip = ClipRef(
      profile: ProfileKey.defaultProfile,
      relPath: 'trip/2024-01-05-2.mp4',
    );

    expect(clip.day, LocalDay(2024, 1, 5));
    expect(clip.ordinal, 2);

    // A path whose file name is not a clip name is no clip.
    for (final String relPath in <String>[
      'notes.txt',
      '2024-01-05.edited.mp4',
      'trip/2024-01-05_483920.mp4',
      '2024-01-05/',
    ]) {
      expect(
        ClipRef.tryParse(profile: ProfileKey.defaultProfile, relPath: relPath),
        isNull,
        reason: relPath,
      );
    }
    expect(
      () => ClipRef(profile: ProfileKey.defaultProfile, relPath: 'notes.txt'),
      throwsArgumentError,
    );
  });

  test("a clip lies inside its profile's folder (O1 path segments)", () {
    const ProfileKey work = ProfileKey('Work');
    ClipRef? parse(ProfileKey profile, String relPath) =>
        ClipRef.tryParse(profile: profile, relPath: relPath);

    expect(parse(work, 'Profiles/Work/2024-01-05.mp4'), isNotNull);
    expect(parse(work, 'Profiles/Work/trip/2024-01-05.mp4'), isNotNull);
    expect(
      parse(ProfileKey.defaultProfile, 'Profilesx/2024-01-05.mp4'),
      isNotNull,
    );

    expect(parse(work, '2024-01-05.mp4'), isNull);
    expect(parse(work, 'Profiles/Workshop/2024-01-05.mp4'), isNull);
    expect(
      parse(ProfileKey.defaultProfile, 'Profiles/Work/2024-01-05.mp4'),
      isNull,
    );
    expect(parse(ProfileKey.defaultProfile, 'Movies/2024-01-05.mp4'), isNull);
    expect(parse(ProfileKey.defaultProfile, '/abs/2024-01-05.mp4'), isNull);
    expect(parse(ProfileKey.defaultProfile, 'a/../2024-01-05.mp4'), isNull);
  });

  test('a legacy profile name is opaque (v1.5, B §5): one with a slash, '
      'spaces, dots or accents owns the clips under Profiles/<name>/, as '
      'v1.7 listed them (O1)', () {
    for (final String name in <String>['Mom/Dad', 'Trip ', 'a.b', 'Café']) {
      final ProfileKey profile = ProfileKey(name);

      expect(
        ClipRef.tryParse(
          profile: profile,
          relPath: 'Profiles/$name/2024-01-05.mp4',
        )?.day,
        LocalDay(2024, 1, 5),
        reason: name,
      );
      expect(
        ClipRef.tryParse(
          profile: profile,
          relPath: 'Profiles/$name/old/2024-01-05-2.mp4',
        )?.ordinal,
        2,
        reason: name,
      );
      expect(
        ClipRef.tryParse(profile: profile, relPath: 'Profiles/$name/'),
        isNull,
        reason: name,
      );
    }
    // Older installs accepted any profile name: a "Mom/Dad" profile shows
    // the clips of Profiles/Mom/Dad/.
    const ProfileKey momDad = ProfileKey('Mom/Dad');
    ClipRef? parse(String relPath) =>
        ClipRef.tryParse(profile: momDad, relPath: relPath);

    expect(parse('Profiles/Mom/Dad/2024-01-05.mp4')?.day, LocalDay(2024, 1, 5));
    expect(parse('Profiles/Mom/Dad/trip/2024-01-06.mp4'), isNotNull);
    expect(parse('Profiles/Mom/2024-01-05.mp4'), isNull);
    expect(parse('Profiles/Mom/Daddy/2024-01-05.mp4'), isNull);
  });
}
