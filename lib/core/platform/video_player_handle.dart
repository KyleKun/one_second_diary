import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/platform/player_handle.dart';
import 'package:one_second_diary/core/platform/player_state.dart';
import 'package:video_player/video_player.dart';

/// The [PlayerState] of a `video_player` [value]. `completed` is the fork's
/// `isCompleted` (set at the end, cleared by playing or seeking back), and
/// the aspect ratio is the plugin's (1 until initialised).
///
/// [openError] is why the player could not be opened when [value] does not
/// say: the plugin describes only the errors of its event stream, so a
/// player the platform refused to create has no description of its own.
PlayerState playerStateOf(VideoPlayerValue value, {String? openError}) =>
    PlayerState(
      initialized: value.isInitialized,
      playing: value.isPlaying,
      position: value.position,
      duration: value.duration,
      error: value.errorDescription ?? openError,
      aspectRatio: value.aspectRatio,
      completed: value.isCompleted,
    );

/// [PlayerHandle] over a `VideoPlayerController` of the pinned fork.
///
/// Three plugin behaviours are smoothed over, so the `PlayerPool` can
/// dispose a player at any moment and a screen always learns of a failure:
/// - calls after [dispose] do nothing (the controller throws when used
///   after dispose);
/// - [initialize] completes when the handle is disposed meanwhile (the
///   controller's never does, its events being ignored after dispose);
/// - an [initialize] that throws before the plugin listens to the player's
///   events (the platform could not create it) leaves the controller's
///   value without an error; [value] carries the thrown one, so the screen
///   shows "can't play" and not a player that loads for ever.
final class VideoPlayerHandle implements PlayerHandle {
  VideoPlayerHandle(this._controller) {
    _controller.addListener(_sync);
  }

  final VideoPlayerController _controller;

  late final ValueNotifier<PlayerState> _state = ValueNotifier<PlayerState>(
    playerStateOf(_controller.value),
  );

  bool _disposed = false;

  /// Why [initialize] threw; null while it has not.
  String? _openError;

  /// Completed by [dispose].
  final Completer<void> _disposedSignal = Completer<void>();

  /// The wrapped controller, for the factory's tests.
  @visibleForTesting
  VideoPlayerController get controller => _controller;

  @override
  ValueListenable<PlayerState> get value => _state;

  void _sync() =>
      _state.value = playerStateOf(_controller.value, openError: _openError);

  @override
  Future<void> initialize() async {
    if (_disposed) return;
    try {
      await Future.any(<Future<void>>[
        _controller.initialize(),
        _disposedSignal.future,
      ]);
    } on Object catch (error) {
      _openError = '$error';
      if (!_disposed) _sync();
      rethrow;
    }
  }

  @override
  Future<void> play() => _unlessDisposed(_controller.play);

  @override
  Future<void> pause() => _unlessDisposed(_controller.pause);

  @override
  Future<void> seekTo(Duration position) =>
      _unlessDisposed(() => _controller.seekTo(position));

  @override
  Future<void> setVolume(double volume) =>
      _unlessDisposed(() => _controller.setVolume(volume));

  @override
  Future<void> setLooping(bool looping) =>
      _unlessDisposed(() => _controller.setLooping(looping));

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _disposedSignal.complete();
    _controller.removeListener(_sync);
    await _controller.dispose();
    // _state is left undisposed: a screen may still remove its listener.
  }

  Future<void> _unlessDisposed(Future<void> Function() call) =>
      _disposed ? Future<void>.value() : call();

  @override
  Widget buildView() => VideoPlayer(_controller);
}
