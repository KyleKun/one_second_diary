import 'dart:convert';
import 'dart:io';

import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_meta_sidecar.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/stamped_clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/movies/domain/movie_file_name.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../support/support.dart';

/// Seeding helpers for journeys and performance tests, on top of
/// `seedClip` / `seedFile` (`test/support/temp_storage.dart`). Pass them as
/// the `seed:` of `AppRobot.launch`; the profile helpers also give the
/// preferences to launch with.
///
/// ```dart
/// final List<ProfileSeed> trip = <ProfileSeed>[
///   const ProfileSeed('Trip', orientation: 'portrait', withPhoto: true),
/// ];
/// final AppRobot app = await AppRobot.launch(
///   tester,
///   prefs: prefsWithProfiles(trip, selected: 1),
///   seed: (AppPaths paths) async {
///     await seedProfilePhotos(paths, trip);
///     await seedDayClips(paths, ProfileKey.defaultProfile, day, count: 3);
///   },
/// );
/// ```

/// A 1×1 PNG: a real image, so a profile photo decodes.
const List<int> onePixelPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0, //
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, //
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
];

/// Clips 1 to [count] of [day] for [profile] (`yyyy-MM-dd.mp4`, then
/// `-2`, `-3`, …). Returns the files, in ordinal order.
Future<List<File>> seedDayClips(
  AppPaths paths,
  ProfileKey profile,
  LocalDay day, {
  required int count,
}) async => <File>[
  for (int ordinal = 1; ordinal <= count; ordinal++)
    await seedClip(paths, profile, day, ordinal: ordinal),
];

/// One clip a day for [days] days in a row, ending on [lastDay]: a diary
/// years long (1 000+ clips for the performance tests of the Diary and the
/// movie picker), written in parallel batches.
Future<void> seedManyClips(
  AppPaths paths,
  ProfileKey profile, {
  required LocalDay lastDay,
  required int days,
}) async {
  const int batch = 64;
  for (int start = 0; start < days; start += batch) {
    await Future.wait(<Future<File>>[
      for (int i = start; i < days && i < start + batch; i++)
        seedClip(paths, profile, lastDay.addDays(-i)),
    ]);
  }
}

/// A movie in `Movies/` (or in its user-made [subFolder]):
/// `OSD-Movie-<number>-<day>.mp4`. Returns the file.
Future<File> seedMovie(
  AppPaths paths, {
  required int number,
  required LocalDay day,
  String subFolder = '',
}) {
  final String name = MovieFileName.format(number: number, day: day);
  return seedFile(
    paths,
    subFolder.isEmpty ? 'Movies/$name' : 'Movies/$subFolder/$name',
  );
}

/// A named profile to seed: its folder key, its canvas, and optionally a
/// display name and a photo.
final class ProfileSeed {
  const ProfileSeed(
    this.key, {
    this.orientation = 'landscape',
    this.displayName,
    this.withPhoto = false,
  });

  /// The folder name under `Profiles/`.
  final String key;

  /// `landscape` or `portrait`.
  final String orientation;
  final String? displayName;
  final bool withPhoto;

  /// Where its photo lives, relative to `AppPaths.internal`.
  String get photoRelPath => 'avatars/seed-$key.png';
}

/// The preferences of an onboarded install with a landscape Default
/// profile and the [named] profiles, [selected] active (0 is Default),
/// with the profile metadata for display names and photos. [extra] adds
/// any other key, as `legacyPrefs` does.
Map<String, Object> prefsWithProfiles(
  List<ProfileSeed> named, {
  int selected = 0,
  String defaultOrientation = 'landscape',
  Map<String, Object> extra = const <String, Object>{},
}) {
  final Map<String, Object> meta = <String, Object>{
    for (final ProfileSeed profile in named)
      if (profile.displayName != null || profile.withPhoto)
        profile.key: <String, String>{
          'displayName': ?profile.displayName,
          if (profile.withPhoto) 'avatarRelPath': profile.photoRelPath,
        },
  };
  return legacyPrefs(
    profiles: <String>['Default', for (final ProfileSeed p in named) p.key],
    selectedProfileIndex: selected,
    orientations: <String, String>{
      '': defaultOrientation,
      for (final ProfileSeed p in named) p.key: p.orientation,
    },
    extra: <String, Object>{
      if (meta.isNotEmpty) 'profileMeta': jsonEncode(meta),
      ...extra,
    },
  );
}

/// Writes the photo of every [profiles] entry that has one.
Future<void> seedProfilePhotos(
  AppPaths paths,
  List<ProfileSeed> profiles,
) async {
  for (final ProfileSeed profile in profiles.where((p) => p.withPhoto)) {
    final File photo = File('${paths.internal}/${profile.photoRelPath}');
    await photo.parent.create(recursive: true);
    await photo.writeAsBytes(onePixelPng);
  }
}

/// Writes the metadata cache's file (`ClipMetadataCache.fileName`) with
/// [byRelPath]'s facts for clips already seeded (paths relative to the
/// videos folder), stamped as they are on disk now: what the backfill
/// leaves after probing them, so the Diary's captions, the viewer's place
/// and the subtitle sheet read them without ffmpeg.
Future<void> seedClipMeta(
  AppPaths paths,
  Map<String, ClipMeta> byRelPath,
) async {
  final File file = File(
    '${paths.supportIndexDir}/${ClipMetadataCache.fileName}',
  );
  await file.parent.create(recursive: true);
  await file.writeAsString(
    ClipMetaSidecar.encode(<String, StampedClipMeta>{
      for (final MapEntry<String, ClipMeta> entry in byRelPath.entries)
        entry.key: StampedClipMeta(
          stamp: await _stampOf(paths.absoluteFromVideos(entry.key)),
          meta: entry.value,
        ),
    }),
  );
}

Future<FileStamp> _stampOf(String path) async {
  final FileStat stat = await FileStat.stat(path);
  return FileStamp(
    sizeBytes: stat.size,
    modifiedMs: stat.modified.millisecondsSinceEpoch,
  );
}
