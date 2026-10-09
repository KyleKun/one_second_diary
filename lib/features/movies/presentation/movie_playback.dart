import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:one_second_diary/core/platform/player_handle.dart';
import 'package:one_second_diary/core/platform/player_state.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';

/// What the movie player's movie is doing.
enum MoviePhase {
  /// Its player is opening (the poster shows).
  loading,

  playing,

  /// Paused by the user.
  paused,

  /// Played to the end (the replay circle shows).
  ended,

  /// It can't be played (the error block shows).
  failed,
}

/// The movie on the player's screen (the movie player page): the player the
/// screen's [PlayerPool] shows for [path], what it is doing, and the user's
/// controls.
final class MoviePlayback {
  MoviePlayback({
    required this._pool,
    required this.path,
    required TickerProvider vsync,
    required this._onPlayingChanged,
  }) : _progress = AnimationController(vsync: vsync);

  final PlayerPool _pool;

  /// The movie's absolute path.
  final String path;

  /// Told whether the movie plays, each time that changes.
  final ValueChanged<bool> _onPlayingChanged;

  final AnimationController _progress;
  final ValueNotifier<MoviePhase> _phase = ValueNotifier<MoviePhase>(
    MoviePhase.loading,
  );
  final ValueNotifier<Duration> _duration = ValueNotifier<Duration>(
    Duration.zero,
  );

  /// The gap between two position reports of `video_player`.
  static const Duration _reportGap = Duration(milliseconds: 500);

  /// A move forward larger than this is a seek, not playback: it jumps.
  static const Duration _glideLimit = Duration(seconds: 1);

  final ValueNotifier<PlayerHandle?> _player = ValueNotifier<PlayerHandle?>(
    null,
  );
  bool _autoplayed = false;
  bool _playing = false;
  bool _disposed = false;

  /// What the movie is doing.
  ValueListenable<MoviePhase> get phase => _phase;

  /// How long it runs; zero until its player knows.
  ValueListenable<Duration> get duration => _duration;

  /// How far it has played, 0 to 1.
  ValueListenable<double> get progress => _progress;

  /// Where it is, as [progress] says of [duration].
  Duration get position => _duration.value * _progress.value;

  /// The player on screen (its video); null until it is ready.
  ValueListenable<PlayerHandle?> get player => _player;

  PlayerHandle? get _handle => _player.value;

  /// Opens the movie, then plays it.
  void start() {
    _pool.shown.addListener(_onShown);
    unawaited(_pool.select(path));
  }

  /// A tap on the movie: pauses it, plays it on, or plays it again from
  /// the start once it ended.
  void toggle() {
    final PlayerHandle? handle = _handle;
    if (handle == null) return;
    switch (_phase.value) {
      case MoviePhase.playing:
        unawaited(handle.pause());
      case MoviePhase.paused:
        unawaited(handle.play());
      case MoviePhase.ended:
        unawaited(_replay(handle));
      case MoviePhase.loading || MoviePhase.failed:
        break;
    }
  }

  Future<void> _replay(PlayerHandle handle) async {
    await handle.seekTo(Duration.zero);
    await handle.play();
  }

  /// Moves the movie to [fraction] (0 to 1) of its length.
  void seekTo(double fraction) =>
      seekToPosition(_duration.value * fraction.clamp(0, 1).toDouble());

  /// Moves the movie to [position] (a chapter's start). The bar goes there
  /// at once; the movie plays on if it was playing.
  void seekToPosition(Duration position) {
    final PlayerHandle? handle = _handle;
    final Duration duration = _duration.value;
    if (handle == null || duration <= Duration.zero) return;
    final Duration target = position < Duration.zero
        ? Duration.zero
        : position > duration
        ? duration
        : position;
    _progress
      ..stop()
      ..value = target.inMicroseconds / duration.inMicroseconds;
    unawaited(handle.seekTo(target));
  }

  /// Stops the movie where it is (a movie that can't be played).
  void pause() => unawaited(_handle?.pause());

  Future<void> setMuted(bool muted) => _pool.setMuted(muted);

  void _onShown() {
    final PlayerHandle? handle = _pool.shown.value?.handle;
    if (_disposed || handle == null || identical(handle, _handle)) return;
    _handle?.value.removeListener(_onPlayer);
    _player.value = handle;
    handle.value.addListener(_onPlayer);
    unawaited(handle.setLooping(false));
    if (!_autoplayed && handle.value.value.error == null) {
      _autoplayed = true;
      unawaited(handle.play());
    }
    _onPlayer();
  }

  void _onPlayer() {
    final PlayerHandle? handle = _handle;
    if (_disposed || handle == null) return;
    final PlayerState state = handle.value.value;
    _phase.value = switch (state) {
      PlayerState(error: final String _) => MoviePhase.failed,
      PlayerState(initialized: false) => MoviePhase.loading,
      PlayerState(playing: true) => MoviePhase.playing,
      PlayerState(completed: true) => MoviePhase.ended,
      _ => MoviePhase.paused,
    };
    _duration.value = state.duration;
    if (state.playing != _playing) {
      _playing = state.playing;
      _onPlayingChanged(state.playing);
    }
    _follow(state);
  }

  void _follow(PlayerState state) {
    final int total = state.duration.inMicroseconds;
    final double target = total <= 0
        ? 0
        : (state.position.inMicroseconds / total).clamp(0, 1).toDouble();
    final double ahead = target - _progress.value;
    if (state.playing && ahead > 0 && state.duration * ahead <= _glideLimit) {
      unawaited(_progress.animateTo(target, duration: _reportGap));
    } else {
      _progress
        ..stop()
        ..value = target;
    }
  }

  void dispose() {
    _disposed = true;
    _pool.shown.removeListener(_onShown);
    _handle?.value.removeListener(_onPlayer);
    _progress.dispose();
    _player.dispose();
    _phase.dispose();
    _duration.dispose();
  }
}
