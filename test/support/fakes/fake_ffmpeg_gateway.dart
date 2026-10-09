import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/ffmpeg_gateway.dart';
import 'package:one_second_diary/core/platform/ffmpeg_result.dart';
import 'package:one_second_diary/core/platform/ffmpeg_statistics.dart';

/// A scriptable [FfmpegGateway].
///
/// - Records every argument list ([executed], [probed]) for argv goldens.
/// - Returns [executeResults] / [probeResults] in order, then success.
/// - Calls [onExecute] (e.g. to create the output file) and emits
///   [statistics] during every `execute`.
/// - With [holdExecutions], `execute` stays pending until [cancel] (which
///   completes it as cancelled) or [releaseHeld].
class FakeFfmpegGateway extends Fake implements FfmpegGateway {
  static FfmpegResult success({String output = '', String logs = ''}) =>
      FfmpegResult(
        returnCode: 0,
        output: output,
        logs: logs,
        failStackTrace: null,
      );

  static FfmpegResult failure({
    int returnCode = 1,
    String logs = 'Error while processing',
    String? failStackTrace,
  }) => FfmpegResult(
    returnCode: returnCode,
    output: '',
    logs: logs,
    failStackTrace: failStackTrace,
  );

  /// A cancelled result (ffmpeg-kit return code 255).
  static FfmpegResult cancelledResult() => const FfmpegResult(
    returnCode: FfmpegResult.cancelCode,
    output: '',
    logs: '',
    failStackTrace: null,
  );

  /// Arguments of every `execute`, in call order.
  final List<List<String>> executed = <List<String>>[];

  /// Arguments of every `probe`, in call order.
  final List<List<String>> probed = <List<String>>[];

  /// Session ids passed to `cancel`, in call order.
  final List<int> cancelledSessions = <int>[];

  /// Folders passed to `setFontDirectory`, in call order.
  final List<String> fontDirectories = <String>[];

  /// Results of the next `execute` calls; empty means success.
  final Queue<FfmpegResult> executeResults = Queue<FfmpegResult>();

  /// Results of the next `probe` calls; empty means success.
  final Queue<FfmpegResult> probeResults = Queue<FfmpegResult>();

  /// Samples passed to `onStatistics` during every `execute`.
  List<FfmpegStatistics> statistics = const <FfmpegStatistics>[];

  /// Runs during every `execute`, before it completes.
  Future<void> Function(List<String> arguments)? onExecute;

  /// What `listEncoders` returns.
  String encodersOutput = '';

  /// Keeps every new `execute` pending until [cancel] or [releaseHeld].
  bool holdExecutions = false;

  int _nextSessionId = 1;
  final Map<int, Completer<FfmpegResult>> _held =
      <int, Completer<FfmpegResult>>{};

  /// Ids of the sessions currently held.
  List<int> get heldSessions => _held.keys.toList();

  /// Completes every held session with the next queued result (or success).
  void releaseHeld() {
    final List<Completer<FfmpegResult>> held = _held.values.toList();
    _held.clear();
    for (final Completer<FfmpegResult> completer in held) {
      completer.complete(_next(executeResults));
    }
  }

  @override
  Future<FfmpegResult> execute(
    List<String> arguments, {
    void Function(FfmpegStatistics statistics)? onStatistics,
    void Function(int sessionId)? onSessionId,
  }) async {
    executed.add(List<String>.unmodifiable(arguments));
    final int sessionId = _nextSessionId++;
    final Completer<FfmpegResult>? held = holdExecutions
        ? Completer<FfmpegResult>()
        : null;
    if (held != null) _held[sessionId] = held;
    onSessionId?.call(sessionId);
    await onExecute?.call(arguments);
    if (onStatistics != null) statistics.forEach(onStatistics);
    return held?.future ?? _next(executeResults);
  }

  @override
  Future<FfmpegResult> probe(List<String> arguments) async {
    probed.add(List<String>.unmodifiable(arguments));
    return _next(probeResults);
  }

  @override
  Future<void> cancel(int sessionId) async {
    cancelledSessions.add(sessionId);
    _held.remove(sessionId)?.complete(cancelledResult());
  }

  @override
  Future<void> setFontDirectory(String path) async {
    fontDirectories.add(path);
  }

  @override
  Future<String> listEncoders() async => encodersOutput;

  static FfmpegResult _next(Queue<FfmpegResult> queue) =>
      queue.isEmpty ? success() : queue.removeFirst();
}
