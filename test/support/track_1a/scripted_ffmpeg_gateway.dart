import 'dart:async';
import 'dart:io';

import 'package:one_second_diary/core/platform/ffmpeg_result.dart';
import 'package:one_second_diary/core/platform/ffmpeg_statistics.dart';

import '../fake_clock.dart';
import '../fakes/fake_ffmpeg_gateway.dart';

/// A [FakeFfmpegGateway] that behaves enough like ffmpeg for engine tests:
///
/// - every `execute` writes its output file (the argument before the final
///   `-y`), also when the session then fails or is cancelled, as a real
///   partial output would be;
/// - [answer] can replace the result of an `execute` by its arguments (for
///   example, fail only the concat);
/// - `probe` answers [probeOutputs] by the probed path (the last argument),
///   and [otherProbeOutput] for any other path; a keyframe probe answers
///   [keyframeOutputs] and [otherKeyframeOutput] the same way;
/// - [textInputs] keeps what each text input (concat list, SRT) held;
/// - `listEncoders` can be held on [encodersGate];
/// - with [clock], each statistics sample first advances it by
///   [statisticsGap], so throttling can be observed.
class ScriptedFfmpegGateway extends FakeFfmpegGateway {
  ScriptedFfmpegGateway({this.clock}) {
    onExecute = writeOutput;
  }

  final FakeClock? clock;

  /// Time between two statistics samples (with [clock]).
  Duration statisticsGap = const Duration(milliseconds: 500);

  /// The bytes of every output file.
  List<int> outputBytes = const <int>[0, 0, 0, 24, 102, 116, 121, 112];

  /// Replaces the scripted result of an `execute` when it returns non-null.
  FfmpegResult? Function(List<String> arguments)? answer;

  /// ffprobe output by probed path.
  final Map<String, String> probeOutputs = <String, String>{};

  /// ffprobe output for any other path (for example, the engine's own
  /// temps); null leaves those to the queued results.
  String? otherProbeOutput;

  /// The output of a keyframe probe (`ProbeCommands.keyframes`, told apart
  /// by its `packet=pts_time,flags` entry) by probed path, and for any
  /// other path ([otherKeyframeOutput], no packets unless set).
  final Map<String, String> keyframeOutputs = <String, String>{};
  String otherKeyframeOutput = '';

  /// The content of every `.txt` or `.srt` input (`-i`) at the time its
  /// session ran, by path: concat lists and subtitle files live in job
  /// folders that are gone once the job ends.
  final Map<String, String> textInputs = <String, String>{};

  /// When set, `listEncoders` waits for it.
  Completer<void>? encodersGate;

  /// The output file of [arguments]: the element before the final `-y`.
  static String? outputOf(List<String> arguments) =>
      arguments.length >= 2 && arguments.last == '-y'
      ? arguments[arguments.length - 2]
      : null;

  @override
  Future<FfmpegResult> execute(
    List<String> arguments, {
    void Function(FfmpegStatistics statistics)? onStatistics,
    void Function(int sessionId)? onSessionId,
  }) async {
    for (final (int index, String argument) in arguments.indexed) {
      final String? input = index > 0 && arguments[index - 1] == '-i'
          ? argument
          : null;
      if (input != null && (input.endsWith('.txt') || input.endsWith('.srt'))) {
        textInputs[input] = await File(input).readAsString();
      }
    }
    final FfmpegResult result = await super.execute(
      arguments,
      onSessionId: onSessionId,
      onStatistics: onStatistics == null
          ? null
          : (FfmpegStatistics sample) {
              clock?.advance(statisticsGap);
              onStatistics(sample);
            },
    );
    return answer?.call(arguments) ?? result;
  }

  @override
  Future<FfmpegResult> probe(List<String> arguments) async {
    // A probe output may be scripted by the file's name alone, for a file
    // the engine makes in a job folder nobody knows in advance.
    final String name = arguments.last.split('/').last;
    final String? output = arguments.contains('packet=pts_time,flags')
        ? keyframeOutputs[arguments.last] ?? otherKeyframeOutput
        : probeOutputs[arguments.last] ??
              probeOutputs[name] ??
              otherProbeOutput;
    final FfmpegResult result = await super.probe(arguments);
    return output == null ? result : FakeFfmpegGateway.success(output: output);
  }

  @override
  Future<String> listEncoders() async {
    await encodersGate?.future;
    return super.listEncoders();
  }

  /// Writes the output file of [arguments], as ffmpeg would.
  Future<void> writeOutput(List<String> arguments) async {
    final String? output = outputOf(arguments);
    if (output == null) return;
    final File file = File(output);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(outputBytes);
  }
}
