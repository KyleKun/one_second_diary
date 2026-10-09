// A clip's kept original travels with the clip: a
// publish MOVES the camera temp beside the diary under the clip's name, a
// replace trashes the old source in the same entry (and keeps the new one),
// a delete trashes both, Undo brings both back or removes both, and an
// unfinished write's source is put back at the next launch.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/features/clips/data/clip_trash.dart';
import 'package:one_second_diary/features/clips/data/media_publisher.dart';
import 'package:one_second_diary/features/clips/data/originals_store.dart';
import 'package:one_second_diary/features/clips/domain/undo_token.dart';

import '../../../support/support.dart';
import '../../../support/track_1b/scripted_media_store_gateway.dart';

const String _clip = 'Profiles/Work/2024-01-05.mp4';
const String _source = 'Profiles/Work/2024-01-05.mov';

void main() {
  late AppPaths paths;
  late MemoryLogSink sink;
  late ScriptedMediaStoreGateway gateway;
  late OriginalsStore originals;
  late MediaPublisher publisher;

  setUp(() async {
    paths = await createTestPaths();
    sink = MemoryLogSink();
    gateway = ScriptedMediaStoreGateway.onDisk(paths);
    originals = OriginalsStore(
      paths: paths,
      gateway: gateway,
      logger: memoryLogger(sink),
      isAndroid: true,
    );
    addTearDown(originals.dispose);
    publisher = MediaPublisher(
      gateway: gateway,
      paths: paths,
      logger: memoryLogger(sink),
      clock: FakeClock(DateTime(2024, 1, 5, 10)),
      originals: originals,
    );
  });

  /// A finished render in scratch, as the media engine leaves it.
  Future<String> render(List<int> bytes) async {
    final File file = File('${paths.scratchDir}/job/2024-01-05.mp4');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// A camera temp in the app's cache, as the camera leaves it.
  Future<String> recording(List<int> bytes, {String name = 'REC.mov'}) async {
    final File file = File('${paths.temporaryDir}/$name');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  File clipFile() => File(paths.absoluteFromVideos(_clip));

  File sourceFile([String original = _source]) =>
      File(originals.absoluteOf(original));

  List<FileSystemEntity> trashFiles() {
    final Directory trash = Directory(paths.trashDir);
    return trash.existsSync()
        ? trash.listSync(recursive: true).whereType<File>().toList()
        : const <FileSystemEntity>[];
  }

  test('publish moves the camera temp into the Originals folder under the '
      "clip's name with its own extension (the temp is gone, nothing is "
      'copied) and the store knows the source; without a source nothing is '
      'kept; Undo deletes the clip and its source', () async {
    final String temp = await recording(<int>[9, 9, 9]);

    final UndoToken? token = await publisher.publish(
      tempPath: await render(<int>[1]),
      relPath: _clip,
      sourcePath: temp,
    );

    expect(
      token,
      const PublishedUndo(relPath: _clip, keptSourceRelPath: _source),
    );
    expect(clipFile().readAsBytesSync(), <int>[1]);
    expect(sourceFile().readAsBytesSync(), <int>[9, 9, 9]);
    expect(File(temp).existsSync(), isFalse, reason: 'moved, not copied');
    expect(File('${paths.originals}${PathNames.noMedia}').existsSync(), isTrue);
    expect(originals.sourceRelPaths, <String>{_clip});
    expect(originals.sourcePathOf(_clip), sourceFile().path);
    expect(publisher.sourcePathOf(_clip), sourceFile().path);

    expect(await publisher.undo(token!), isTrue);
    expect(clipFile().existsSync(), isFalse);
    expect(sourceFile().existsSync(), isFalse);
    expect(originals.sourceRelPaths, isEmpty);

    // Without a source: a plain publish, nothing kept.
    final UndoToken? plain = await publisher.publish(
      tempPath: await render(<int>[2]),
      relPath: _clip,
    );
    expect(plain, const PublishedUndo(relPath: _clip));
    expect(originals.sourceRelPaths, isEmpty);
  });

  test('replace backs the old clip AND its old source up into the same '
      'trash entry, removes the old source, keeps the new one under the '
      'name; Undo brings the old clip and source back and removes the new '
      'source; purge forgets both', () async {
    await publisher.publish(
      tempPath: await render(<int>[1]),
      relPath: _clip,
      sourcePath: await recording(<int>[9]),
    );

    final UndoToken? token = await publisher.replace(
      tempPath: await render(<int>[2]),
      relPath: _clip,
      sourcePath: await recording(<int>[8, 8], name: 'REC2.mp4'),
      keepExistingSource: false,
    );

    final ReplacedUndo replaced = token! as ReplacedUndo;
    expect(replaced.keptSourceRelPath, 'Profiles/Work/2024-01-05.mp4');
    expect(clipFile().readAsBytesSync(), <int>[2]);
    expect(sourceFile().existsSync(), isFalse, reason: 'the old .mov went');
    expect(sourceFile('Profiles/Work/2024-01-05.mp4').readAsBytesSync(), <int>[
      8,
      8,
    ]);
    final String entry = '${paths.trashDir}/${replaced.trashId}';
    expect(File('$entry/$_clip').readAsBytesSync(), <int>[1]);
    expect(
      File('$entry/${ClipTrash.sourcesFolder}/$_source').readAsBytesSync(),
      <int>[9],
    );

    expect(await publisher.undo(token), isTrue);
    expect(clipFile().readAsBytesSync(), <int>[1]);
    expect(sourceFile().readAsBytesSync(), <int>[9]);
    expect(sourceFile('Profiles/Work/2024-01-05.mp4').existsSync(), isFalse);
    expect(originals.sourceRelPaths, <String>{_clip});
    expect(trashFiles(), isEmpty);

    // A replace whose snackbar went away: the old pair is gone for good.
    final UndoToken? again = await publisher.replace(
      tempPath: await render(<int>[3]),
      relPath: _clip,
      keepExistingSource: false,
    );
    expect(again!.keptSourceRelPath, isNull);
    expect(originals.sourceRelPaths, isEmpty, reason: 'no new source came');
    await publisher.purge(again);
    expect(trashFiles(), isEmpty);
    expect(clipFile().readAsBytesSync(), <int>[3]);
  });

  test('"Edit again", a privacy mark, a tags or subtitle edit: a replace '
      'that keeps the existing source (the default) leaves it where it is, '
      'still the clip\'s', () async {
    await publisher.publish(
      tempPath: await render(<int>[1]),
      relPath: _clip,
      sourcePath: await recording(<int>[9]),
    );

    final UndoToken? token = await publisher.replace(
      tempPath: await render(<int>[2]),
      relPath: _clip,
    );

    expect(token, isA<ReplacedUndo>());
    expect(clipFile().readAsBytesSync(), <int>[2]);
    expect(sourceFile().readAsBytesSync(), <int>[9]);
    expect(originals.sourceRelPaths, <String>{_clip});
    expect(trashFiles().map((FileSystemEntity f) => f.path), <String>[
      '${paths.trashDir}/${(token! as ReplacedUndo).trashId}/$_clip',
    ]);

    // Undo puts the old clip back; the source was never touched.
    expect(await publisher.undo(token), isTrue);
    expect(clipFile().readAsBytesSync(), <int>[1]);
    expect(sourceFile().readAsBytesSync(), <int>[9]);
  });

  test('delete trashes the clip and its source together; Undo restores '
      'both; a source that cannot be backed up (no trash entry) stays '
      'where it is, logged, never deleted without a way back', () async {
    await publisher.publish(
      tempPath: await render(<int>[1]),
      relPath: _clip,
      sourcePath: await recording(<int>[9]),
    );

    final UndoToken? token = await publisher.delete(_clip);

    expect(token, isA<DeletedUndo>());
    expect(clipFile().existsSync(), isFalse);
    expect(sourceFile().existsSync(), isFalse);
    expect(originals.sourceRelPaths, isEmpty);

    expect(await publisher.undo(token!), isTrue);
    expect(clipFile().readAsBytesSync(), <int>[1]);
    expect(sourceFile().readAsBytesSync(), <int>[9]);
    expect(originals.sourceRelPaths, <String>{_clip});
    expect(trashFiles(), isEmpty);

    // No room for a backup (a file where the trash folder goes): the clip
    // goes without Undo, the source stays.
    final Directory trash = Directory(paths.trashDir);
    if (trash.existsSync()) await trash.delete(recursive: true);
    await File(paths.trashDir).writeAsBytes(<int>[0]);
    final UndoToken? noRoom = await publisher.delete(_clip);
    expect(noRoom, const DeletedUndo(relPath: _clip, trashId: null));
    expect(clipFile().existsSync(), isFalse);
    expect(sourceFile().readAsBytesSync(), <int>[9]);
    expect(
      sink.lines.last,
      contains('The original of $_clip stays: it could not be backed up'),
    );
  });

  test('purgeTrash puts an unfinished write\'s clip AND source back where '
      'they are missing (the app died mid-replace), and drops a finished '
      'entry', () async {
    await publisher.publish(
      tempPath: await render(<int>[1]),
      relPath: _clip,
      sourcePath: await recording(<int>[9]),
    );
    // A replace whose publish never came back: the entry stays pending,
    // and the platform had already taken the old clip.
    gateway.hangPublishes = true;
    gateway.beforePublish = (String _, String _) {
      clipFile().deleteSync();
      sourceFile().deleteSync();
    };
    unawaited(
      publisher.replace(
        tempPath: await render(<int>[2]),
        relPath: _clip,
        sourcePath: await recording(<int>[8], name: 'REC2.mov'),
        keepExistingSource: false,
      ),
    );
    await pumpEventQueue();
    gateway
      ..hangPublishes = false
      ..beforePublish = null;
    expect(clipFile().existsSync(), isFalse);
    expect(sourceFile().existsSync(), isFalse);

    await publisher.purgeTrash();

    expect(clipFile().readAsBytesSync(), <int>[1]);
    expect(sourceFile().readAsBytesSync(), <int>[9]);
    expect(originals.sourceRelPaths, <String>{_clip});
    expect(trashFiles(), isEmpty);
  });
}
