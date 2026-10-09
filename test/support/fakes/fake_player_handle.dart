import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/player_handle.dart';
import 'package:one_second_diary/core/platform/player_state.dart';

/// A [PlayerHandle] that plays nothing but moves through the same states.
///
/// - `initialize` reports [duration] and [aspectRatio]; with
///   [failInitialize] it reports an error and throws a [StateError]; with
///   [holdInitialize] it waits for [completeInitialize].
/// - `play`, `pause`, `seekTo` update [value] (seeking to the end reads as
///   completed, playing clears it); [volume] and [looping] keep the last
///   values set.
/// - After `dispose` ([isDisposed]) every call is ignored.
/// - `buildView` is a `SizedBox` keyed `ValueKey('fake-player:<path>')`.
/// - [emit] pushes any state (e.g. playback reaching the end).
class FakePlayerHandle extends Fake implements PlayerHandle {
  FakePlayerHandle({
    required this.path,
    required this.mixWithOthers,
    this.duration = const Duration(seconds: 2),
    this.aspectRatio = 16 / 9,
    this.failInitialize = false,
    this.holdInitialize = false,
  });

  final String path;
  final bool mixWithOthers;
  final Duration duration;
  final double aspectRatio;
  final bool failInitialize;
  final bool holdInitialize;

  final ValueNotifier<PlayerState> _value = ValueNotifier<PlayerState>(
    const PlayerState.uninitialized(),
  );
  final Completer<void> _initializeGate = Completer<void>();

  bool isDisposed = false;
  double volume = 1;
  bool looping = false;

  @override
  ValueListenable<PlayerState> get value => _value;

  /// Lets a held `initialize` finish.
  void completeInitialize() {
    if (!_initializeGate.isCompleted) _initializeGate.complete();
  }

  /// Replaces the current state.
  void emit(PlayerState state) {
    if (!isDisposed) _value.value = state;
  }

  @override
  Future<void> initialize() async {
    if (isDisposed) return;
    if (holdInitialize) await _initializeGate.future;
    if (failInitialize) {
      emit(_copy(error: 'Cannot open $path'));
      throw StateError('Cannot open $path');
    }
    emit(
      PlayerState(
        initialized: true,
        playing: false,
        position: Duration.zero,
        duration: duration,
        error: null,
        aspectRatio: aspectRatio,
        completed: false,
      ),
    );
  }

  @override
  Future<void> play() async => emit(_copy(playing: true, completed: false));

  @override
  Future<void> pause() async => emit(_copy(playing: false));

  /// Like the fork, a position at the end reads as completed.
  @override
  Future<void> seekTo(Duration position) async => emit(
    _copy(position: position, completed: position == _value.value.duration),
  );

  @override
  Future<void> setVolume(double volume) async {
    if (!isDisposed) this.volume = volume;
  }

  @override
  Future<void> setLooping(bool looping) async {
    if (!isDisposed) this.looping = looping;
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
  }

  @override
  Widget buildView() => SizedBox(key: ValueKey<String>('fake-player:$path'));

  PlayerState _copy({
    bool? playing,
    Duration? position,
    String? error,
    bool? completed,
  }) {
    final PlayerState current = _value.value;
    return PlayerState(
      initialized: current.initialized,
      playing: playing ?? current.playing,
      position: position ?? current.position,
      duration: current.duration,
      error: error ?? current.error,
      aspectRatio: current.aspectRatio,
      completed: completed ?? current.completed,
    );
  }
}
