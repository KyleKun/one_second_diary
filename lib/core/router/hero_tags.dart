import 'package:one_second_diary/features/clips/domain/clip_ref.dart';

/// The shared-element hero tags. Both ends of a flight use the same tag:
/// Today's record button and the camera shutter, a clip (Today, the Diary,
/// Memories) and the viewer, a movie and the player.
///
/// Flights go straight (go_router's plain `HeroController`); under reduced
/// motion there is no hero (a 150 ms fade).
abstract final class HeroTags {
  /// Today's record button → the camera shutter.
  static const String recordShutter = 'record-shutter';

  /// A clip → the viewer: `clip-{profileId}-{yyyyMMdd}-{index}`.
  static String clip(ClipRef clip) =>
      'clip-${clip.profile.value}-${clip.day.key}-${clip.ordinal}';

  /// A movie → the player, by its path relative to `Movies/`.
  static String movie(String file) => 'movie-$file';
}
