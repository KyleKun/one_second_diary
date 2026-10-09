import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/platform/player_state.dart';
import 'package:one_second_diary/core/platform/video_player_handle.dart';
import 'package:video_player/video_player.dart';

void main() {
  test("maps the plugin's value: a playing clip with its aspect ratio, an "
      "unopened one, the plugin's error and the fork's completed flag", () {
    expect(
      playerStateOf(
        const VideoPlayerValue(
          duration: Duration(seconds: 2),
          size: Size(1920, 1080),
          position: Duration(milliseconds: 500),
          isInitialized: true,
          isPlaying: true,
        ),
      ),
      const PlayerState(
        initialized: true,
        playing: true,
        position: Duration(milliseconds: 500),
        duration: Duration(seconds: 2),
        error: null,
        aspectRatio: 1920 / 1080,
        completed: false,
      ),
    );
    expect(
      playerStateOf(const VideoPlayerValue.uninitialized()),
      const PlayerState.uninitialized(),
    );
    expect(
      playerStateOf(const VideoPlayerValue.erroneous('Source error')).error,
      'Source error',
    );
    expect(
      playerStateOf(
        const VideoPlayerValue(
          duration: Duration(seconds: 2),
          position: Duration(seconds: 2),
          isInitialized: true,
          isCompleted: true,
        ),
      ).completed,
      isTrue,
    );
  });

  // The platform refusing to create a player throws before the plugin listens for its
  // errors, so the controller's value never says so and the screen would show a clip that
  // loads forever.
  test('an initialize that throws without a plugin error still shows as a '
      'failed player', () async {
    final _FakeController controller = _FakeController();
    final VideoPlayerHandle handle = VideoPlayerHandle(controller);
    final Future<void> opening = handle.initialize();
    controller.opened.completeError(StateError('no player'));

    await expectLater(opening, throwsStateError);
    expect(handle.value.value.initialized, isFalse);
    expect(handle.value.value.error, contains('no player'));
  });

  // The plugin's controller throws when used after dispose, and the fork
  // never answers initialize after dispose.
  test('after dispose, a pending initialize completes and every later call '
      'is ignored', () async {
    final _FakeController controller = _FakeController();
    final VideoPlayerHandle handle = VideoPlayerHandle(controller);
    bool initialized = false;
    unawaited(handle.initialize().whenComplete(() => initialized = true));

    await handle.dispose();
    await pumpEventQueue();
    expect(initialized, isTrue);

    await handle.play();
    await handle.pause();
    await handle.seekTo(Duration.zero);
    await handle.setVolume(0);
    await handle.setLooping(true);
    await handle.dispose();
    expect(handle.value.value.playing, isFalse);
  });
}

/// A controller that plays nothing: [initialize] answers when [opened]
/// completes, and the rest only moves [value]. Like the plugin's, it
/// throws when used after [dispose] (a `ValueNotifier`).
class _FakeController extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  _FakeController() : super(const VideoPlayerValue.uninitialized());

  final Completer<void> opened = Completer<void>();

  @override
  Future<void> initialize() => opened.future;

  @override
  Future<void> play() async => value = value.copyWith(isPlaying: true);

  @override
  Future<void> pause() async => value = value.copyWith(isPlaying: false);

  @override
  Future<void> seekTo(Duration position) async =>
      value = value.copyWith(position: position);

  @override
  Future<void> setVolume(double volume) async =>
      value = value.copyWith(volume: volume);

  @override
  Future<void> setLooping(bool looping) async =>
      value = value.copyWith(isLooping: looping);

  @override
  Future<void> dispose() async => super.dispose();

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
