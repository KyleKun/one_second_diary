import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/shared_wakelock.dart';

import '../../support/support.dart';

void main() {
  // The movie job, the movie player, the clip editor's save, the camera and the folder
  // migration share one hold.
  test('the screen stays on while anyone holds it, and a release nobody '
      'holds changes nothing', () async {
    final FakeWakelockGateway platform = FakeWakelockGateway();
    final SharedWakelock wakelock = SharedWakelock(platform: platform);

    await wakelock.disable(); // nobody holds it yet
    expect(platform.enabled, isFalse);

    await wakelock.enable(); // the movie job
    await wakelock.enable(); // the player
    await wakelock.disable(); // the player paused
    expect(platform.enabled, isTrue, reason: 'the job still holds it');

    await wakelock.disable(); // the job ended
    expect(platform.enabled, isFalse);
  });
}
