import 'dart:async';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_session.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/session.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:flutter/foundation.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/platform/ffmpeg_gateway.dart';
import 'package:one_second_diary/core/platform/ffmpeg_result.dart';
import 'package:one_second_diary/core/platform/ffmpeg_statistics.dart';

/// [FfmpegGateway] over `ffmpeg_kit_flutter_new`.
///
/// This is the ONLY file that imports the plugin (a guard test pins it):
/// swapping the GPL build for the LGPL one, for the App Store, is an import
/// change here.
///
/// Every command goes in as an argument list (`executeWithArguments…`), never
/// a string: a string goes through `FFmpegKitConfig.parseArguments`, which
/// splits unquoted paths at the space of iOS `Application Support`.
final class FfmpegKitGateway implements FfmpegGateway {
  /// The gateway over the real plugin.
  FfmpegKitGateway() : _registerFonts = FFmpegKitConfig.setFontDirectory;

  /// A gateway whose font registration goes to `registerFonts` instead of
  /// the plugin, to pin the mapping it is given (see [setFontDirectory]).
  @visibleForTesting
  FfmpegKitGateway.withFontRegistrar({required this._registerFonts});

  final Future<void> Function(String path, Map<String, String>? mapping)
  _registerFonts;

  /// Runs ffmpeg with `executeWithArgumentsAsync` and completes from the
  /// session's complete callback, so statistics arrive while it runs.
  ///
  /// The session id is only known once the plugin call returns, which can be
  /// AFTER the session completed; [onSessionId] is still called then. A
  /// plugin error (a `PlatformException` while starting or reading the
  /// session) completes as a failed result: this method never throws. A
  /// success carries neither output nor logs ([resultOf]).
  @override
  Future<FfmpegResult> execute(
    List<String> arguments, {
    void Function(FfmpegStatistics statistics)? onStatistics,
    void Function(int sessionId)? onSessionId,
  }) async {
    final Completer<FfmpegResult> done = Completer<FfmpegResult>();
    try {
      final FFmpegSession session = await FFmpegKit.executeWithArgumentsAsync(
        arguments,
        (FFmpegSession session) => _complete(done, session, readOutput: false),
        null,
        onStatistics == null
            ? null
            : (Statistics statistics) =>
                  onStatistics(statisticsFrom(statistics)),
      );
      final int? sessionId = session.getSessionId();
      if (sessionId != null) onSessionId?.call(sessionId);
    } on Object catch (error, stackTrace) {
      if (!done.isCompleted) {
        done.complete(failedToStart(error, stackTrace: stackTrace));
      }
    }
    return done.future;
  }

  /// Runs ffprobe with `FFprobeKit.executeWithArgumentsAsync`; the probed
  /// values are the session output. Never throws.
  @override
  Future<FfmpegResult> probe(List<String> arguments) async {
    final Completer<FfmpegResult> done = Completer<FfmpegResult>();
    try {
      await FFprobeKit.executeWithArgumentsAsync(
        arguments,
        (FFprobeSession session) => _complete(done, session, readOutput: true),
      );
    } on Object catch (error, stackTrace) {
      if (!done.isCompleted) {
        done.complete(failedToStart(error, stackTrace: stackTrace));
      }
    }
    return done.future;
  }

  /// `FFmpegKit.cancel(sessionId)`: the running session ends with return
  /// code 255 and its [execute] completes as cancelled.
  @override
  Future<void> cancel(int sessionId) => FFmpegKit.cancel(sessionId);

  /// Registers the stamp font with the plugin, ALWAYS with an empty
  /// font-name mapping ([fontNameMapping]): a null mapping reaches iOS as
  /// `NSNull` and crashes with `-[NSNull allKeys]`.
  @override
  Future<void> setFontDirectory(String path) =>
      _registerFonts(path, fontNameMapping);

  /// `ffmpeg -hide_banner -encoders` ([encoderListing]), run synchronously.
  /// An empty string when the session fails, and a
  /// [VideoProcessingException] when the plugin cannot run it; the engine
  /// logs either and uses the platform's default encoder.
  @override
  Future<String> listEncoders() async {
    try {
      final FFmpegSession session = await FFmpegKit.executeWithArguments(
        encoderListing,
      );
      if (!ReturnCode.isSuccess(await session.getReturnCode())) return '';
      return await session.getOutput() ?? '';
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        VideoProcessingException(
          'Could not list the encoders',
          returnCode: null,
          logTail: 'ffmpeg-kit error: $error',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  /// The encoder listing's argv, an ffmpeg (not ffprobe) command. Kept here
  /// rather than with the engine's commands, so the platform layer never
  /// depends on `core/media`.
  @visibleForTesting
  static const List<String> encoderListing = <String>[
    '-hide_banner',
    '-encoders',
  ];

  /// The font-name mapping handed to the plugin with the font path: empty,
  /// never null (see [setFontDirectory]).
  @visibleForTesting
  static const Map<String, String> fontNameMapping = <String, String>{};

  /// The plugin's statistics sample as the gateway's type.
  @visibleForTesting
  static FfmpegStatistics statisticsFrom(Statistics statistics) =>
      FfmpegStatistics(
        timeMs: statistics.getTime(),
        videoFrameNumber: statistics.getVideoFrameNumber(),
        size: statistics.getSize(),
        speed: statistics.getSpeed(),
      );

  static Future<void> _complete(
    Completer<FfmpegResult> done,
    Session session, {
    required bool readOutput,
  }) async {
    FfmpegResult result;
    try {
      result = await resultOf(session, readOutput: readOutput);
    } on Object catch (error, stackTrace) {
      result = failedToStart(error, stackTrace: stackTrace);
    }
    if (!done.isCompleted) done.complete(result);
  }

  /// The outcome of the finished [session], read with as few plugin calls as
  /// needed. Each read is a method-channel call served on the main thread, and
  /// `getOutput()` is `getAllLogsAsString()` under another name, so:
  /// - a success reads its output only when [readOutput] (ffprobe), never its logs;
  /// - any other session reads its logs once, waiting at most 500 ms, for the
  ///   failure tail `FfmpegRunner` keeps.
  @visibleForTesting
  static Future<FfmpegResult> resultOf(
    Session session, {
    required bool readOutput,
  }) async {
    final int? returnCode = (await session.getReturnCode())?.getValue();
    if (returnCode == ReturnCode.success) {
      return FfmpegResult(
        returnCode: returnCode,
        output: readOutput ? await session.getOutput() ?? '' : '',
        logs: '',
        failStackTrace: null,
      );
    }
    return FfmpegResult(
      returnCode: returnCode,
      output: '',
      logs: await session.getAllLogsAsString(_failureLogWaitMs) ?? '',
      failStackTrace: await session.getFailStackTrace(),
    );
  }

  /// How long a failure's log read waits for log messages still in transit.
  /// Positive on purpose: the plugin reads anything below 1 as its 5 s
  /// default.
  static const int _failureLogWaitMs = 500;

  /// The result of a session the plugin could not start or report on: no
  /// return code, the error as its log and [stackTrace] (where it was
  /// thrown) as its fail stack trace, so the runner's log keeps both.
  @visibleForTesting
  static FfmpegResult failedToStart(Object error, {StackTrace? stackTrace}) =>
      FfmpegResult(
        returnCode: null,
        output: '',
        logs: 'ffmpeg-kit error: $error',
        failStackTrace: stackTrace?.toString(),
      );
}
