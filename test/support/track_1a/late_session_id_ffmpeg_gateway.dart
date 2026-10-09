import 'dart:async';

import 'package:one_second_diary/core/platform/ffmpeg_result.dart';
import 'package:one_second_diary/core/platform/ffmpeg_statistics.dart';

import '../fakes/fake_ffmpeg_gateway.dart';

/// A [FakeFfmpegGateway] that reports each session id only when
/// [deliverSessionIds] is called, as the real plugin does: the id is known
/// once `executeWithArgumentsAsync` returns, after an `await`, so a cancel
/// can arrive before it.
class LateSessionIdFfmpegGateway extends FakeFfmpegGateway {
  final List<void Function()> _pendingIds = <void Function()>[];

  /// Hands every session id held so far to its caller.
  void deliverSessionIds() {
    final List<void Function()> pending = List<void Function()>.of(_pendingIds);
    _pendingIds.clear();
    for (final void Function() deliver in pending) {
      deliver();
    }
  }

  @override
  Future<FfmpegResult> execute(
    List<String> arguments, {
    void Function(FfmpegStatistics statistics)? onStatistics,
    void Function(int sessionId)? onSessionId,
  }) => super.execute(
    arguments,
    onStatistics: onStatistics,
    onSessionId: (int id) => _pendingIds.add(() => onSessionId?.call(id)),
  );
}
