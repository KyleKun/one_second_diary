import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/router/hero_tags.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_thumbnail_view.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hero.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';

/// A clip's media as one end of the flight to and from the viewer (`OsdHero`
/// with `HeroTags.clip`, the corners morphing from [radius] to the viewer's 0).
///
/// - A flying copy is built in the navigator's overlay, above the page's
///   `PlayerPool`, where a `ClipPlayerView` can't play: it shows the clip's
///   poster and [child] takes over when the flight lands.
/// - It flies only while its page shows (`TickerMode`), so the same clip on
///   another tab never makes a second hero with the same tag.
/// - It flies only when [enabled]: the calendar's cell and its mini player
///   show the same clip, and only the one the viewer opened from flies.
class ClipHero extends StatelessWidget {
  const ClipHero({
    super.key,
    required this.clip,
    required this.radius,
    required this.slot,
    required this.orientation,
    required this.child,
    this.enabled = true,
  });

  final ClipRef clip;

  /// The corner radius here (the flight morphs it).
  final double radius;

  /// How the poster fills the frame in flight.
  final ClipThumbnailSlot slot;

  /// The profile's orientation.
  final VideoOrientation orientation;

  /// The media at rest.
  final Widget child;

  /// Whether this is the flight's end here.
  final bool enabled;

  @override
  Widget build(BuildContext context) => HeroMode(
    enabled: enabled && TickerMode.valuesOf(context).enabled,
    child: OsdHero(
      tag: HeroTags.clip(clip),
      radius: radius,
      child: _FlightSafe(
        clip: clip,
        slot: slot,
        orientation: orientation,
        child: child,
      ),
    ),
  );
}

/// [child] where the page's `PlayerPool` is in reach, the clip's poster in
/// a flight shuttle, where it is not.
class _FlightSafe extends StatelessWidget {
  const _FlightSafe({
    required this.clip,
    required this.slot,
    required this.orientation,
    required this.child,
  });

  final ClipRef clip;
  final ClipThumbnailSlot slot;
  final VideoOrientation orientation;
  final Widget child;

  @override
  Widget build(BuildContext context) => context.read<PlayerPool?>() == null
      ? ClipThumbnailView(clip: clip, slot: slot, orientation: orientation)
      : child;
}
