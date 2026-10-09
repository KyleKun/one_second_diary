import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/platform/ffmpeg_kit_gateway.dart';
import 'package:one_second_diary/core/platform/ffmpeg_result.dart';

// Only the pure mapping of the gateway runs here: the plugin itself needs a
// device.
void main() {
  // A null font-name mapping reaches iOS as NSNull and crashes with
  // -[NSNull allKeys].
  test('registers the stamp font with an empty mapping, never null', () async {
    final List<(String, Map<String, String>?)> registered =
        <(String, Map<String, String>?)>[];
    final FfmpegKitGateway gateway = FfmpegKitGateway.withFontRegistrar(
      registerFonts: (String path, Map<String, String>? mapping) async {
        registered.add((path, mapping));
      },
    );

    await gateway.setFontDirectory('/fonts/YuseiMagic-Regular.v1.ttf');

    expect(registered, hasLength(1));
    expect(registered.single.$1, '/fonts/YuseiMagic-Regular.v1.ttf');
    expect(registered.single.$2, isNotNull);
    expect(registered.single.$2, isEmpty);
  });

  // Under `flutter test` no plugin is registered: the call fails the way a
  // broken platform channel does, and the engine encodes with the platform
  // default.
  test("lists the encoders with v1.7's argv (ffmpeg, not ffprobe); a plugin "
      'that cannot is a VideoProcessingException', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    expect(FfmpegKitGateway.encoderListing, <String>[
      '-hide_banner',
      '-encoders',
    ]);
    await expectLater(
      FfmpegKitGateway().listEncoders(),
      throwsA(
        isA<VideoProcessingException>().having(
          (VideoProcessingException e) => e.returnCode,
          'returnCode',
          isNull,
        ),
      ),
    );
  });

  // Each read is a platform-channel call the plugin serves on the main
  // thread, where it may wait for log messages still in transit (5 s by
  // default, and for any wait below 1 ms); the plugin's getOutput() is
  // getAllLogsAsString(). So a success reads no logs (an ffprobe success
  // reads its output, the probed values), and a failure reads its logs
  // once, with a short wait, for FfmpegRunner's failure tail.
  test('maps each finished session: success, probed output, failure logs, '
      'cancel, no return code, and a plugin that failed to start', () async {
    final _FinishedSession failure = _FinishedSession(
      1,
      log: 'Error while processing',
      failStackTrace: 'at ffmpeg',
    );
    // (name, session, read its output, the result, success, cancelled)
    final List<(String, _FinishedSession, bool, FfmpegResult, bool, bool)>
    rows = <(String, _FinishedSession, bool, FfmpegResult, bool, bool)>[
      (
        'an ffmpeg success',
        _FinishedSession(ReturnCode.success, log: 'frame=   30 fps=0.0'),
        false,
        const FfmpegResult(
          returnCode: 0,
          output: '',
          logs: '',
          failStackTrace: null,
        ),
        true,
        false,
      ),
      (
        'an ffprobe success',
        _FinishedSession(ReturnCode.success, log: '{"streams": []}'),
        true,
        const FfmpegResult(
          returnCode: 0,
          output: '{"streams": []}',
          logs: '',
          failStackTrace: null,
        ),
        true,
        false,
      ),
      (
        'a failure',
        failure,
        true,
        const FfmpegResult(
          returnCode: 1,
          output: '',
          logs: 'Error while processing',
          failStackTrace: 'at ffmpeg',
        ),
        false,
        false,
      ),
      (
        'a cancel (ffmpeg-kit ReturnCode.CANCEL)',
        _FinishedSession(ReturnCode.cancel, log: ''),
        false,
        const FfmpegResult(
          returnCode: FfmpegResult.cancelCode,
          output: '',
          logs: '',
          failStackTrace: null,
        ),
        false,
        true,
      ),
      (
        'no return code or logs',
        _FinishedSession(null, log: null),
        true,
        const FfmpegResult(
          returnCode: null,
          output: '',
          logs: '',
          failStackTrace: null,
        ),
        false,
        false,
      ),
    ];

    for (final (
          String name,
          _FinishedSession session,
          bool readOutput,
          FfmpegResult expected,
          bool success,
          bool cancelled,
        )
        in rows) {
      final FfmpegResult result = await FfmpegKitGateway.resultOf(
        session,
        readOutput: readOutput,
      );
      expect(result, expected, reason: name);
      expect(result.success, success, reason: name);
      expect(result.cancelled, cancelled, reason: name);
    }
    expect(failure.logWaits, everyElement(inInclusiveRange(1, 1000)));

    final StackTrace thrownAt = StackTrace.current;
    final FfmpegResult failedToStart = FfmpegKitGateway.failedToStart(
      StateError('channel closed'),
      stackTrace: thrownAt,
    );
    expect(failedToStart.success, isFalse);
    expect(failedToStart.cancelled, isFalse);
    expect(failedToStart.logs, contains('channel closed'));
    expect(failedToStart.failStackTrace, thrownAt.toString());
  });
}

/// A finished plugin session. As in the plugin, its output IS its logs
/// (`getOutput() => getAllLogsAsString()`), the text [log].
final class _FinishedSession extends Fake implements Session {
  _FinishedSession(this._returnCode, {required this.log, this.failStackTrace});

  final int? _returnCode;
  final String? log;
  final String? failStackTrace;

  /// The wait each log read asked for (null: the plugin's default, 5 s).
  final List<int?> logWaits = <int?>[];

  @override
  Future<ReturnCode?> getReturnCode() async =>
      _returnCode == null ? null : ReturnCode(_returnCode);

  @override
  Future<String?> getOutput() => getAllLogsAsString();

  @override
  Future<String?> getAllLogsAsString([int? waitTimeout]) async {
    logWaits.add(waitTimeout);
    return log;
  }

  @override
  Future<String?> getFailStackTrace() async => failStackTrace;
}
