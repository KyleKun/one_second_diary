import 'package:flutter/material.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_thumbnail_view.dart';
import 'package:one_second_diary/features/movies/presentation/bloc/movie_job_state.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';

/// One clip of the making page's grid: its thumbnail in one of three states,
/// each change animated over `OsdMotion.processing`.
class ProcessingThumb extends StatelessWidget {
  const ProcessingThumb({
    super.key,
    required this.clip,
    required this.orientation,
    required this.done,
    required this.current,
  });

  /// The cell of [clip] (give it to the thumb).
  static Key cellKey(ClipRef clip) =>
      ValueKey<(String, ClipRef)>(('processingThumb', clip));

  /// A pending clip's opacity.
  static const double pendingOpacity = .35;

  /// The clip in hand's scale.
  static const double currentScale = 1.08;

  /// Whether [index] of [job]'s clips is done, and whether it is the one in
  /// hand.
  static ({bool done, bool current}) stateOf(MovieJobState job, int index) => (
    done:
        index < job.processed ||
        job.status == MovieJobStatus.finishing ||
        job.status == MovieJobStatus.done,
    current: job.currentIndex == index,
  );

  final ClipRef clip;

  /// The movie's canvas (the thumbnail covers the cell either way).
  final VideoOrientation orientation;

  final bool done;

  final bool current;

  @override
  Widget build(BuildContext context) {
    final Duration duration = OsdMotion.d(context, OsdMotion.processing);
    final Curve curve = OsdMotion.curve(context, OsdMotion.processingCurve);
    final bool pending = !done && !current;
    final BorderRadius radius = BorderRadius.circular(OsdRadius.r10);
    final Color ring = context.colors.co;
    return AnimatedScale(
      // No scale under reduced motion: the ring says it.
      scale: current && !OsdMotion.reduced(context) ? currentScale : 1,
      duration: duration,
      curve: curve,
      child: AnimatedContainer(
        duration: duration,
        curve: curve,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: current ? ring : ring.withValues(alpha: 0),
              spreadRadius: 2,
            ),
          ],
        ),
        child: AnimatedOpacity(
          opacity: pending ? pendingOpacity : 1,
          duration: duration,
          curve: curve,
          child: _Greyed(
            grey: pending,
            duration: duration,
            curve: curve,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ClipThumbnailView(
                  clip: clip,
                  slot: ClipThumbnailSlot.tile,
                  orientation: orientation,
                  radius: OsdRadius.r10,
                ),
                PositionedDirectional(
                  end: 3,
                  bottom: 3,
                  child: _DoneBadge(visible: done),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [child] in greyscale at brightness .7 (CSS `grayscale(1) brightness(.7)`)
/// while [grey], tweened in and out; no filter layer at all once in full
/// colour.
class _Greyed extends StatelessWidget {
  const _Greyed({
    required this.grey,
    required this.duration,
    required this.curve,
    required this.child,
  });

  final bool grey;
  final Duration duration;
  final Curve curve;
  final Widget child;

  /// CSS `grayscale(1)`'s luminance weights, then `brightness(.7)`.
  static const double _r = .2126 * .7;
  static const double _g = .7152 * .7;
  static const double _b = .0722 * .7;

  static List<double> _matrix(double t) {
    double mix(double identity, double greyed) =>
        identity + (greyed - identity) * t;
    return <double>[
      mix(1, _r), mix(0, _g), mix(0, _b), 0, 0, //
      mix(0, _r), mix(1, _g), mix(0, _b), 0, 0, //
      mix(0, _r), mix(0, _g), mix(1, _b), 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(end: grey ? 1 : 0),
    duration: duration,
    curve: curve,
    child: child,
    builder: (BuildContext context, double t, Widget? child) => t == 0
        ? child!
        : ColorFiltered(
            colorFilter: ColorFilter.matrix(_matrix(t)),
            child: child,
          ),
  );
}

/// The green circle with a check (dark on green in both themes), popping
/// in.
class _DoneBadge extends StatelessWidget {
  const _DoneBadge({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final Duration duration = OsdMotion.d(context, OsdMotion.badgeIn);
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: duration,
      curve: OsdMotion.curve(context, OsdMotion.fastCurve),
      child: AnimatedScale(
        scale: visible ? 1 : OsdMotion.badgeInScale,
        duration: duration,
        curve: OsdMotion.curve(context, OsdMotion.badgeInCurve),
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: OsdMedia.doneBadge,
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: 16,
            child: Center(
              child: OsdIcon(
                OsdIcons.check,
                size: 12,
                color: OsdMedia.doneBadgeInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
