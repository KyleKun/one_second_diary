import 'package:equatable/equatable.dart';

/// A progress sample of a running ffmpeg session (ffmpeg-kit `Statistics`).
final class FfmpegStatistics extends Equatable {
  const FfmpegStatistics({
    required this.timeMs,
    required this.videoFrameNumber,
    required this.size,
    required this.speed,
  });

  /// Output time processed so far, in ms. Progress = timeMs / expected
  /// output duration.
  final int timeMs;

  final int videoFrameNumber;

  /// Output size so far, in bytes.
  final int size;

  /// Processing speed relative to real time.
  final double speed;

  @override
  List<Object?> get props => <Object?>[timeMs, videoFrameNumber, size, speed];
}
