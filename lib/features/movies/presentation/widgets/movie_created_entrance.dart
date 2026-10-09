import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// Which part of the created page enters.
enum MovieCreatedPart {
  /// The preview: fades in and grows.
  preview(Duration.zero, OsdMotion.emphasized),

  /// "Movie created!" and where it was saved: fade in and rise.
  words(Duration(milliseconds: 100), Duration(milliseconds: 250)),

  /// Watch, Share and Done: fade in.
  buttons(Duration(milliseconds: 180), Duration(milliseconds: 200));

  const MovieCreatedPart(this.delay, this.duration);

  /// From the page's first frame.
  final Duration delay;
  final Duration duration;

  /// The whole entrance, the last part's end.
  static Duration get total => buttons.delay + buttons.duration;
}

/// One part of the created page's entrance, driven by the page's [animation] (0
/// → 1 over [MovieCreatedPart.total], once). Only transform and opacity move.
class MovieCreatedEntrance extends StatelessWidget {
  const MovieCreatedEntrance({
    super.key,
    required this.animation,
    required this.part,
    required this.child,
  });

  /// The preview's starting scale.
  static const double previewScale = .94;

  final Animation<double> animation;
  final MovieCreatedPart part;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final int total = MovieCreatedPart.total.inMicroseconds;
    // Built on every rebuild: a CurveTween keeps no listener of its own on
    // [animation], where a CurvedAnimation made here would leak one.
    final Animation<double> t = animation.drive(
      CurveTween(
        curve: Interval(
          part.delay.inMicroseconds / total,
          (part.delay + part.duration).inMicroseconds / total,
          curve: OsdMotion.standardCurve,
        ),
      ),
    );
    return FadeTransition(
      opacity: t,
      child: switch (part) {
        MovieCreatedPart.preview => ScaleTransition(
          scale: Tween<double>(begin: previewScale, end: 1).animate(t),
          child: child,
        ),
        MovieCreatedPart.words => AnimatedBuilder(
          animation: t,
          builder: (BuildContext context, Widget? child) => Transform.translate(
            offset: Offset(0, OsdMotion.entranceRise * (1 - t.value)),
            child: child,
          ),
          child: child,
        ),
        MovieCreatedPart.buttons => child,
      },
    );
  }
}
