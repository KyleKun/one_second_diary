import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/platform/player_state.dart';

/// Where a clip's playback is, for the controls drawn over a
/// `ClipPlayerView`.
enum ClipPlaybackPhase {
  /// The clip's player is not ready yet: the poster shows.
  loading,

  /// Ready and paused (before the first play too).
  paused,

  playing,

  /// It played to the end (only when it does not loop).
  completed,

  /// The file cannot be played (deleted meanwhile, unreadable).
  failed,
}

/// What a `ClipPlayerView` shows: the [phase], and how far it has played.
final class ClipPlayback extends Equatable {
  const ClipPlayback({
    required this.phase,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  /// Before the clip's player is ready.
  const ClipPlayback.loading() : this(phase: ClipPlaybackPhase.loading);

  /// The playback a player's [state] describes.
  factory ClipPlayback.of(PlayerState state) => ClipPlayback(
    phase: switch (state) {
      PlayerState(error: _?) => ClipPlaybackPhase.failed,
      PlayerState(initialized: false) => ClipPlaybackPhase.loading,
      PlayerState(playing: true) => ClipPlaybackPhase.playing,
      PlayerState(completed: true) => ClipPlaybackPhase.completed,
      _ => ClipPlaybackPhase.paused,
    },
    position: state.position,
    duration: state.duration,
  );

  final ClipPlaybackPhase phase;
  final Duration position;
  final Duration duration;

  bool get isPlaying => phase == ClipPlaybackPhase.playing;

  /// 0 to 1: how far it has played.
  double get progress => duration <= Duration.zero
      ? 0
      : (position.inMicroseconds / duration.inMicroseconds).clamp(0, 1);

  @override
  List<Object?> get props => <Object?>[phase, position, duration];
}

/// What the controls over a `ClipPlayerView` can do with its clip.
abstract interface class ClipPlayerControls {
  /// Plays; from the start when it had played to the end.
  Future<void> play();

  Future<void> pause();

  /// Plays when paused, pauses when playing (a tap on the video).
  Future<void> toggle();

  Future<void> seekTo(Duration position);
}
