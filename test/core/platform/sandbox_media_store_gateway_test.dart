import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/sandbox_media_store_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

import '../../support/support.dart';

void main() {
  late AppPaths paths;
  late MemoryLogSink log;
  late SandboxMediaStoreGateway gateway;

  setUp(() async {
    paths = await createTestPaths();
    log = MemoryLogSink();
    gateway = SandboxMediaStoreGateway(paths: paths, logger: memoryLogger(log));
  });

  Future<File> tempFile(String name, [String content = 'new']) async {
    final File file = File('${paths.scratchDir}/job/$name');
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
    return file;
  }

  test('publish moves the temp file into <media root>/<album>/<its name>, '
      'replacing a file of that name; a missing temp is a logged false, '
      'never a throw', () async {
    await seedClip(paths, ProfileKey.defaultProfile, LocalDay(2024, 1, 5));
    final File remuxed = await tempFile('2024-01-05.mp4', 'remuxed');
    expect(
      await gateway.publish(
        tempFilePath: remuxed.path,
        album: 'OneSecondDiary',
      ),
      isTrue,
    );
    expect(File('${paths.videos}2024-01-05.mp4').readAsStringSync(), 'remuxed');
    expect(remuxed.existsSync(), isFalse);

    final File work = await tempFile('2024-01-06.mp4');
    expect(
      await gateway.publish(
        tempFilePath: work.path,
        album: 'OneSecondDiary/Profiles/Work',
      ),
      isTrue,
    );
    expect(
      File('${paths.videos}Profiles/Work/2024-01-06.mp4').readAsStringSync(),
      'new',
    );
    expect(log.lines, isEmpty);

    expect(
      await gateway.publish(
        tempFilePath: '${paths.scratchDir}/job/2024-01-07.mp4',
        album: 'OneSecondDiary',
      ),
      isFalse,
    );
    expect(File('${paths.videos}2024-01-07.mp4').existsSync(), isFalse);
    expect(
      log.lines.single,
      startsWith(
        '[ERROR] 2024-01-05 10:00:00.000: [MediaGallery] Could not publish '
        '2024-01-07.mp4 into OneSecondDiary',
      ),
    );
  });

  test('delete unlinks the file, a file already gone counts as deleted, and '
      'a failure is a logged false, never a throw', () async {
    final File clip = await seedClip(
      paths,
      ProfileKey.defaultProfile,
      LocalDay(2024, 1, 5),
    );
    expect(
      await gateway.delete(absolutePath: clip.path, album: 'OneSecondDiary'),
      isTrue,
    );
    expect(clip.existsSync(), isFalse);
    expect(
      await gateway.delete(absolutePath: clip.path, album: 'OneSecondDiary'),
      isTrue,
    );
    expect(log.lines, isEmpty);

    // A folder where the clip should be: unlink fails, not "not found".
    final Directory folder = Directory('${paths.videos}2024-01-06.mp4');
    await folder.create();
    expect(
      await gateway.delete(absolutePath: folder.path, album: 'OneSecondDiary'),
      isFalse,
    );
    expect(folder.existsSync(), isTrue);
    expect(
      log.lines.single,
      startsWith(
        '[ERROR] 2024-01-05 10:00:00.000: [MediaGallery] Could not delete '
        '2024-01-06.mp4 from OneSecondDiary',
      ),
    );
  });
}
