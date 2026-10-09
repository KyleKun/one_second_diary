import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/features/profiles/domain/device_media_profile.dart';

/// One test of the media part of the phone check, as it starts: the
/// progress line "Testing 4K 60 fps · HEVC" or "Playing a sample video".
sealed class DeviceMediaCheckStep extends Equatable {
  const DeviceMediaCheckStep({required this.index});

  /// 0-based, over the runner's `stepCount`.
  final int index;
}

/// A synthetic encode of [format].
final class EncodeStep extends DeviceMediaCheckStep {
  const EncodeStep({required super.index, required this.format});

  final ClipFormat format;

  @override
  List<Object?> get props => <Object?>[index, format];
}

/// A decode of the bundled [sample].
final class DecodeStep extends DeviceMediaCheckStep {
  const DecodeStep({required super.index, required this.sample});

  final String sample;

  @override
  List<Object?> get props => <Object?>[index, sample];
}

/// What the media tests found.
final class DeviceMediaCheckResult extends Equatable {
  DeviceMediaCheckResult({
    required Map<String, EncodeResult> encode,
    required Map<String, double> decode,
  }) : encode = Map<String, EncodeResult>.unmodifiable(encode),
       decode = Map<String, double>.unmodifiable(decode);

  /// Per candidate (`ClipFormat.toString`).
  final Map<String, EncodeResult> encode;

  /// Per bundled sample: the real-time factor.
  final Map<String, double> decode;

  @override
  List<Object?> get props => <Object?>[encode, decode];
}

/// A media check in flight.
abstract interface class DeviceMediaCheckRun {
  /// What was found, once every test ran or the escalation stopped. After
  /// [cancel], what was found so far. Throws a `VideoProcessingException`
  /// when the engine could not run at all.
  Future<DeviceMediaCheckResult> get result;

  /// Stops after the test in flight.
  Future<void> cancel();
}

/// The media tests of the phone check: the synthetic encodes, cheapest first, stopping at the first failure, and the decodes
/// of the bundled samples. `DeviceMediaCheck` (`core/media`) is adapted to this; tests fake it.
abstract interface class DeviceMediaCheckRunner {
  /// How many steps a full run reports, for the progress bar (a run that
  /// stops early reports fewer).
  int get stepCount;

  /// Starts the tests; [onStep] is called as each begins.
  DeviceMediaCheckRun start({
    required void Function(DeviceMediaCheckStep step) onStep,
  });
}
