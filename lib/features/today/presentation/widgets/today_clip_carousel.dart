import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/today/domain/today_carousel_geometry.dart';
import 'package:one_second_diary/features/today/presentation/today_motion.dart';
import 'package:one_second_diary/features/today/presentation/widgets/clip_snap_physics.dart';
import 'package:one_second_diary/features/today/presentation/widgets/today_clip_page.dart';
import 'package:one_second_diary/shared/widgets/progress/page_dots.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The day's clips on Today's stage: one clip fills the frame; several sit
/// in a pager that shows one clip at a time, whole, with page dots below
/// (a "3 / 12" counter above 7 clips).
///
/// - It opens on the clip in view ([visible]), and moves to the one the
///   day brings into view: a new clip, or the latest after one went away.
///   A swipe snaps (`ClipSnapPhysics`), and the page it settles on is
///   reported ([onShow], with a selection haptic): Edit acts on it.
/// - Only the page in view plays; its neighbours are kept warm. Pages
///   fade and their overlays follow how much each is in view, repainting
///   only.
/// - A tap on a dot brings its clip into view.
/// - The dots fade in with the second clip.
/// - Screen readers page through it with increase / decrease ("Video 2 of
///   3"); the dots are not exposed to them.
/// - The list is lazy: only the pages in view and the next are built.
class TodayClipCarousel extends StatefulWidget {
  const TodayClipCarousel({
    super.key,
    required this.clips,
    required this.visible,
    required this.frame,
    required this.orientation,
    required this.onShow,
    this.onOpen,
    this.landing = const <ClipRef>{},
  });

  static const Key dotsKey = Key('todayClipCarousel.dots');

  /// The day's clips, in recording order.
  final List<ClipRef> clips;

  /// The clip in view.
  final ClipRef visible;

  final Size frame;

  final VideoOrientation orientation;

  /// A swipe (or a tap on a dot) brought [clip] into view.
  final ValueChanged<ClipRef> onShow;

  /// Opens the clip in view in the viewer (a long press).
  final ValueChanged<ClipRef>? onOpen;

  /// Clips that just arrived: their Saved badge lands.
  final Set<ClipRef> landing;

  /// The room the dots take under the frame for [count] clips at
  /// [textScaler]: none for one clip, the counter's line above 7 clips.
  static double dotsExtent(int count, TextScaler textScaler) {
    if (count < 2) return 0;
    if (count <= _maxDots) return _dotsGap + _dotsHeight;
    return _dotsGap +
        math.max(_counterMinHeight, (textScaler.scale(13) * 1.25).ceil());
  }

  static const int _maxDots = 7;
  static const double _dotsGap = 14;
  static const double _dotsHeight = 8;
  static const double _counterMinHeight = 16;

  @override
  State<TodayClipCarousel> createState() => _TodayClipCarouselState();
}

class _TodayClipCarouselState extends State<TodayClipCarousel> {
  ScrollController? _scroll;

  /// The layout of the last build.
  late TodayCarouselGeometry _geometry;

  /// The page in view: the nearest to the scroll offset.
  late int _index = _indexOfVisible;

  /// The pager is moving to a page on its own (not the user's swipe), or
  /// about to: the pages it passes are not reported, and a change of
  /// layout meanwhile does not hold it on the page it leaves.
  bool _moving = false;

  int get _indexOfVisible => math.max(0, widget.clips.indexOf(widget.visible));

  int get _count => widget.clips.length;

  double get _offset {
    final ScrollController? scroll = _scroll;
    return scroll != null && scroll.hasClients
        ? scroll.offset
        : _geometry.targetOf(_index);
  }

  @override
  void didUpdateWidget(TodayClipCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible &&
        listEquals(widget.clips, oldWidget.clips)) {
      return;
    }
    final int target = _indexOfVisible;
    final bool grew = _count > oldWidget.clips.length;
    // A swipe already shows the clip it reported; anything else (a new
    // clip, one gone) makes its clip the page in view at once (it plays,
    // its badge lands there) and moves the pager to it once the new layout
    // is in.
    if (target == _index && !grew) return;
    _index = target;
    _moving = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _moving = false;
      _moveTo(
        target,
        duration: grew ? TodayMotion.newClipInView : TodayMotion.resnap,
        curve: grew ? TodayMotion.newClipInViewCurve : OsdMotion.standardCurve,
      );
    });
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  /// Moves the pager to page [index]; the page in view is reported once
  /// it gets there.
  void _moveTo(int index, {required Duration duration, required Curve curve}) {
    final ScrollController? scroll = _scroll;
    if (scroll == null || !scroll.hasClients) return;
    final double target = _geometry.targetOf(index);
    if (scroll.offset == target) return;
    if (OsdMotion.reduced(context)) {
      scroll.jumpTo(target);
      return;
    }
    _moving = true;
    unawaited(
      scroll.animateTo(target, duration: duration, curve: curve).whenComplete(
        () {
          _moving = false;
          if (mounted && scroll.hasClients) _onScroll();
        },
      ),
    );
  }

  /// Where the page in view rests in the layout of the last build; null
  /// while the pager moves on its own.
  double? _restingOffset() => _moving ? null : _geometry.targetOf(_index);

  void _bringIntoView(int index) => _moveTo(
    index,
    duration: TodayMotion.dotTap,
    curve: TodayMotion.dotTapCurve,
  );

  /// A tap on the dot of page [index].
  void _tapDot(int index) {
    if (index == _index) return;
    unawaited(OsdHaptic.selection.play());
    _bringIntoView(index);
  }

  /// Follows the page in view: a new one is reported (Edit acts on it),
  /// with a selection haptic when the user moved the pager.
  void _onScroll() {
    final ScrollController scroll = _scroll!;
    if (_moving) return;
    final int index = _geometry.indexAt(scroll.offset);
    if (index == _index) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      // Corrected during layout: catch up after the frame.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && scroll.hasClients) _onScroll();
      });
      return;
    }
    setState(() => _index = index);
    if (scroll.position.userScrollDirection != ScrollDirection.idle) {
      unawaited(OsdHaptic.selection.play());
    }
    widget.onShow(widget.clips[index]);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      _geometry = TodayCarouselGeometry(
        viewport: constraints.maxWidth,
        count: _count,
      );
      final ScrollController scroll = _scroll ??= ScrollController(
        initialScrollOffset: _geometry.targetOf(_index),
      )..addListener(_onScroll);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: widget.frame.height,
            child: _Pager(
              scroll: scroll,
              geometry: _geometry,
              geometryNow: () => _geometry,
              restingOffset: _restingOffset,
              clips: widget.clips,
              index: _index,
              landing: widget.landing,
              onOpen: widget.onOpen,
              frame: widget.frame,
              orientation: widget.orientation,
              onTapPage: _bringIntoView,
            ),
          ),
          if (_count > 1)
            _Dots(
              key: TodayClipCarousel.dotsKey,
              scroll: scroll,
              geometryNow: () => _geometry,
              count: _count,
              offset: () => _offset,
              onTap: _tapDot,
            ),
        ],
      );
    },
  );
}

/// The horizontal list of pages, with its screen-reader actions.
class _Pager extends StatelessWidget {
  const _Pager({
    required this.scroll,
    required this.geometry,
    required this.geometryNow,
    required this.restingOffset,
    required this.clips,
    required this.index,
    required this.landing,
    required this.onOpen,
    required this.frame,
    required this.orientation,
    required this.onTapPage,
  });

  final ScrollController scroll;
  final TodayCarouselGeometry geometry;
  final ValueGetter<TodayCarouselGeometry> geometryNow;
  final ValueGetter<double?> restingOffset;
  final List<ClipRef> clips;
  final int index;
  final Set<ClipRef> landing;
  final ValueChanged<ClipRef>? onOpen;
  final Size frame;
  final VideoOrientation orientation;
  final ValueChanged<int> onTapPage;

  @override
  Widget build(BuildContext context) {
    final int count = clips.length;
    final bool portrait = orientation == VideoOrientation.portrait;
    String positionOf(int page) =>
        Strings.todayClipPositionA11y(index: page + 1, count: count);
    final Widget list = ListView.builder(
      controller: scroll,
      scrollDirection: Axis.horizontal,
      physics: ClipSnapPhysics(
        geometry: geometryNow,
        restingOffset: restingOffset,
        reducedMotion: OsdMotion.reduced(context),
      ),
      itemCount: count,
      itemExtentBuilder: (int page, _) => page == count - 1
          ? geometry.viewport
          : geometry.viewport + TodayCarouselGeometry.gap,
      findChildIndexCallback: (Key key) {
        final int page = key is ValueKey<ClipRef>
            ? clips.indexOf(key.value)
            : -1;
        return page < 0 ? null : page;
      },
      itemBuilder: (BuildContext context, int page) {
        final ClipRef clip = clips[page];
        final Animation<double> focus = _PageFocus(
          scroll: scroll,
          geometry: geometryNow,
          page: page,
          fallback: index,
        );
        return Padding(
          key: ValueKey<ClipRef>(clip),
          padding: EdgeInsetsDirectional.only(
            end: page == count - 1 ? 0 : TodayCarouselGeometry.gap,
          ),
          // The clip at the frame's size, in the middle of its page.
          child: Center(
            child: SizedBox.fromSize(
              size: frame,
              child: FadeTransition(
                opacity: focus.drive(
                  Tween<double>(begin: _awayOpacity, end: 1),
                ),
                child: ScaleTransition(
                  scale: portrait
                      ? focus.drive(Tween<double>(begin: _awayScale, end: 1))
                      : const AlwaysStoppedAnimation<double>(1),
                  child: page == index
                      ? TodayClipPage(
                          clip: clip,
                          frame: frame,
                          orientation: orientation,
                          playable: true,
                          neighbours: <ClipRef>[
                            if (page > 0) clips[page - 1],
                            if (page < count - 1) clips[page + 1],
                          ],
                          overlayOpacity: focus,
                          landing: landing.contains(clip),
                          onOpen: onOpen == null ? null : () => onOpen!(clip),
                        )
                      : ExcludeSemantics(
                          child: TodayClipPage(
                            clip: clip,
                            frame: frame,
                            orientation: orientation,
                            playable: false,
                            overlayOpacity: focus,
                            onTap: () => onTapPage(page),
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
    // Always there, so the list keeps its place in the tree (and its
    // scroll position) when the second clip arrives.
    final bool paged = count > 1;
    return Semantics(
      container: paged,
      value: paged ? positionOf(index) : null,
      increasedValue: paged && index < count - 1 ? positionOf(index + 1) : null,
      decreasedValue: paged && index > 0 ? positionOf(index - 1) : null,
      onIncrease: paged && index < count - 1
          ? () => onTapPage(index + 1)
          : null,
      onDecrease: paged && index > 0 ? () => onTapPage(index - 1) : null,
      child: list,
    );
  }

  /// The opacity of a page as it leaves the view.
  static const double _awayOpacity = .6;

  /// The scale of a portrait page as it leaves the view.
  static const double _awayScale = .94;
}

/// The page dots, following the scroll continuously; they fade in with
/// the second clip. A tap on one brings its page into view ([onTap]).
class _Dots extends StatelessWidget {
  const _Dots({
    super.key,
    required this.scroll,
    required this.geometryNow,
    required this.count,
    required this.offset,
    required this.onTap,
  });

  final ScrollController scroll;
  final ValueGetter<TodayCarouselGeometry> geometryNow;
  final int count;
  final ValueGetter<double> offset;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: 1),
    duration: OsdMotion.d(context, OsdMotion.selection),
    curve: OsdMotion.selectionCurve,
    builder: (BuildContext context, double shown, Widget? dots) =>
        Opacity(opacity: shown, child: dots),
    child: Center(
      child: ListenableBuilder(
        listenable: scroll,
        builder: (BuildContext context, _) => PageDots(
          count: count,
          position: geometryNow().positionAt(offset()),
          onTap: onTap,
          // Inside the dots, so a tap just above one counts.
          padding: const EdgeInsets.only(top: TodayClipCarousel._dotsGap),
          counterText: (int index, int count) =>
              Strings.todayClipCounter(index: index, count: count),
        ),
      ),
    ),
  );
}

/// How much page [page] is in view: 1 in view, 0 a page or more away,
/// read from the pager's scroll offset (before the first layout, whether
/// it is the [fallback] page).
class _PageFocus extends Animation<double> {
  _PageFocus({
    required this.scroll,
    required this.geometry,
    required this.page,
    required this.fallback,
  });

  final ScrollController scroll;
  final ValueGetter<TodayCarouselGeometry> geometry;
  final int page;
  final int fallback;

  @override
  double get value {
    final double position = scroll.hasClients
        ? geometry().positionAt(scroll.offset)
        : fallback.toDouble();
    return 1 - (position - page).abs().clamp(0, 1);
  }

  @override
  AnimationStatus get status => AnimationStatus.forward;

  @override
  void addListener(VoidCallback listener) => scroll.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => scroll.removeListener(listener);

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}
}
