import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';

/// One encode test of the phone check (`DeviceMediaCheck`): whether this
/// phone wrote [format] with [encoder], and how fast.
final class EncodeTestResult extends Equatable {
  const EncodeTestResult({
    required this.format,
    required this.encoder,
    required this.ok,
    required this.realtimeFactor,
  });

  /// The candidate (on the landscape canvas; the orientation does not
  /// change the speed).
  final ClipFormat format;

  final VideoEncoder encoder;

  /// Whether ffmpeg finished and its output really holds the format (the
  /// encoder list only says a wrapper was compiled in).
  final bool ok;

  /// Seconds of video encoded per wall second: 1.0 means a 3 s clip saves
  /// in about 3 s. 0 when the test failed.
  final double realtimeFactor;

  @override
  List<Object?> get props => <Object?>[format, encoder, ok, realtimeFactor];
}

/// One decode test of the phone check: how fast this phone decodes the
/// bundled real-world [sample] in software.
final class DecodeTestResult extends Equatable {
  const DecodeTestResult({
    required this.sample,
    required this.ok,
    required this.realtimeFactor,
  });

  /// The sample's path, as given to the check.
  final String sample;

  final bool ok;

  /// Seconds of video decoded per wall second; 0 when the test failed.
  final double realtimeFactor;

  @override
  List<Object?> get props => <Object?>[sample, ok, realtimeFactor];
}

/// What the phone check measured: the encode
/// candidates tried, in order, up to the first that failed or ran under
/// `DeviceMediaCheck.stopBelowFactor`, and the decode of every sample.
/// The profiles & onboarding lane wraps it with the camera probe, the free
/// space and the phone's identity into its `DeviceMediaProfile`.
final class DeviceMediaCheckResult extends Equatable {
  const DeviceMediaCheckResult({required this.encode, required this.decode});

  final List<EncodeTestResult> encode;
  final List<DecodeTestResult> decode;

  /// The encode result of [format] on either canvas, or null when the
  /// escalation never reached it.
  EncodeTestResult? encodeOf(ClipFormat format) {
    for (final EncodeTestResult result in encode) {
      if (result.format.withOrientation(format.orientation) == format) {
        return result;
      }
    }
    return null;
  }

  @override
  List<Object?> get props => <Object?>[encode, decode];
}
