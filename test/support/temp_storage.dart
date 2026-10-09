import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_name_codec.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Bytes written into seeded files: small, non-empty, not a real video.
const List<int> fakeVideoBytes = <int>[0, 0, 0, 24, 102, 116, 121, 112];

/// A fresh temp folder, deleted (with its content) after the current test.
Future<Directory> createTempRoot([String prefix = 'osd_test_']) async {
  final Directory root = await Directory.systemTemp.createTemp(prefix);
  addTearDown(() async {
    try {
      await root.delete(recursive: true);
    } on FileSystemException {
      // Already gone.
    }
  });
  return root;
}

/// [AppPaths.forTest] in a fresh temp root, with the startup folders
/// (logs, videos, movies) created.
Future<AppPaths> createTestPaths() async {
  final AppPaths paths = AppPaths.forTest(await createTempRoot());
  await paths.createDirectories();
  return paths;
}

/// Writes clip [ordinal] of [day] for [profile] where the app keeps it
/// (`ClipNameCodec` name in `AppPaths.profileVideos`), or in [subFolder] of
/// that folder (a user-made sub-folder). Returns the file.
Future<File> seedClip(
  AppPaths paths,
  ProfileKey profile,
  LocalDay day, {
  int ordinal = 1,
  String subFolder = '',
  List<int> bytes = fakeVideoBytes,
}) {
  final String folder = subFolder.isEmpty
      ? paths.profileVideos(profile)
      : '${paths.profileVideos(profile)}$subFolder/';
  return _write('$folder${ClipNameCodec.format(day, ordinal: ordinal)}', bytes);
}

/// Writes any file at [relativeToVideos] (a movie, a temp, junk).
Future<File> seedFile(
  AppPaths paths,
  String relativeToVideos, {
  List<int> bytes = fakeVideoBytes,
}) => _write(paths.absoluteFromVideos(relativeToVideos), bytes);

Future<File> _write(String path, List<int> bytes) async {
  final File file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  return file;
}
