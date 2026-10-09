import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/file_log_sink.dart';

import '../../support/support.dart';

void main() {
  late String path;

  setUp(() async {
    final Directory root = await createTempRoot();
    path = '${root.path}/2024-01-05_10-00-00.txt';
    await File(path).create();
  });

  test('flush puts every line written so far in the file, one per line, and '
      'a line written while a flush is in flight goes with the next', () async {
    final FileLogSink sink = FileLogSink.open(path);
    addTearDown(sink.close);
    sink
      ..write('[INFO] 2024-01-05 10:00:00.000: [APP] started')
      ..write('[ERROR] 2024-01-05 10:00:01.000: [SAVE] failed\nError: x');

    final Future<void> inFlight = sink.flush();
    sink.write('late');
    await inFlight;
    await sink.flush();

    expect(
      await File(path).readAsString(),
      '[INFO] 2024-01-05 10:00:00.000: [APP] started\n'
      '[ERROR] 2024-01-05 10:00:01.000: [SAVE] failed\nError: x\n'
      'late\n',
    );
  });

  test('never throws: a line written after close, or to a file that cannot '
      'be written, is dropped', () async {
    final FileLogSink closed = FileLogSink.open(path)..write('kept');
    await closed.close();
    closed.write('dropped');
    await closed.flush();
    expect(await File(path).readAsString(), 'kept\n');

    final FileLogSink unwritable = FileLogSink.open(
      '${File(path).parent.path}/missing-folder/log.txt',
    );
    addTearDown(unwritable.close);
    unwritable.write('lost');
    await unwritable.flush();
    unwritable.write('lost too');
    await unwritable.flush();
  });
}
