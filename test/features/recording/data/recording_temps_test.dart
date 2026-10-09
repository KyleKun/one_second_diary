// The camera's own files: a recording the page does not keep (too short,
// interrupted, cancelled) is deleted at once instead of piling up in the
// camera plugin's temp folder.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/features/recording/data/recording_temps.dart';

import '../../../support/support.dart';

void main() {
  late MemoryLogSink log;
  late RecordingTemps temps;
  late Directory dir;

  setUp(() async {
    log = MemoryLogSink();
    temps = RecordingTemps(logger: memoryLogger(log));
    dir = await createTempRoot();
  });

  test('a recording that is not kept is deleted; one already gone is not '
      'an error, and says so in the log', () async {
    final File file = File('${dir.path}/REC_1.mp4')
      ..writeAsBytesSync(fakeVideoBytes);

    await temps.discard(file.path);
    expect(file.existsSync(), isFalse);
    expect(log.lines, isEmpty);

    await temps.discard(file.path);
    expect(log.lines.single, contains('[RECORDING]'));
  });
}
