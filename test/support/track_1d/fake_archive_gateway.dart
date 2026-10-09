import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/archive_gateway.dart';

/// A zip made by a [FakeArchiveGateway]: what it would contain, read from
/// disk at the moment of the call.
final class FakeZip extends Equatable {
  const FakeZip({
    required this.sourceDir,
    required this.zipPath,
    required this.entries,
  });

  final String sourceDir;
  final String zipPath;

  /// File name → text content of every file directly inside [sourceDir].
  final Map<String, String> entries;

  @override
  List<Object?> get props => <Object?>[sourceDir, zipPath, entries];
}

/// An [ArchiveGateway] that records [zips] instead of compressing.
///
/// Like the plugin, it takes only the files directly inside the source
/// folder (sub-folders are skipped) and writes a file at the zip path, so
/// code that checks for the zip finds one. Throws [error] when set, before
/// writing anything.
class FakeArchiveGateway extends Fake implements ArchiveGateway {
  final List<FakeZip> zips = <FakeZip>[];
  Object? error;

  @override
  Future<void> zipFilesIn({
    required String sourceDir,
    required String zipPath,
  }) async {
    final Object? failure = error;
    if (failure != null) throw failure;
    final Map<String, String> entries = <String, String>{};
    await for (final FileSystemEntity entity in Directory(sourceDir).list()) {
      if (entity is File) {
        entries[entity.uri.pathSegments.last] = await entity.readAsString();
      }
    }
    zips.add(FakeZip(sourceDir: sourceDir, zipPath: zipPath, entries: entries));
    await File(zipPath).writeAsString('fake zip');
  }
}
