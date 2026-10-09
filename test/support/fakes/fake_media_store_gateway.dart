import 'dart:collection';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/media_store_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

/// A call made to a [FakeMediaStoreGateway].
sealed class MediaStoreCall extends Equatable {
  const MediaStoreCall();
}

final class PublishCall extends MediaStoreCall {
  const PublishCall({required this.tempFilePath, required this.album});

  final String tempFilePath;
  final String album;

  @override
  List<Object?> get props => <Object?>[tempFilePath, album];
}

/// One [MediaStoreGateway.requestWrite]: the batch asked about.
final class WriteRequestCall extends MediaStoreCall {
  const WriteRequestCall(this.absolutePaths);

  final List<String> absolutePaths;

  @override
  List<Object?> get props => <Object?>[absolutePaths];
}

final class DeleteCall extends MediaStoreCall {
  const DeleteCall({required this.absolutePath, required this.album});

  final String absolutePath;
  final String album;

  @override
  List<Object?> get props => <Object?>[absolutePath, album];
}

/// A [MediaStoreGateway] that records [calls] in order and, when it has a
/// [mediaRoot], changes the disk the way iOS does: `publish` moves the temp
/// file to `<mediaRoot>/<album>/<temp file name>` (replacing a file with that
/// name) and `delete` removes the file.
///
/// [publishResults] / [deleteResults] script the next results (`false`
/// refuses the call and leaves the disk alone); empty means success.
class FakeMediaStoreGateway extends Fake implements MediaStoreGateway {
  /// Records calls only; the disk never changes.
  FakeMediaStoreGateway() : mediaRoot = null;

  /// Changes the disk under the folder holding `paths.videos` (the stand-in
  /// for DCIM / Documents in `AppPaths.forTest`).
  FakeMediaStoreGateway.onDisk(AppPaths paths)
    : mediaRoot = paths.videos.substring(
        0,
        paths.videos.length - AppPaths.folderName.length - 2,
      );

  final String? mediaRoot;

  final List<MediaStoreCall> calls = <MediaStoreCall>[];
  final Queue<bool> publishResults = Queue<bool>();
  final Queue<bool> deleteResults = Queue<bool>();

  /// The next answers of [requestWrite] (`false` declines the batch);
  /// empty means allowed.
  final Queue<bool> writeRequestResults = Queue<bool>();

  @override
  Future<bool> publish({
    required String tempFilePath,
    required String album,
  }) async {
    calls.add(PublishCall(tempFilePath: tempFilePath, album: album));
    if (!_next(publishResults)) return false;
    final String? root = mediaRoot;
    if (root != null) {
      final String name = tempFilePath.substring(
        tempFilePath.lastIndexOf('/') + 1,
      );
      final Directory folder = Directory('$root/$album');
      await folder.create(recursive: true);
      await File(tempFilePath).rename('${folder.path}/$name');
    }
    return true;
  }

  @override
  Future<bool> delete({
    required String absolutePath,
    required String album,
  }) async {
    calls.add(DeleteCall(absolutePath: absolutePath, album: album));
    if (!_next(deleteResults)) return false;
    if (mediaRoot != null) {
      try {
        await File(absolutePath).delete();
      } on FileSystemException {
        // Deleting a missing file succeeds, like the real gateway.
      }
    }
    return true;
  }

  @override
  Future<bool> requestWrite(List<String> absolutePaths) async {
    calls.add(WriteRequestCall(List<String>.unmodifiable(absolutePaths)));
    return _next(writeRequestResults);
  }

  static bool _next(Queue<bool> results) =>
      results.isEmpty || results.removeFirst();
}
