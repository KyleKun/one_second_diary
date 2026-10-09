import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/movies/domain/movie_entry.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

MovieEntry _movie(ProfileKey? profile) => MovieEntry(
  fileName: 'OSD-Movie-3-2025-12-31.mp4',
  title: '2025',
  profile: profile,
  clipCount: 340,
  from: LocalDay(2025, 1, 1),
  to: LocalDay(2025, 12, 31),
  createdAt: DateTime(2025, 12, 31, 21),
  durationMs: 680000,
);

/// The display names profiles have now; "Kids" was renamed "Children".
String? _displayNameOf(ProfileKey profile) => switch (profile.value) {
  '' => 'Default',
  'Kids' => 'Children',
  _ => null,
};

void main() {
  test('displayTitle (decision D3): a non-Default movie leads with its '
      "profile's CURRENT name, a deleted profile's with its key; Default and "
      'v1.x movies show the bare title', () {
    final Map<ProfileKey?, String> titles = <ProfileKey?, String>{
      const ProfileKey('Kids'): 'Children · 2025',
      const ProfileKey('Trip 2024'): 'Trip 2024 · 2025',
      ProfileKey.defaultProfile: '2025',
      null: '2025',
    };
    for (final MapEntry<ProfileKey?, String>(key: profile, value: title)
        in titles.entries) {
      expect(
        _movie(profile).displayTitle(_displayNameOf),
        title,
        reason: '$profile',
      );
    }
  });
}
