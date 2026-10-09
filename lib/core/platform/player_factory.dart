import 'package:one_second_diary/core/platform/player_handle.dart';

/// Creates video players. The only way the app makes one, so widget and
/// cubit tests can pump pages with fake players.
abstract interface class PlayerFactory {
  /// A new, uninitialised player for the local file at [path].
  ///
  /// With [mixWithOthers] the player does not take audio focus, so a muted
  /// preview never stops the user's music. On iOS this is NOT per player:
  /// the plugin applies it to the app-wide audio session each time a player
  /// initialises, so the last one wins. Callers that keep several players
  /// alive (the `PlayerPool`) create them all with one value and recreate
  /// or re-initialise them when it changes (e.g. when the user unmutes).
  ///
  /// Never throws and never opens the file: `PlayerHandle.initialize` does,
  /// and reports a file that cannot be played.
  PlayerHandle create(String path, {required bool mixWithOthers});
}
