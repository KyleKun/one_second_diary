import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/media_job_queue.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';

import '../../support/support.dart';

void main() {
  late AppPaths paths;
  late MediaJobQueue queue;

  setUp(() async {
    paths = await createTestPaths();
    queue = MediaJobQueue(paths: paths, logger: memoryLogger(MemoryLogSink()));
  });

  test('runs jobs one at a time, in the order they were submitted', () async {
    final List<String> events = <String>[];
    final Completer<void> firstMayEnd = Completer<void>();
    final Completer<void> firstStarted = Completer<void>();
    Future<String> job(String name, [Future<void>? until]) =>
        queue.run((Directory scratch) async {
          events.add('start $name');
          if (!firstStarted.isCompleted) firstStarted.complete();
          await until;
          events.add('end $name');
          return name;
        });

    final Future<List<String>> all = Future.wait(<Future<String>>[
      job('save', firstMayEnd.future),
      job('probe'),
      job('movie'),
    ]);
    // Wait on state, not on event-loop turns: a job starts only after real
    // file IO (its scratch folder), which a loaded parallel run delays past
    // pumpEventQueue's turns.
    await firstStarted.future;
    await pumpEventQueue();
    expect(events, <String>['start save'], reason: 'the others wait');

    firstMayEnd.complete();

    expect(await all, <String>['save', 'probe', 'movie']);
    expect(events, <String>[
      'start save',
      'end save',
      'start probe',
      'end probe',
      'start movie',
      'end movie',
    ]);
  });

  test(
    'a failed job fails its own caller and the next job still runs',
    () async {
      final Future<void> failing = queue.run(
        (Directory scratch) async => throw StateError('ffmpeg crashed'),
      );
      final Future<String> next = queue.run((Directory scratch) async => 'ok');

      await expectLater(failing, throwsStateError);
      expect(await next, 'ok');
    },
  );

  test(
    'each job gets its own new scratch folder, deleted when it ends',
    () async {
      final List<Directory> folders = <Directory>[];
      Future<void> job({required bool fail}) => queue.run((
        Directory scratch,
      ) async {
        expect(scratch.existsSync(), isTrue);
        expect(scratch.path, startsWith('${paths.scratchDir}/'));
        File('${scratch.path}/date.txt').writeAsStringSync('5 January 2024');
        folders.add(scratch);
        if (fail) throw StateError('failed');
      });

      await job(fail: false);
      await expectLater(job(fail: true), throwsStateError);

      expect(folders[0].path, isNot(folders[1].path));
      expect(folders.where((Directory d) => d.existsSync()), isEmpty);
    },
  );
}
