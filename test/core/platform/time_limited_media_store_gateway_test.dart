import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/time_limited_media_store_gateway.dart';

import '../../support/support.dart';

void main() {
  late FakeMediaStoreGateway inner;
  late MemoryLogSink log;
  late TimeLimitedMediaStoreGateway gateway;

  setUp(() {
    inner = FakeMediaStoreGateway();
    log = MemoryLogSink();
    gateway = TimeLimitedMediaStoreGateway(
      inner: inner,
      timeLimit: const Duration(seconds: 30),
      logger: memoryLogger(log),
    );
  });

  test('passes every call on and returns its answer', () async {
    inner.deleteResults.add(false);

    final bool published = await gateway.publish(
      tempFilePath: '/scratch/2024-01-05.mp4',
      album: 'OneSecondDiary',
    );
    final bool deleted = await gateway.delete(
      absolutePath: '/DCIM/OneSecondDiary/2024-01-06.mp4',
      album: 'OneSecondDiary',
    );

    expect(published, isTrue);
    expect(deleted, isFalse);
    expect(inner.calls, const <MediaStoreCall>[
      PublishCall(
        tempFilePath: '/scratch/2024-01-05.mp4',
        album: 'OneSecondDiary',
      ),
      DeleteCall(
        absolutePath: '/DCIM/OneSecondDiary/2024-01-06.mp4',
        album: 'OneSecondDiary',
      ),
    ]);
  });

  test('a call with no answer within the time limit is a logged false, so '
      'the caller can finish', () {
    fakeAsync((FakeAsync async) {
      final _NeverAnswers never = _NeverAnswers();
      gateway = TimeLimitedMediaStoreGateway(
        inner: never,
        timeLimit: const Duration(seconds: 30),
        logger: memoryLogger(log),
      );
      bool? published;
      bool? deleted;

      unawaited(
        gateway
            .publish(
              tempFilePath: '/scratch/2024-01-05.mp4',
              album: 'OneSecondDiary',
            )
            .then((bool result) => published = result),
      );
      unawaited(
        gateway
            .delete(
              absolutePath: '/DCIM/OneSecondDiary/Profiles/Work/2024-01-06.mp4',
              album: 'OneSecondDiary/Profiles/Work',
            )
            .then((bool result) => deleted = result),
      );
      async.elapse(const Duration(seconds: 29));
      final (bool?, bool?) before = (published, deleted);
      async.elapse(const Duration(seconds: 1));

      expect(before, (null, null));
      expect((published, deleted), (false, false));
      expect(log.lines, <String>[
        '[ERROR] 2024-01-05 10:00:00.000: [MediaGallery] No answer within '
            '30 s publishing 2024-01-05.mp4 into OneSecondDiary; reported as '
            'not done',
        '[ERROR] 2024-01-05 10:00:00.000: [MediaGallery] No answer within '
            '30 s deleting 2024-01-06.mp4 from OneSecondDiary/Profiles/Work; '
            'reported as not done',
      ]);
    });
  });
}

/// The fork's native failures: the call is never answered.
class _NeverAnswers extends FakeMediaStoreGateway {
  @override
  Future<bool> publish({required String tempFilePath, required String album}) =>
      Completer<bool>().future;

  @override
  Future<bool> delete({required String absolutePath, required String album}) =>
      Completer<bool>().future;
}
