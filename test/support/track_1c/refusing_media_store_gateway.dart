import '../fakes/fake_media_store_gateway.dart';

/// [FakeMediaStoreGateway.onDisk], except that the media store refuses to
/// delete the files in [refusedDeletes] (absolute paths), as Android does
/// for a clip a previous install made until the user consents, and to
/// publish a file NAMED as one in [refusedPublishes] (the temp file carries
/// the destination's name), as it does when storage is full.
class RefusingMediaStoreGateway extends FakeMediaStoreGateway {
  RefusingMediaStoreGateway.onDisk(
    super.paths, {
    this.refusedDeletes = const <String>{},
    this.refusedPublishes = const <String>{},
  }) : super.onDisk();

  final Set<String> refusedDeletes;
  final Set<String> refusedPublishes;

  @override
  Future<bool> delete({required String absolutePath, required String album}) {
    if (refusedDeletes.contains(absolutePath)) deleteResults.addFirst(false);
    return super.delete(absolutePath: absolutePath, album: album);
  }

  @override
  Future<bool> publish({required String tempFilePath, required String album}) {
    final String name = tempFilePath.substring(
      tempFilePath.lastIndexOf('/') + 1,
    );
    if (refusedPublishes.contains(name)) publishResults.addFirst(false);
    return super.publish(tempFilePath: tempFilePath, album: album);
  }
}
