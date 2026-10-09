import 'dart:async';
import 'dart:io';

import '../fakes/fake_media_store_gateway.dart';

/// A [FakeMediaStoreGateway.onDisk] with the platform behaviours the shared
/// fake does not script, for `MediaPublisher`'s ordering and recovery rules.
///
/// - [strictFolders]: a publish into an album folder that does not exist is
///   refused, as a plain rename would fail on iOS (the shared fake creates
///   the folder).
/// - [beforePublish] runs first on every publish, so a test can look at the
///   disk as the platform finds it.
/// - [loseExistingOnRefusal]: a refused publish first deletes the file it
///   would have replaced, as Android's `saveFile` deletes the existing row
///   by name before its insert fails.
/// - [hangPublishes]: publishes never answer, as if the app were killed
///   during the call (after [beforePublish] ran).
class ScriptedMediaStoreGateway extends FakeMediaStoreGateway {
  ScriptedMediaStoreGateway.onDisk(super.paths) : super.onDisk();

  bool strictFolders = false;
  bool loseExistingOnRefusal = false;
  bool hangPublishes = false;
  void Function(String tempFilePath, String album)? beforePublish;

  @override
  Future<bool> publish({
    required String tempFilePath,
    required String album,
  }) async {
    beforePublish?.call(tempFilePath, album);
    if (hangPublishes) return Completer<bool>().future;
    if (strictFolders && !await Directory('$mediaRoot/$album').exists()) {
      calls.add(PublishCall(tempFilePath: tempFilePath, album: album));
      return false;
    }
    final bool refused = publishResults.isNotEmpty && !publishResults.first;
    if (refused && loseExistingOnRefusal) {
      final String name = tempFilePath.substring(
        tempFilePath.lastIndexOf('/') + 1,
      );
      final File existing = File('$mediaRoot/$album/$name');
      if (await existing.exists()) await existing.delete();
    }
    return super.publish(tempFilePath: tempFilePath, album: album);
  }
}
