import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_name_codec.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// The stamp every fixture clip is seen with.
const FileStamp diaryStamp = FileStamp(sizeBytes: 8, modifiedMs: 1000);

/// The clip [ordinal] of [day] in [profile]'s folder (`yyyy-MM-dd.mp4`,
/// then `-2`, `-3`, …).
ClipRef diaryClip(ProfileKey profile, LocalDay day, {int ordinal = 1}) =>
    ClipRef(
      profile: profile,
      relPath:
          '${profile.isDefault ? '' : 'Profiles/${profile.value}/'}'
          '${ClipNameCodec.format(day, ordinal: ordinal)}',
    );

/// A snapshot of [profile] with, for each day, that many clips.
ClipIndex diaryIndex(
  ProfileKey profile,
  Map<LocalDay, int> clipsPerDay, {
  FileStamp stamp = diaryStamp,
}) => ClipIndex(
  profile: profile,
  clips: <IndexedClip>[
    for (final MapEntry<LocalDay, int> day in clipsPerDay.entries)
      for (int ordinal = 1; ordinal <= day.value; ordinal++)
        IndexedClip(
          ref: diaryClip(profile, day.key, ordinal: ordinal),
          stamp: stamp,
        ),
  ],
);
