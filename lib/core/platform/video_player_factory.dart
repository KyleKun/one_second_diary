import 'dart:io';

import 'package:one_second_diary/core/platform/player_factory.dart';
import 'package:one_second_diary/core/platform/player_handle.dart';
import 'package:one_second_diary/core/platform/video_player_handle.dart';
import 'package:video_player/video_player.dart';

/// [PlayerFactory] over the pinned `video_player` fork (it fixes seeking
/// after the end, flutter#170737, and reports `isCompleted`).
///
/// [mixWithOthers] goes through `VideoPlayerOptions`: without it even a
/// muted Diary preview pauses the user's music. On iOS the plugin applies
/// it to the app-wide audio session when a player initialises; `PlayerPool`
/// keeps every live player on one value.
final class VideoPlayerFactory implements PlayerFactory {
  @override
  PlayerHandle create(String path, {required bool mixWithOthers}) =>
      VideoPlayerHandle(
        VideoPlayerController.file(
          File(path),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: mixWithOthers),
        ),
      );
}
