import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/viewer_dismiss.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/viewer_swipe.dart';
import 'package:one_second_diary/shared/widgets/foundation/sideways_chrome.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_viewer.dart';

/// Where the viewer's parts go, and how they move:
///
/// - **Upright** (and on tablets): the bar, then the video in the middle of
///   the room with its progress under it, then the bottom row: the caption
///   across it, the two buttons at its end ([_BottomRow]).
/// - **A phone turned sideways**: the video fills the screen (contained);
///   the bar and, at the bottom, the same row, low (the compact caption,
///   the compact buttons at the end) over the progress lie over it on
///   gradients, so most of the video stays clear. They hide [chromeLinger]
///   after the last touch, and a tap brings them back (a tap on the video
///   then plays or pauses again); with a screen reader on they stay
///   ([SidewaysChrome], shared with the movie player).
/// - The chrome rises in shortly after the video began its flight (at once
///   under reduced motion).
/// - A drag down closes the viewer ([ViewerDismiss]): the video follows the
///   finger, the chrome fades, the page below shows through.
/// - A swipe sideways anywhere on the screen steps to the previous or next
///   clip ([ViewerSwipe]): the video leans the way it will go, and gives a
///   little at the ends.
class ViewerLayout extends StatefulWidget {
  const ViewerLayout({
    super.key,
    required this.bar,
    required this.video,
    required this.progress,
    required this.caption,
    required this.actions,
    required this.sidewaysCaption,
    required this.sidewaysActions,
    required this.onDismiss,
    required this.onPrevious,
    required this.onNext,
  });

  /// The black page.
  static const Key backgroundKey = Key('viewerLayout.background');

  /// The gradients under the chrome of a phone turned sideways.
  static const Key topScrimKey = Key('viewerLayout.topScrim');
  static const Key bottomScrimKey = Key('viewerLayout.bottomScrim');

  /// How long the chrome of a phone turned sideways stays after a touch.
  static const Duration chromeLinger = SidewaysChrome.linger;

  final Widget bar;

  /// The video, with how much its own chrome (the chevrons) shows.
  final Widget Function(Animation<double> chrome) video;

  final Widget progress;

  /// The caption and the buttons of the bottom row.
  final Widget caption;
  final Widget actions;

  /// The caption and the buttons of a phone turned sideways: compact, in
  /// one low row over the bottom of the video.
  final Widget sidewaysCaption;
  final Widget sidewaysActions;

  /// The upright row's bottom: the design's 28, or 12 above a home
  /// indicator.
  static const double _uprightBottom = 28;
  static const double _aboveInset = 12;

  /// The row's side margins.
  static const double _side = 16;

  static const double _sidewaysBottom = 8;

  /// Closes the viewer (a drag down).
  final VoidCallback onDismiss;

  /// Steps to the previous or next clip (a swipe sideways); null at the
  /// first or last, where the swipe only gives a little.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  State<ViewerLayout> createState() => _ViewerLayoutState();
}

class _ViewerLayoutState extends State<ViewerLayout>
    with TickerProviderStateMixin {
  /// The chrome rises in once the video has begun its flight.
  static const Duration _chromeDelay = Duration(milliseconds: 80);

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: _chromeDelay + OsdMotion.standard,
  );
  late final CurvedAnimation _chromeIn = CurvedAnimation(
    parent: _entrance,
    curve: Interval(
      _chromeDelay.inMicroseconds / _entrance.duration!.inMicroseconds,
      1,
      curve: OsdMotion.standardCurve,
    ),
  );

  /// Where the viewer's video lives, kept as the phone turns.
  final GlobalKey _videoKey = GlobalKey();

  bool _entered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entered) return;
    _entered = true;
    if (OsdMotion.reduced(context)) {
      _entrance.value = 1;
    } else {
      unawaited(_entrance.forward());
    }
  }

  @override
  void dispose() {
    _chromeIn.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SidewaysChrome(
    builder: (BuildContext context, SidewaysChromeState sideways) =>
        ViewerDismiss(
          onDismiss: widget.onDismiss,
          builder: (BuildContext context, Animation<double> drag) => Builder(
            builder: (BuildContext context) {
              final Animation<double> dragFade = drag.drive(
                ViewerDismiss.chromeFade,
              );
              final Animation<double> chrome = AnimationMin<double>(
                dragFade,
                sideways.shown,
              );
              return ViewerSwipe(
                onPrevious: widget.onPrevious,
                onNext: widget.onNext,
                builder: (BuildContext context, Animation<double> shift) {
                  final Widget video = _Dragged(
                    drag: drag,
                    shift: shift,
                    child: KeyedSubtree(
                      key: _videoKey,
                      child: widget.video(chrome),
                    ),
                  );
                  return Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      FadeTransition(
                        opacity: drag.drive(ViewerDismiss.backgroundFade),
                        child: const ColoredBox(
                          key: ViewerLayout.backgroundKey,
                          color: OsdViewer.background,
                        ),
                      ),
                      if (sideways.sideways)
                        _Sideways(
                          bar: _Chrome(
                            entrance: _chromeIn,
                            visible: chrome,
                            from: -_Chrome.rise,
                            child: DecoratedBox(
                              key: ViewerLayout.topScrimKey,
                              decoration: SidewaysChrome.scrim(top: true),
                              child: widget.bar,
                            ),
                          ),
                          video: video,
                          bottom: _Chrome(
                            entrance: _chromeIn,
                            visible: chrome,
                            child: DecoratedBox(
                              key: ViewerLayout.bottomScrimKey,
                              decoration: SidewaysChrome.scrim(top: false),
                              child: SafeArea(
                                top: false,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    _BottomRow(
                                      caption: widget.sidewaysCaption,
                                      actions: widget.sidewaysActions,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: ViewerLayout._side,
                                      ),
                                    ),
                                    widget.progress,
                                    const SizedBox(
                                      height: ViewerLayout._sidewaysBottom,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          onRevealTap: sideways.reveal,
                          onHideTap: sideways.hide,
                        )
                      else
                        _Upright(
                          bar: _Chrome(
                            entrance: _chromeIn,
                            visible: chrome,
                            from: -_Chrome.rise,
                            child: widget.bar,
                          ),
                          video: video,
                          progress: _Chrome(
                            entrance: _chromeIn,
                            visible: chrome,
                            child: widget.progress,
                          ),
                          bottom: _Chrome(
                            entrance: _chromeIn,
                            visible: chrome,
                            child: _BottomRow(
                              caption: widget.caption,
                              actions: widget.actions,
                              padding: EdgeInsets.fromLTRB(
                                ViewerLayout._side,
                                ViewerLayout._side,
                                ViewerLayout._side,
                                math.max(
                                  ViewerLayout._uprightBottom,
                                  MediaQuery.viewPaddingOf(context).bottom +
                                      ViewerLayout._aboveInset,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
  );
}

/// The upright viewer: the bar, the video with its progress
/// ([_CentredVideo]), the bottom row.
class _Upright extends StatelessWidget {
  const _Upright({
    required this.bar,
    required this.video,
    required this.progress,
    required this.bottom,
  });

  final Widget bar;
  final Widget video;
  final Widget progress;
  final Widget bottom;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      bar,
      Expanded(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: OsdSizes.mediaMaxWidth),
            child: CustomMultiChildLayout(
              delegate: _CentredVideo(),
              children: <Widget>[
                LayoutId(id: _Part.video, child: video),
                LayoutId(id: _Part.progress, child: progress),
              ],
            ),
          ),
        ),
      ),
      bottom,
    ],
  );
}

enum _Part { video, progress }

/// The video in the middle of the room, as large as the room less the
/// progress and [_clear] above and below allows, so the progress of a clip
/// that fills the room (a portrait one) stays clear of the bottom row. The
/// progress goes right under it.
class _CentredVideo extends MultiChildLayoutDelegate {
  /// The least room between the progress and the bottom row.
  static const double _clear = 16;

  @override
  void performLayout(Size size) {
    final BoxConstraints wide = BoxConstraints(
      minWidth: size.width,
      maxWidth: size.width,
      maxHeight: size.height,
    );
    final Size progress = layoutChild(_Part.progress, wide);
    final Size video = layoutChild(
      _Part.video,
      BoxConstraints(
        maxWidth: size.width,
        maxHeight: math.max(0, size.height - 2 * (progress.height + _clear)),
      ),
    );
    final double videoTop = (size.height - video.height) / 2;
    positionChild(
      _Part.video,
      Offset((size.width - video.width) / 2, videoTop),
    );
    positionChild(_Part.progress, Offset(0, videoTop + video.height));
  }

  @override
  bool shouldRelayout(_CentredVideo oldDelegate) => false;
}

/// The bottom row: the caption across it (the subtitle, the tags, the
/// badges), the buttons (Share, Edit) at its end, no wider than the video
/// on a tablet. The caption takes what the buttons leave, however many
/// lines; the buttons never shrink.
class _BottomRow extends StatelessWidget {
  const _BottomRow({
    required this.caption,
    required this.actions,
    required this.padding,
  });

  /// Between the caption and the buttons.
  static const double _gap = 12;

  final Widget caption;
  final Widget actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: OsdSizes.mediaMaxWidth),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: _gap,
          children: <Widget>[
            Expanded(child: caption),
            actions,
          ],
        ),
      ),
    ),
  );
}

/// A phone turned sideways: the video fills the screen, the chrome lies
/// over it; a tap beside the video and the controls hides the chrome, and
/// while it is hidden a tap anywhere brings it back.
class _Sideways extends StatelessWidget {
  const _Sideways({
    required this.bar,
    required this.video,
    required this.bottom,
    required this.onRevealTap,
    required this.onHideTap,
  });

  final Widget bar;
  final Widget video;
  final Widget bottom;

  /// Brings the chrome back; null while it shows.
  final VoidCallback? onRevealTap;

  /// Hides the chrome; null while it is hidden.
  final VoidCallback? onHideTap;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onRevealTap = this.onRevealTap;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: onHideTap,
        ),
        Center(child: video),
        // The scrims take hits of their own.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GestureDetector(onTap: onHideTap, child: bar),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: GestureDetector(onTap: onHideTap, child: bottom),
        ),
        if (onRevealTap != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRevealTap,
            ),
          ),
      ],
    );
  }
}

/// A part of the chrome (the bar, the progress, the bottom row):
/// it fades in sliding to its place as the viewer opens, and shows as much
/// as [visible] says (a drag down, a phone turned sideways).
class _Chrome extends StatelessWidget {
  const _Chrome({
    required this.entrance,
    required this.visible,
    required this.child,
    this.from = _Chrome.rise,
  });

  /// How far the chrome slides in.
  static const double rise = 12;

  final Animation<double> entrance;
  final Animation<double> visible;

  /// Where it slides in from: below (positive) or above (negative).
  final double from;
  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: entrance,
    child: FadeTransition(
      opacity: visible,
      child: AnimatedBuilder(
        animation: entrance,
        builder: (BuildContext context, Widget? child) => Transform.translate(
          offset: Offset(0, (1 - entrance.value) * from),
          child: child,
        ),
        child: child,
      ),
    ),
  );
}

/// The video as it is dragged down (it follows the finger and shrinks) or
/// swiped sideways (it leans the way it will go).
class _Dragged extends StatelessWidget {
  const _Dragged({
    required this.drag,
    required this.shift,
    required this.child,
  });

  final Animation<double> drag;
  final Animation<double> shift;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge(<Listenable>[drag, shift]),
    builder: (BuildContext context, Widget? child) => Transform.translate(
      offset: Offset(shift.value, drag.value),
      child: Transform.scale(
        scale: ViewerDismiss.scaleAt(context, drag.value),
        child: child,
      ),
    ),
    child: child,
  );
}
