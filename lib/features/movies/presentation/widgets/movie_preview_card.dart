import 'package:flutter/material.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/router/hero_tags.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/thumbnail_tier.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_thumbnail_view.dart';
import 'package:one_second_diary/shared/widgets/buttons/play_overlay_button.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hero.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_radius.dart';

/// The created page's preview of the movie just made: its first frame, the
/// poster of its first clip (already made for the earlier pages, so it shows at
/// once), with the play circle; the whole card plays the movie ([onTap], as
/// Watch does) and flies into the player (`HeroTags.movie`).
class MoviePreviewCard extends StatelessWidget {
  const MoviePreviewCard({
    super.key,
    required this.file,
    required this.poster,
    required this.orientation,
    required this.semanticsLabel,
    required this.onTap,
  });

  static const Key cardKey = Key('moviePreviewCard');

  /// A landscape card's width over its height.
  static const double landscapeRatio = 350 / 201;

  /// The tallest a portrait card gets.
  static const double maxPortraitHeight = 360;

  /// The movie, relative to `Movies/` (the hero's tag).
  final String file;

  /// The clip whose poster shows; null draws the loading surface.
  final ClipRef? poster;

  final VideoOrientation orientation;

  /// "Watch {name}".
  final String semanticsLabel;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(OsdRadius.r24);
    final ClipRef? clip = poster;
    // The play circle shows at once, the poster fading in under it.
    final Widget picture = OsdHero(
      tag: HeroTags.movie(file),
      radius: OsdRadius.r24,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (clip == null)
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.colors.c2,
                borderRadius: radius,
              ),
            )
          else
            ClipThumbnailView(
              clip: clip,
              slot: ClipThumbnailSlot.todayFrame,
              orientation: orientation,
              tier: ThumbnailTier.poster,
              radius: OsdRadius.r24,
            ),
          const Center(
            child: PlayOverlayButton(size: PlayOverlaySize.extraLarge),
          ),
        ],
      ),
    );
    final Widget card = OsdPressable(
      key: cardKey,
      onTap: onTap,
      borderRadius: radius,
      semanticsLabel: semanticsLabel,
      excludeChildSemantics: true,
      child: picture,
    );
    return orientation == VideoOrientation.landscape
        ? AspectRatio(aspectRatio: landscapeRatio, child: card)
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: maxPortraitHeight),
              child: AspectRatio(aspectRatio: 9 / 16, child: card),
            ),
          );
  }
}
