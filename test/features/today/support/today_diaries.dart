import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../../shared/fakes/fake_profiles_repository.dart';

const ProfileKey todayDefault = ProfileKey.defaultProfile;
const ProfileKey todayTravel = ProfileKey('Travel');

/// Default (landscape) and Travel (portrait).
List<Profile> todayProfiles() => <Profile>[
  testProfile(),
  testProfile(key: todayTravel, orientation: VideoOrientation.portrait),
];

/// Clip [ordinal] of [day] in [profile], where the app keeps it.
ClipRef todayClip(ProfileKey profile, LocalDay day, {int ordinal = 1}) =>
    ClipRef(
      profile: profile,
      relPath:
          '${profile.isDefault ? '' : 'Profiles/${profile.value}/'}'
          '${ordinal == 1 ? day.fileStem : '${day.fileStem}-$ordinal'}.mp4',
    );

/// The version of every clip in [todayDiary].
const FileStamp todayStamp = FileStamp(sizeBytes: 8, modifiedMs: 0);

/// [profile]'s diary with [clipsPerDay] clips on each day.
ClipIndex todayDiary(ProfileKey profile, Map<LocalDay, int> clipsPerDay) =>
    ClipIndex(
      profile: profile,
      clips: <IndexedClip>[
        for (final MapEntry<LocalDay, int> day in clipsPerDay.entries)
          for (int ordinal = 1; ordinal <= day.value; ordinal++)
            IndexedClip(
              ref: todayClip(profile, day.key, ordinal: ordinal),
              stamp: todayStamp,
            ),
      ],
    );
