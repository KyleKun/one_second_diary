import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_name_codec.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/indexed_clip.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// A snapshot of [profile] with one clip on each of [days], where the app
/// keeps them (`Profiles/<key>/` for a named profile).
ClipIndex clipIndexOf(ProfileKey profile, List<LocalDay> days) => ClipIndex(
  profile: profile,
  clips: <IndexedClip>[
    for (final LocalDay day in days)
      IndexedClip(
        ref: ClipRef(
          profile: profile,
          relPath:
              '${profile.isDefault ? '' : 'Profiles/${profile.value}/'}'
              '${ClipNameCodec.format(day)}',
        ),
        stamp: const FileStamp(sizeBytes: 8, modifiedMs: 0),
      ),
  ],
);
