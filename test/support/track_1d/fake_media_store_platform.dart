import 'dart:async';
import 'dart:io';

import 'package:media_store_plus/media_store_platform_interface.dart';
import 'package:media_store_plus/media_store_plus.dart';

/// The `media_store_plus` platform, scripted, to test `MediaStorePlusGateway`
/// on the host with the plugin's real Dart `MediaStore` class in front of
/// it. It extends the platform class because the plugin checks its token
/// when an instance is set.
///
/// [calls] records every call that reached the platform, in order, as
/// `<method> <arguments>` (the SDK level query is left out). Results are
/// scripted per method; a non-null `…Error` is thrown instead.
class FakeMediaStorePlatform extends MediaStorePlatform {
  int sdkInt = 33;
  final List<String> calls = <String>[];

  bool saveResult = true;
  Object? saveError;

  /// When set, `saveFile` answers only once it completes: a consent prompt
  /// the user has not answered yet, or a native failure the fork never
  /// answers (when it never completes).
  Completer<void>? holdSave;

  /// The native side of Android 10+ deletes the temp file itself after a
  /// successful save (`MediaStorePlusPlugin.kt` `saveFile`).
  bool removesTempOnSave = false;

  bool deleteResult = true;
  Object? deleteError;

  /// What the index lists under a name in an album (`getFileUri`): null
  /// means nothing, as for a file the index lost track of.
  Uri? indexedUri;
  Object? indexedError;

  Uri? scannedUri = Uri.parse('content://media/external/video/media/42');
  bool deleteUsingUriResult = true;
  Object? deleteUsingUriError;

  @override
  Future<int> getPlatformSDKInt() async => sdkInt;

  @override
  Future<bool> saveFile({
    required String tempFilePath,
    required String fileName,
    required DirType dirType,
    required DirName dirName,
    required String relativePath,
  }) async {
    calls.add(
      'saveFile $tempFilePath as $fileName in ${dirName.folder}/$relativePath '
      '(${dirType.name})',
    );
    await holdSave?.future;
    if (saveError case final Object error) throw error;
    if (saveResult && removesTempOnSave) await File(tempFilePath).delete();
    return saveResult;
  }

  @override
  Future<bool> deleteFile({
    required String fileName,
    required DirType dirType,
    required DirName dirName,
    required String relativePath,
  }) async {
    calls.add(
      'deleteFile $fileName in ${dirName.folder}/$relativePath '
      '(${dirType.name})',
    );
    if (deleteError case final Object error) throw error;
    return deleteResult;
  }

  @override
  Future<Uri?> getFileUri({
    required String fileName,
    required DirType dirType,
    required DirName dirName,
    required String relativePath,
  }) async {
    calls.add(
      'getFileUri $fileName in ${dirName.folder}/$relativePath '
      '(${dirType.name})',
    );
    if (indexedError case final Object error) throw error;
    return indexedUri;
  }

  @override
  Future<Uri?> getUriFromFilePath({required String path}) async {
    calls.add('getUriFromFilePath $path');
    return scannedUri;
  }

  @override
  Future<bool> deleteFileUsingUri({
    required String uriString,
    required bool forceUseMediaStore,
  }) async {
    calls.add(
      'deleteFileUsingUri $uriString forceUseMediaStore=$forceUseMediaStore',
    );
    if (deleteUsingUriError case final Object error) throw error;
    return deleteUsingUriResult;
  }
}
