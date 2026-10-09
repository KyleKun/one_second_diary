import 'package:one_second_diary/core/platform/ffmpeg_result.dart';
import 'package:one_second_diary/core/platform/ffmpeg_statistics.dart';

/// The only way into ffmpeg-kit.
///
/// The real implementation is the ONLY file that imports
/// `ffmpeg_kit_flutter_new`: swapping the GPL build for the LGPL one (the App
/// Store path) is an import change in that one file. Plugins cannot run under
/// `flutter test`, so everything above this boundary is tested with a fake.
///
/// Commands are always ARGUMENT LISTS, one element per argument, never a
/// joined command string: a path with spaces (iOS `Application Support`) must
/// never be split.
abstract interface class FfmpegGateway {
  /// Runs ffmpeg with [arguments] and completes when the session ends
  /// (successfully, failed or cancelled; see [FfmpegResult]). Does not throw
  /// for a failed session.
  ///
  /// [onSessionId] is called once, as soon as the session exists, so the
  /// caller can [cancel] it. [onStatistics] is called with every progress
  /// sample.
  Future<FfmpegResult> execute(
    List<String> arguments, {
    void Function(FfmpegStatistics statistics)? onStatistics,
    void Function(int sessionId)? onSessionId,
  });

  /// Runs ffprobe with [arguments] and completes when it ends.
  Future<FfmpegResult> probe(List<String> arguments);

  /// Cancels the running session [sessionId]; its [execute] then completes
  /// with a cancelled result. Does nothing when the session already ended.
  Future<void> cancel(int sessionId);

  /// Registers the folder holding the stamp fonts. The implementation must
  /// pass an empty map (`{}`), never null, as the font-name mapping: iOS
  /// crashes on `NSNull` otherwise.
  Future<void> setFontDirectory(String path);

  /// The output of `ffmpeg -hide_banner -encoders`, for the encoder probe:
  /// `''` when the session fails. Throws a `VideoProcessingException` when
  /// the plugin cannot run it; the engine logs either and encodes with the
  /// platform default.
  Future<String> listEncoders();
}
