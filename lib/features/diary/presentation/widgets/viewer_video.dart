import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/player_state.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_hero.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_playback.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_player_view.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/viewer_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/viewer_state.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/clip_autoplay.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/viewer_swipe.dart';
import 'package:one_second_diary/shared/widgets/buttons/play_overlay_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/viewer_nav_button.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_loading_delay.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_spinner.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';
import 'package:one_second_diary/shared/widgets/surfaces/player_error_block.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The viewer's video: the clip shown, full width at 16:9 (9:16 for a
/// portrait profile, contained on black), playing through the viewer's
/// `PlayerPool`.
///
/// - It plays on its own once, with the viewer's sound; a tap plays or
///   pauses; paused or ended, the play (or `replay`) circle shows; loading
///   past a short delay, a spinner; a clip that can't be played, the error
///   block.
/// - Previous and next (the chevrons centred on the video, hidden at the
///   ends, while the clip loads and, like the play circle, while it
///   plays; or a swipe sideways anywhere on the viewer, `ViewerSwipe`)
///   step through a day's clips, then the recorded days; the video slides
///   that way, the old one following a little behind, a crossfade under
///   reduced motion.
/// - The video is the end of the flight from the Diary ([ClipHero]).
class ViewerVideo extends StatelessWidget {
  const ViewerVideo({
    super.key,
    this.chrome = kAlwaysCompleteAnimation,
    this.playback,
  });

  /// The video surface: a tap plays or pauses.
  static const Key surfaceKey = Key('viewerVideo.surface');

  static const Key previousKey = Key('viewerVideo.previous');

  static const Key nextKey = Key('viewerVideo.next');

  /// How much the chevrons show (they fade with the viewer's chrome).
  final Animation<double> chrome;

  /// The player of the clip shown: the chevrons hide while it plays. They
  /// always show without it.
  final ValueListenable<PlayerState?>? playback;

  static const double _landscape = 16 / 9;
  static const double _portrait = 9 / 16;

  void _step(BuildContext context, {required bool next}) {
    final ViewerCubit cubit = context.read<ViewerCubit>();
    unawaited(OsdHaptic.selection.play());
    next ? cubit.showNext() : cubit.showPrevious();
  }

  @override
  Widget build(BuildContext context) {
    final (
      ClipRef clip,
      bool hasPrevious,
      bool hasNext,
      VideoOrientation orientation,
      ViewerStep step,
    ) = context.select(
      (ViewerCubit cubit) => (
        cubit.state.clip,
        cubit.state.previous != null,
        cubit.state.next != null,
        cubit.state.profile.orientation,
        cubit.state.step,
      ),
    );
    return AspectRatio(
      aspectRatio: orientation == VideoOrientation.portrait
          ? _portrait
          : _landscape,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ClipRect(
            child: _StepSwitcher(
              step: step,
              child: _ViewerClip(key: ValueKey<ClipRef>(clip), clip: clip),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 10),
              child: FadeTransition(
                opacity: chrome,
                child: _WhilePaused(
                  playback: playback,
                  builder: (bool paused) => ViewerNavButton(
                    key: previousKey,
                    icon: OsdIcons.chevronLeft,
                    tooltip: Strings.viewerPreviousDay,
                    visible: hasPrevious && paused,
                    onPressed: () => _step(context, next: false),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: FadeTransition(
                opacity: chrome,
                child: _WhilePaused(
                  playback: playback,
                  builder: (bool paused) => ViewerNavButton(
                    key: nextKey,
                    icon: OsdIcons.chevronRight,
                    tooltip: Strings.viewerNextDay,
                    visible: hasNext && paused,
                    onPressed: () => _step(context, next: true),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Builds a chevron with whether the clip shown rests (paused or ended),
/// rebuilding only the chevron as that changes.
///
/// A clip that is still loading does not count: the viewer opens on a clip
/// about to play, and the chevrons would show for a moment and go. Once a
/// clip has played, a pause or its end shows them at once. One that is
/// ready but has not played yet (or can't play) shows them after [_hold],
/// so stepping on is never out of reach.
class _WhilePaused extends StatefulWidget {
  const _WhilePaused({required this.playback, required this.builder});

  /// How long a ready clip that has not played yet rests before the
  /// chevrons show: the gap between a player being ready and its first
  /// frame playing is far shorter.
  static const Duration _hold = Duration(milliseconds: 400);

  final ValueListenable<PlayerState?>? playback;
  final Widget Function(bool paused) builder;

  @override
  State<_WhilePaused> createState() => _WhilePausedState();
}

class _WhilePausedState extends State<_WhilePaused> {
  bool _paused = false;

  /// Whether the clip shown has played since it was loaded.
  bool _played = false;
  Timer? _settle;

  @override
  void initState() {
    super.initState();
    widget.playback?.addListener(_follow);
    _paused = widget.playback == null;
    _follow();
  }

  @override
  void didUpdateWidget(_WhilePaused oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.playback, widget.playback)) return;
    oldWidget.playback?.removeListener(_follow);
    widget.playback?.addListener(_follow);
    _follow();
  }

  @override
  void dispose() {
    widget.playback?.removeListener(_follow);
    _settle?.cancel();
    super.dispose();
  }

  void _follow() {
    final ValueListenable<PlayerState?>? playback = widget.playback;
    if (playback == null) return _show(true);
    final PlayerState? state = playback.value;
    final bool failed = state?.error != null;
    final bool ready = state != null && state.initialized;
    if (state != null && state.playing) {
      _played = true;
      return _show(false);
    }
    if (!ready && !failed) {
      // Loading, or another clip's player taking over.
      _played = false;
      return _show(false);
    }
    if (_played || failed) return _show(true);
    // Ready, never played: it is about to, or it stays put.
    _settle ??= Timer(_WhilePaused._hold, () {
      _settle = null;
      if (mounted) _show(true);
    });
  }

  void _show(bool paused) {
    if (!paused || _settle != null) {
      _settle?.cancel();
      _settle = null;
    }
    if (paused == _paused || !mounted) return;
    setState(() => _paused = paused);
  }

  @override
  Widget build(BuildContext context) => widget.builder(_paused);
}

/// Slides the new clip in the way the viewer moved, the old one leaving a
/// little behind and fading; a crossfade under reduced motion. Both keep
/// the same widgets around the clip, so a clip is never built again from
/// scratch mid-slide. It takes `ViewerSwipe.stepDuration`, so a swipe's
/// lean settles as the clip slides.
class _StepSwitcher extends StatelessWidget {
  const _StepSwitcher({required this.step, required this.child});

  /// How far the old clip moves while the new one crosses the frame.
  static const double _parallax = .2;

  final ViewerStep step;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool reduced = OsdMotion.reduced(context);
    final Key? current = child.key;
    final double side = step == ViewerStep.backward ? -1 : 1;
    return AnimatedSwitcher(
      duration: OsdMotion.d(context, ViewerSwipe.stepDuration),
      switchInCurve: OsdMotion.curve(context, OsdMotion.standardCurve),
      switchOutCurve: OsdMotion.curve(context, OsdMotion.standardCurve),
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        fit: StackFit.expand,
        children: <Widget>[...previous, ?current],
      ),
      transitionBuilder: (Widget clip, Animation<double> animation) {
        final bool leaving = clip.key != current;
        final Offset away = reduced || step == ViewerStep.none
            ? Offset.zero
            : leaving
            ? Offset(-side * _parallax, 0)
            : Offset(side, 0);
        return FadeTransition(
          opacity: leaving || reduced ? animation : kAlwaysCompleteAnimation,
          child: SlideTransition(
            textDirection: Directionality.of(context),
            position: Tween<Offset>(
              begin: away,
              end: Offset.zero,
            ).animate(animation),
            child: clip,
          ),
        );
      },
      child: child,
    );
  }
}

/// One clip of the viewer, playing, with its controls.
class _ViewerClip extends StatelessWidget {
  const _ViewerClip({super.key, required this.clip});

  final ClipRef clip;

  @override
  Widget build(BuildContext context) {
    final (
      bool muted,
      bool covered,
      VideoOrientation orientation,
      ClipRef? previous,
      ClipRef? next,
    ) = context.select(
      (ViewerCubit cubit) => (
        cubit.state.muted,
        cubit.state.isCovered(clip),
        cubit.state.profile.orientation,
        // This clip's own neighbours: a clip sliding out keeps its own, so
        // it never asks the pool for itself again.
        cubit.state.index?.previousClip(clip),
        cubit.state.index?.nextClip(clip),
      ),
    );
    return ColoredBox(
      color: OsdMedia.letterbox,
      child: ClipHero(
        clip: clip,
        radius: 0,
        slot: ClipThumbnailSlot.viewer,
        orientation: orientation,
        child: ClipPlayerView(
          clip: clip,
          slot: ClipThumbnailSlot.viewer,
          orientation: orientation,
          neighbours: <ClipRef>[?previous, ?next],
          autoPlay: true,
          loop: false,
          muted: muted,
          // Opening the viewer on a private clip is choosing to watch it;
          // one reached by stepping stays covered until tapped.
          revealPrivate: !covered,
          onRevealed: () => context.read<ViewerCubit>().reveal(clip),
          onCovered: () => context.read<ViewerCubit>().cover(clip),
          overlayBuilder:
              (
                BuildContext context,
                ClipPlayback playback,
                ClipPlayerControls controls,
              ) => _ViewerControls(
                clip: clip,
                playback: playback,
                controls: controls,
              ),
        ),
      ),
    );
  }
}

/// Over the video: the tap to play or pause, the play circle, the loading
/// spinner, or the error block.
class _ViewerControls extends StatelessWidget {
  const _ViewerControls({
    required this.clip,
    required this.playback,
    required this.controls,
  });

  /// The spinner's size.
  static const double _spinner = 28;

  final ClipRef clip;
  final ClipPlayback playback;
  final ClipPlayerControls controls;

  @override
  Widget build(BuildContext context) {
    if (playback.phase == ClipPlaybackPhase.failed) {
      return PlayerErrorBlock(
        title: Strings.playerErrorTitle,
        body: Strings.playerErrorBody,
      );
    }
    final bool paused = switch (playback.phase) {
      ClipPlaybackPhase.paused || ClipPlaybackPhase.completed => true,
      _ => false,
    };
    return ClipAutoplay(
      enabled: true,
      playback: playback,
      controls: controls,
      child: Semantics(
        button: true,
        label: DiaryFormats.of(context).fullDate(clip.day),
        onTapHint: playback.isPlaying ? Strings.playerPause : Strings.play,
        onTap: () => unawaited(controls.toggle()),
        excludeSemantics: true,
        child: GestureDetector(
          key: ViewerVideo.surfaceKey,
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(controls.toggle()),
          child: Center(
            child: OsdLoadingDelay(
              loading: playback.phase == ClipPlaybackPhase.loading,
              builder: (BuildContext context, bool showLoading) => showLoading
                  ? const OsdSpinner(size: _spinner, color: OsdMedia.onMedia)
                  : PlayOverlayButton(
                      visible: paused,
                      ended: playback.phase == ClipPlaybackPhase.completed,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
