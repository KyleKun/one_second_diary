import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/cancel_token.dart';
import 'package:one_second_diary/core/platform/ffmpeg_gateway.dart';
import 'package:one_second_diary/core/platform/ffmpeg_result.dart';
import 'package:one_second_diary/core/platform/ffmpeg_statistics.dart';

/// Runs one ffmpeg or ffprobe session of a media job and turns its outcome
/// into the engine's contract: normal completion, a
/// [VideoProcessingException] carrying the return code and the end of the
/// log, or a [CancelledException].
final class FfmpegRunner {
  FfmpegRunner({required this._ffmpeg, required this._logger});

  /// How many of the last log lines a failure keeps, for the local log and
  /// the "Report error" email.
  static const int logTailLines = 30;

  static const String _tag = 'ffmpeg';

  final FfmpegGateway _ffmpeg;
  final AppLogger _logger;

  /// Runs ffmpeg with [arguments] for [job] (named in the log). With
  /// [output], a session that ends without writing that file (or writes it
  /// empty) is a failure too: a caller must never publish an empty clip.
  ///
  /// Cancelling [cancelToken] stops the session through
  /// `FfmpegGateway.cancel` (even when the cancel comes before the session
  /// id is known) and throws a [CancelledException]; so does a token that
  /// is cancelled while the session ends successfully.
  Future<void> execute(
    List<String> arguments, {
    required String job,
    String? output,
    CancelToken? cancelToken,
    void Function(FfmpegStatistics statistics)? onStatistics,
  }) async {
    final FfmpegResult result = await _run(
      arguments,
      job: job,
      cancelToken: cancelToken,
      onStatistics: onStatistics,
    );
    if (!result.success) _fail(job, result);
    if (output != null && !await _isWritten(output)) {
      _fail('$job wrote no output', result);
    }
  }

  /// Runs ffmpeg with [arguments] for [job] and returns its result when
  /// ffmpeg itself ran, whether it succeeded or failed: for a caller that
  /// reads an ffmpeg failure as an answer (no subtitle stream).
  ///
  /// A session without a return code never ran ffmpeg to the end (a plugin
  /// error, `FfmpegKitGateway.failedToStart`) and is a
  /// [VideoProcessingException]; a cancelled one (the session's own, or
  /// [cancelToken]'s, which stops the session as in [execute]) is a
  /// [CancelledException]. Neither is an answer from ffmpeg.
  Future<FfmpegResult> attempt(
    List<String> arguments, {
    required String job,
    CancelToken? cancelToken,
  }) async {
    final FfmpegResult result = await _run(
      arguments,
      job: job,
      cancelToken: cancelToken,
    );
    if (result.returnCode == null) _fail(job, result);
    return result;
  }

  /// One session of [arguments], stopped through `FfmpegGateway.cancel`
  /// when [cancelToken] is cancelled (even before the session id is
  /// known); a session that was cancelled, or whose token is cancelled by
  /// the time it ends, is a [CancelledException].
  Future<FfmpegResult> _run(
    List<String> arguments, {
    required String job,
    required CancelToken? cancelToken,
    void Function(FfmpegStatistics statistics)? onStatistics,
  }) async {
    cancelToken?.throwIfCancelled();
    int? sessionId;
    bool ended = false;
    void stopSession() {
      final int? id = sessionId;
      if (id != null && !ended) unawaited(_cancel(id));
    }

    unawaited(cancelToken?.whenCancelled.then((_) => stopSession()));
    final FfmpegResult result = await _ffmpeg.execute(
      arguments,
      onStatistics: onStatistics,
      onSessionId: (int id) {
        sessionId = id;
        // The real id arrives after an await: a cancel may already be in.
        if (cancelToken?.isCancelled ?? false) stopSession();
      },
    );
    ended = true;
    if (result.cancelled || (cancelToken?.isCancelled ?? false)) {
      _cancelled(job);
    }
    return result;
  }

  static Future<bool> _isWritten(String path) async =>
      (await FileStat.stat(path)).size > 0;

  /// Runs ffprobe with [arguments] for [job] and returns what it printed.
  Future<String> probe(List<String> arguments, {required String job}) async {
    final FfmpegResult result = await _ffmpeg.probe(arguments);
    if (!result.success) _fail(job, result);
    return result.output;
  }

  Future<void> _cancel(int sessionId) async {
    try {
      await _ffmpeg.cancel(sessionId);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not cancel session $sessionId',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Never _cancelled(String job) {
    _logger.info(_tag, '$job cancelled');
    throw CancelledException('$job cancelled');
  }

  Never _fail(String job, FfmpegResult result) {
    final String tail = _tail(result.logs);
    final String? failStackTrace = result.failStackTrace;
    _logger.error(
      _tag,
      '$job failed with return code ${result.returnCode}\n$tail',
      stackTrace: failStackTrace == null
          ? null
          : StackTrace.fromString(failStackTrace),
    );
    throw VideoProcessingException(
      '$job failed',
      returnCode: result.returnCode,
      logTail: tail,
    );
  }

  static String _tail(String logs) {
    final List<String> lines = logs.trimRight().split('\n');
    return lines.skip(max(0, lines.length - logTailLines)).join('\n');
  }
}
