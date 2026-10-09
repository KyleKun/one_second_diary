import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

enum PlayOverlaySize {
  medium(50, 30),

  large(54, 32),

  extraLarge(64, 38);

  const PlayOverlaySize(this.box, this.glyph);

  /// The circle diameter.
  final double box;

  final double glyph;
}

/// The play circle over paused media. After a natural end it shows `replay`.
///
/// It is a visual only: the whole media surface is the tap target and carries
/// the "Play" semantics, so this is excluded from semantics. While playing
/// ([visible] false) it fades and shrinks away.
class PlayOverlayButton extends StatelessWidget {
  const PlayOverlayButton({
    super.key,
    this.size = PlayOverlaySize.large,
    this.ended = false,
    this.visible = true,
  });

  static const Key circleKey = Key('playOverlayButton.circle');

  final PlayOverlaySize size;

  /// Whether the clip ended naturally (shows `replay`).
  final bool ended;

  /// False while playing.
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final duration = OsdMotion.d(
      context,
      visible ? const Duration(milliseconds: 200) : OsdMotion.fast,
    );
    final reduced = OsdMotion.reduced(context);
    return ExcludeSemantics(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: duration,
        child: AnimatedScale(
          scale: visible || reduced ? 1 : .88,
          duration: duration,
          curve: OsdMotion.curve(context, Curves.easeOut),
          child: SizedBox.square(
            key: circleKey,
            dimension: size.box,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: OsdMedia.scrim45,
                shape: BoxShape.circle,
                border: Border.all(
                  color: OsdMedia.ring60,
                  width: 1.5,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
              ),
              child: Center(
                // Optical centring toward the triangle's point, which is
                // physical right: play_arrow never mirrors.
                child: Transform.translate(
                  offset: Offset(ended ? 0 : 1.5, 0),
                  child: OsdIcon(
                    ended ? OsdIcons.replay : OsdIcons.playArrow,
                    size: size.glyph,
                    fill: 1,
                    color: OsdMedia.onMedia,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
