import 'package:equatable/equatable.dart';

/// The outcome of one ffmpeg or ffprobe session.
final class FfmpegResult extends Equatable {
  const FfmpegResult({
    required this.returnCode,
    required this.output,
    required this.logs,
    required this.failStackTrace,
  });

  /// ffmpeg-kit's `ReturnCode.CANCEL`.
  static const int cancelCode = 255;

  /// The session's return code; null when it produced none.
  final int? returnCode;

  /// The session's output (for ffprobe: the probed values). The real
  /// gateway reads it only for a successful ffprobe session, the one place
  /// it is used.
  final String output;

  /// Every log line of the session. The real gateway reads them only for a
  /// session that did not succeed (for the failure tail); a success leaves
  /// this empty, since each read is a main-thread plugin call.
  final String logs;

  /// ffmpeg-kit's fail stack trace, when the session failed.
  final String? failStackTrace;

  /// Return code 0 (ffmpeg-kit `ReturnCode.SUCCESS`).
  bool get success => returnCode == 0;

  /// Return code 255 (ffmpeg-kit `ReturnCode.CANCEL`).
  bool get cancelled => returnCode == cancelCode;

  @override
  List<Object?> get props => <Object?>[
    returnCode,
    output,
    logs,
    failStackTrace,
  ];
}
