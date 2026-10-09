import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/platform/player_state.dart';

/// One video player (the pinned `video_player` fork), created by a
/// `PlayerFactory`.
///
/// The owner must [dispose] it. Calls after [dispose] are ignored.
abstract interface class PlayerHandle {
  /// The player's live state.
  ValueListenable<PlayerState> get value;

  /// Opens the file. Completes when the first frame is ready, or throws when
  /// the file cannot be played. The thrown error is the plugin's (its type
  /// is not part of the contract); the same failure is in [value]
  /// (`PlayerState.error`), which is what a screen shows.
  Future<void> initialize();

  Future<void> play();

  Future<void> pause();

  Future<void> seekTo(Duration position);

  /// 0 (muted) to 1.
  Future<void> setVolume(double volume);

  Future<void> setLooping(bool looping);

  Future<void> dispose();

  /// The widget that renders the video (sized by its parent; use
  /// `PlayerState.aspectRatio` to lay it out).
  Widget buildView();
}
