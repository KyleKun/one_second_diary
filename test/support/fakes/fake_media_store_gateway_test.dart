import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/media_store_gateway.dart';
import 'package:one_second_diary/core/platform/sandbox_media_store_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

import '../memory_log_sink.dart';
import '../temp_storage.dart';
import 'fake_media_store_gateway.dart';

void main() {
  // The on-disk fake stands in for the gallery in every save and delete
  // test, so it must change the disk exactly as the real by-path gateway
  // (iOS, and Android 9 and older) does.
  test('the on-disk fake publishes and deletes like the real by-path '
      'gateway, and a refusal leaves the disk alone', () async {
    final gateways = <String, MediaStoreGateway Function(AppPaths paths)>{
      'SandboxMediaStoreGateway': (paths) => SandboxMediaStoreGateway(
        paths: paths,
        logger: memoryLogger(MemoryLogSink()),
      ),
      'FakeMediaStoreGateway.onDisk': FakeMediaStoreGateway.onDisk,
    };

    for (final MapEntry(key: name, value: build) in gateways.entries) {
      final AppPaths paths = await createTestPaths();
      final MediaStoreGateway store = build(paths);
      Future<File> scratchFile(String fileName, String content) async {
        final File file = File('${paths.scratchDir}/job1/$fileName');
        await file.parent.create(recursive: true);
        await file.writeAsString(content);
        return file;
      }

      // Publish moves the temp file into the album under its own name.
      final File first = await scratchFile('2024-01-05.mp4', 'first');
      expect(
        await store.publish(
          tempFilePath: first.path,
          album: 'OneSecondDiary/Profiles/Work',
        ),
        isTrue,
        reason: name,
      );
      final File published = File(
        '${paths.videos}Profiles/Work/2024-01-05.mp4',
      );
      expect(first.existsSync(), isFalse, reason: name);
      expect(published.readAsStringSync(), 'first', reason: name);

      // A file with the same name is replaced.
      final File second = await scratchFile('2024-01-05.mp4', 'second');
      await store.publish(
        tempFilePath: second.path,
        album: 'OneSecondDiary/Profiles/Work',
      );
      expect(published.readAsStringSync(), 'second', reason: name);

      // Delete unlinks; a file already gone counts as deleted.
      for (var i = 0; i < 2; i++) {
        expect(
          await store.delete(
            absolutePath: published.path,
            album: 'OneSecondDiary/Profiles/Work',
          ),
          isTrue,
          reason: '$name delete #$i',
        );
        expect(published.existsSync(), isFalse, reason: name);
      }
    }

    // A refused call (a failure or a declined consent prompt) is false and
    // keeps the temp file and the clip.
    final AppPaths paths = await createTestPaths();
    final FakeMediaStoreGateway refusing = FakeMediaStoreGateway.onDisk(paths)
      ..publishResults.add(false)
      ..deleteResults.add(false);
    final File temp = File('${paths.scratchDir}/job1/2024-01-05.mp4');
    await temp.parent.create(recursive: true);
    await temp.writeAsString('new');
    final File clip = await seedFile(paths, '2024-01-06.mp4');

    expect(
      await refusing.publish(tempFilePath: temp.path, album: 'OneSecondDiary'),
      isFalse,
    );
    expect(
      await refusing.delete(absolutePath: clip.path, album: 'OneSecondDiary'),
      isFalse,
    );
    expect(temp.existsSync(), isTrue);
    expect(clip.existsSync(), isTrue);
  });
}
