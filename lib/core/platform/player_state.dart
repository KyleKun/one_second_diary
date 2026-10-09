import 'package:equatable/equatable.dart';

/// A snapshot of a video player (mapped from `VideoPlayerValue`).
final class PlayerState extends Equatable {
  const PlayerState({
    required this.initialized,
    required this.playing,
    required this.position,
    required this.duration,
    required this.error,
    required this.aspectRatio,
    required this.completed,
  });

  /// Before `initialize` completes.
  const PlayerState.uninitialized()
    : initialized = false,
      playing = false,
      position = Duration.zero,
      duration = Duration.zero,
      error = null,
      aspectRatio = 1,
      completed = false;

  final bool initialized;
  final bool playing;
  final Duration position;
  final Duration duration;

  /// Playback reached the end (the fork's `isCompleted`): the player paused
  /// on the last frame. Cleared when it plays again or seeks back. The Diary
  /// and the viewer step to the next clip on it.
  final bool completed;

  /// The player's error description (e.g. file not found); null when fine.
  final String? error;

  /// Width / height of the video; 1 until initialised.
  final double aspectRatio;

  @override
  List<Object?> get props => <Object?>[
    initialized,
    playing,
    position,
    duration,
    error,
    aspectRatio,
    completed,
  ];
}
