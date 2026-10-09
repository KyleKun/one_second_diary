import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/media/ffmpeg_runner.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';

import '../../support/support.dart';
import '../../support/track_1a/late_session_id_ffmpeg_gateway.dart';

void main() {
  late FakeFfmpegGateway ffmpeg;
  late MemoryLogSink log;
  late FfmpegRunner runner;

  setUp(() {
    ffmpeg = FakeFfmpegGateway();
    log = MemoryLogSink();
    runner = FfmpegRunner(ffmpeg: ffmpeg, logger: memoryLogger(log));
  });

  test(
    'runs the argument list and completes when the session succeeds',
    () async {
      await runner.execute(<String>[
        '-i',
        'in.mp4',
        'out.mp4',
        '-y',
      ], job: 'save');

      expect(ffmpeg.executed, <List<String>>[
        <String>['-i', 'in.mp4', 'out.mp4', '-y'],
      ]);
    },
  );

  // ffmpeg-kit's fail stack trace is a stack trace, not the error: logged
  // as one, the bug report shows it where a reader looks for it.
  test(
    'a failed session logs its fail stack trace as the stack trace',
    () async {
      ffmpeg.executeResults.add(
        FakeFfmpegGateway.failure(
          logs: 'Error while processing',
          failStackTrace: '#0 FFmpegKitFlutterPlugin.execute',
        ),
      );

      await runner
          .execute(<String>['-i', 'in.mp4', 'out.mp4'], job: 'save')
          .then<void>((_) {}, onError: (Object _) {});

      expect(
        log.lines.single,
        allOf(
          contains('Stacktrace: #0 FFmpegKitFlutterPlugin.execute'),
          isNot(contains('Error: #0')),
        ),
      );
    },
  );

  // The end of the log (its last 30 lines) goes into the report; a short
  // log is kept whole.
  test('a failed session is a VideoProcessingException with its return code '
      'and the end of its log', () async {
    final String longLog = <String>[
      for (int line = 1; line <= 40; line++) 'line $line',
    ].join('\n');
    for (final (int code, String logs, String tail) in <(int, String, String)>[
      (
        234,
        longLog,
        <String>[
          for (int line = 11; line <= 40; line++) 'line $line',
        ].join('\n'),
      ),
      (1, 'No such file or directory\n', 'No such file or directory'),
    ]) {
      ffmpeg.executeResults.add(
        FakeFfmpegGateway.failure(returnCode: code, logs: logs),
      );

      await expectLater(
        runner.execute(<String>['-i', 'in.mp4', 'out.mp4'], job: 'save'),
        throwsA(
          isA<VideoProcessingException>()
              .having(
                (VideoProcessingException e) => e.returnCode,
                'code',
                code,
              )
              .having(
                (VideoProcessingException e) => e.logTail,
                'logTail',
                tail,
              ),
        ),
      );
    }
  });

  group('cancel', () {
    test('cancelling the token stops the running session', () async {
      ffmpeg.holdExecutions = true;
      final CancelToken token = CancelToken();
      final Future<void> running = runner.execute(
        <String>['-i', 'in.mp4', 'out.mp4'],
        job: 'save',
        cancelToken: token,
      );
      await pumpEventQueue();

      token.cancel();

      await expectLater(running, throwsA(isA<CancelledException>()));
      expect(ffmpeg.cancelledSessions, <int>[1]);
      expect(ffmpeg.heldSessions, isEmpty);
    });

    test('a cancel before the session id arrives stops the session as soon '
        'as its id is known', () async {
      final LateSessionIdFfmpegGateway late = LateSessionIdFfmpegGateway()
        ..holdExecutions = true;
      final FfmpegRunner lateRunner = FfmpegRunner(
        ffmpeg: late,
        logger: memoryLogger(log),
      );
      final CancelToken token = CancelToken();
      final Future<void> running = lateRunner.execute(
        <String>['-i', 'in.mp4', 'out.mp4'],
        job: 'save',
        cancelToken: token,
      );
      await pumpEventQueue();
      token.cancel();
      await pumpEventQueue();
      expect(late.heldSessions, <int>[1], reason: 'no id yet, still running');

      late.deliverSessionIds();

      await expectLater(running, throwsA(isA<CancelledException>()));
      expect(late.cancelledSessions, <int>[1]);
    });

    test('a token cancelled before the start runs no session', () async {
      final CancelToken token = CancelToken()..cancel();

      await expectLater(
        runner.execute(
          <String>['-i', 'in.mp4'],
          job: 'save',
          cancelToken: token,
        ),
        throwsA(isA<CancelledException>()),
      );
      expect(ffmpeg.executed, isEmpty);
    });
  });

  test('a probe returns what ffprobe printed; a failed one is a '
      'VideoProcessingException', () async {
    ffmpeg.probeResults
      ..add(FakeFfmpegGateway.success(output: 'audio\n'))
      ..add(FakeFfmpegGateway.failure(returnCode: 1));

    expect(
      await runner.probe(<String>['-v', 'quiet', 'clip.mp4'], job: 'probe'),
      'audio\n',
    );
    expect(ffmpeg.probed, <List<String>>[
      <String>['-v', 'quiet', 'clip.mp4'],
    ]);
    await expectLater(
      runner.probe(<String>['missing.mp4'], job: 'probe'),
      throwsA(
        isA<VideoProcessingException>().having(
          (VideoProcessingException e) => e.returnCode,
          'returnCode',
          1,
        ),
      ),
    );
  });
}
