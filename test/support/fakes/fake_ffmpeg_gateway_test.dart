import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/ffmpeg_result.dart';

import 'fake_ffmpeg_gateway.dart';

void main() {
  // The renderers read ffmpeg-kit's outcomes: return code 0 is a success,
  // 255 (ReturnCode.CANCEL) a cancelled session. The fake must answer in the
  // same codes, or every cancel and failure test passes for the wrong reason.
  test(
    'the fake answers in ffmpeg-kit return codes: queued results in '
    'order, then success, and a cancelled session ends with CANCEL',
    () async {
      final FakeFfmpegGateway ffmpeg = FakeFfmpegGateway()
        ..executeResults.add(FakeFfmpegGateway.failure(returnCode: 1));

      final FfmpegResult failed = await ffmpeg.execute(<String>['a']);
      final FfmpegResult succeeded = await ffmpeg.execute(<String>['b']);
      expect((failed.returnCode, failed.success), (1, false));
      expect((succeeded.returnCode, succeeded.success), (0, true));
      expect(ffmpeg.executed, <List<String>>[
        <String>['a'],
        <String>['b'],
      ]);

      ffmpeg.holdExecutions = true;
      int? sessionId;
      final Future<FfmpegResult> running = ffmpeg.execute(<String>[
        'long',
      ], onSessionId: (int id) => sessionId = id);
      await pumpEventQueue();
      await ffmpeg.cancel(sessionId!);

      final FfmpegResult cancelled = await running;
      expect(cancelled.returnCode, FfmpegResult.cancelCode);
      expect(cancelled.cancelled, isTrue);
    },
  );
}
