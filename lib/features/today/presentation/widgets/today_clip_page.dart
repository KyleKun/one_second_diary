import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_hero.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_playback.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_player_view.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_thumbnail_view.dart';
import 'package:one_second_diary/features/today/presentation/today_motion.dart';
import 'package:one_second_diary/shared/widgets/buttons/play_overlay_button.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';
import 'package:one_second_diary/shared/widgets/media/saved_badge.dart';
import 'package:one_second_diary/shared/widgets/surfaces/player_error_block.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// One of the day's clips on Today's stage: the clip's poster with the
/// Saved badge and the play button over it.
///
/// - The clip is laid out at the [frame]'s size and centred in the page,
///   which may be narrower (the pager's pages crop it like
///   `BoxFit.cover`), so the poster keeps one size, and one decode, as the
///   frame narrows to a page and when its player takes over.
/// - The page in view ([playable]) plays inline through the screen's
///   `PlayerPool` (`ClipPlayerView`, never on its own: no autoplay on
///   Today), with its [neighbours] warm. A tap plays it with sound, a tap
///   while it plays pauses it; it plays once, then its first frame comes
///   back with the overlays. While it plays the badge and the play button
///   fade out.
/// - A page not in view shows its poster; [onTap] brings it into view.
class TodayClipPage extends StatelessWidget {
  const TodayClipPage({
    super.key,
    required this.clip,
    required this.frame,
    required this.orientation,
    required this.playable,
    this.neighbours = const <ClipRef>[],
    this.overlayOpacity,
    this.landing = false,
    this.onTap,
    this.onOpen,
  });

  /// The whole page: the play target of the page in view.
  static const Key targetKey = Key('todayClipPage.target');

  final ClipRef clip;

  /// The frame's size (the stage's clip frame in the profile's shape).
  final Size frame;

  final VideoOrientation orientation;

  /// Whether this is the page in view, which plays.
  final bool playable;

  /// The clips beside it, kept warm while it is in view.
  final List<ClipRef> neighbours;

  /// How much the badge and the play button show (they follow how much
  /// the page is in view); fully when null.
  final Animation<double>? overlayOpacity;

  /// Whether the clip just arrived: its Saved badge lands.
  final bool landing;

  /// Brings a page not in view into view.
  final VoidCallback? onTap;

  /// Opens the page in view in the viewer (a long press).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => ClipHero(
    clip: clip,
    radius: OsdRadius.r4,
    slot: ClipThumbnailSlot.todayFrame,
    orientation: orientation,
    child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints page) {
        final double inset = (frame.width - page.maxWidth) / 2;
        return OverflowBox(
          minWidth: frame.width,
          maxWidth: frame.width,
          minHeight: frame.height,
          maxHeight: frame.height,
          child: playable
              ? ClipPlayerView(
                  clip: clip,
                  slot: ClipThumbnailSlot.todayFrame,
                  orientation: orientation,
                  neighbours: neighbours,
                  loop: false,
                  overlayBuilder:
                      (
                        BuildContext context,
                        ClipPlayback playback,
                        ClipPlayerControls controls,
                      ) => _PlaybackOverlay(
                        inset: inset,
                        playback: playback,
                        controls: controls,
                        opacity: overlayOpacity,
                        landing: landing,
                        onOpen: onOpen,
                      ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    ClipThumbnailView(
                      clip: clip,
                      slot: ClipThumbnailSlot.todayFrame,
                      orientation: orientation,
                    ),
                    _Overlays(
                      inset: inset,
                      playing: false,
                      opacity: overlayOpacity,
                      onTap: onTap,
                    ),
                  ],
                ),
        );
      },
    ),
  );
}

/// The overlays of the page in view, driving its player.
///
/// - A tap before the player is ready plays it as soon as it is.
/// - Played to the end, it goes back to its first frame: the poster.
/// - Back in view after it was left mid-way (swiped away), it starts over.
///
/// The player is only driven after the frame: its state changes rebuild
/// the overlays.
class _PlaybackOverlay extends StatefulWidget {
  const _PlaybackOverlay({
    required this.inset,
    required this.playback,
    required this.controls,
    required this.opacity,
    required this.landing,
    required this.onOpen,
  });

  final double inset;
  final ClipPlayback playback;
  final ClipPlayerControls controls;
  final Animation<double>? opacity;
  final bool landing;
  final VoidCallback? onOpen;

  @override
  State<_PlaybackOverlay> createState() => _PlaybackOverlayState();
}

class _PlaybackOverlayState extends State<_PlaybackOverlay> {
  /// Tapped while the player was still loading.
  bool _wantsPlay = false;

  /// Whether this page has seen its player ready since it came into view.
  bool _attached = false;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(_PlaybackOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _attach();
    final ClipPlaybackPhase phase = widget.playback.phase;
    if (phase == oldWidget.playback.phase) return;
    if (phase == ClipPlaybackPhase.completed) {
      _afterFrame(() => widget.controls.seekTo(Duration.zero));
    } else if (_wantsPlay && phase == ClipPlaybackPhase.paused) {
      _wantsPlay = false;
      _afterFrame(widget.controls.play);
    } else if (phase == ClipPlaybackPhase.failed) {
      _wantsPlay = false;
    }
  }

  /// A player left mid-way (the page was swiped away) starts over.
  void _attach() {
    final ClipPlayback playback = widget.playback;
    if (_attached || playback.phase == ClipPlaybackPhase.loading) return;
    _attached = true;
    if (!playback.isPlaying && playback.position > Duration.zero) {
      _afterFrame(() => widget.controls.seekTo(Duration.zero));
    }
  }

  void _afterFrame(Future<void> Function() drive) =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(drive());
      });

  void _toggle() {
    if (widget.playback.phase == ClipPlaybackPhase.loading) {
      setState(() => _wantsPlay = !_wantsPlay);
    } else {
      unawaited(widget.controls.toggle());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ClipPlayback playback = widget.playback;
    if (playback.phase == ClipPlaybackPhase.failed) {
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.inset),
            child: PlayerErrorBlock(title: Strings.playerErrorTitle),
          ),
          _Overlays(
            inset: widget.inset,
            playing: false,
            showsPlay: false,
            opacity: widget.opacity,
            landing: widget.landing,
          ),
        ],
      );
    }
    return _Overlays(
      inset: widget.inset,
      playing: playback.isPlaying || _wantsPlay,
      opacity: widget.opacity,
      landing: widget.landing,
      onTap: _toggle,
      onLongPress: widget.onOpen,
      semanticsLabel: playback.isPlaying
          ? Strings.playerPause
          : Strings.todayPlayA11y,
    );
  }
}

/// The Saved badge and the play button over a page, [inset] into the
/// frame the page crops; both fade out while [playing].
class _Overlays extends StatelessWidget {
  const _Overlays({
    required this.inset,
    required this.playing,
    this.opacity,
    this.landing = false,
    this.showsPlay = true,
    this.onTap,
    this.onLongPress,
    this.semanticsLabel,
  });

  final double inset;
  final bool playing;
  final Animation<double>? opacity;
  final bool landing;
  final bool showsPlay;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final Animation<double>? opacity = this.opacity;
    final Widget stack = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PositionedDirectional(
          start: inset + OsdSpace.s10,
          top: OsdSpace.s10,
          child: AnimatedOpacity(
            opacity: playing ? 0 : 1,
            duration: OsdMotion.d(
              context,
              playing ? OsdMotion.fast : TodayMotion.overlaysBack,
            ),
            curve: OsdMotion.fastCurve,
            child: _Badge(landing: landing),
          ),
        ),
        if (showsPlay) Center(child: PlayOverlayButton(visible: !playing)),
      ],
    );
    final Widget overlays = opacity == null
        ? stack
        : FadeTransition(opacity: opacity, child: stack);
    final String? label = semanticsLabel;
    // One node for the whole page: "Play today's video", with the long
    // press; the badge and the button are part of it.
    return Semantics(
      container: label != null,
      excludeSemantics: true,
      button: label != null,
      label: label,
      onTap: label == null ? null : onTap,
      onLongPress: label == null ? null : onLongPress,
      child: GestureDetector(
        key: TodayClipPage.targetKey,
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        onLongPress: onLongPress,
        child: overlays,
      ),
    );
  }
}

/// The Saved badge. A clip that just arrived lands it: shortly after the
/// clip, it fades in and scales up while its check fills, with a light
/// haptic as it lands. Under reduced motion it is simply there, with the
/// haptic. Either way it fades out after [TodayMotion.badgeShown].
class _Badge extends StatefulWidget {
  const _Badge({required this.landing});

  final bool landing;

  @override
  State<_Badge> createState() => _BadgeState();
}

class _BadgeState extends State<_Badge> {
  /// Before the badge lands: nothing yet.
  late bool _waiting = widget.landing;

  /// While it lands.
  bool _landing = false;

  /// Once it has been shown long enough.
  bool _gone = false;

  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.landing) {
      _goAfterShown();
      return;
    }
    if (OsdMotion.reduced(context)) {
      _waiting = false;
      unawaited(OsdHaptic.light.play());
      _goAfterShown();
      return;
    }
    _timer = Timer(TodayMotion.badgeDelay, () {
      setState(() {
        _waiting = false;
        _landing = true;
      });
      _timer = Timer(TodayMotion.badgeLanding, () {
        unawaited(OsdHaptic.light.play());
        setState(() => _landing = false);
        _goAfterShown();
      });
    });
  }

  void _goAfterShown() {
    _timer = Timer(TodayMotion.badgeShown, () {
      if (mounted) setState(() => _gone = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_waiting) return const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: _gone ? 0 : 1,
      duration: OsdMotion.d(context, TodayMotion.badgeFade),
      curve: OsdMotion.curve(context, OsdMotion.standardCurve),
      child: TweenAnimationBuilder<double>(
        // From 0 only for a badge that lands; one shown at once stays at 1.
        tween: Tween<double>(begin: _landing ? 0 : 1, end: 1),
        duration: TodayMotion.badgeLanding,
        curve: OsdMotion.fastCurve,
        builder: (BuildContext context, double shown, Widget? child) =>
            Opacity(opacity: shown, child: child),
        child: SavedBadge(label: Strings.todaySavedBadge, animateIn: _landing),
      ),
    );
  }
}
