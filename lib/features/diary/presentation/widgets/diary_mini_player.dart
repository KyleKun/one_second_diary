import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_hero.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_playback.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_player_view.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';
import 'package:one_second_diary/features/diary/presentation/diary_viewer_flow.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/clip_autoplay.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/neighbour_posters.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/viewer_swipe.dart';
import 'package:one_second_diary/shared/widgets/buttons/play_overlay_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/video_overlay_icon_button.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';
import 'package:one_second_diary/shared/widgets/progress/page_dots.dart';
import 'package:one_second_diary/shared/widgets/surfaces/player_error_block.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';

/// The calendar's mini player: the clips of [day] in a frame under the
/// grid, played through the shared `ClipPlayerView` and the Diary's
/// `PlayerPool`.
///
/// - The poster shows in the same frame as the tap, from the thumbnail
///   cache; the video fades in over it once its player is ready, and the
///   clips before and after it are kept warm, their players opened and
///   their posters decoded ([NeighbourPosters]).
/// - It plays on its own (`calendarAutoPlay`, the user's last play or
///   pause), muted and mixing with the user's music until the sound toggle
///   turns the sound on. A tap anywhere on the video plays or pauses it;
///   the play button is only a visual.
/// - The clip shown plays in a loop, as in older versions.
/// - A swipe sideways on the video steps as the viewer does ([ViewerSwipe]):
///   through the day's clips (dots at bottom-end), then to the neighbouring
///   recorded days, the calendar following.
/// - A clip that can't be played shows the player error block in place,
///   without expand and sound (never a restart).
/// - Expand (top-start) opens the viewer, the video flying there
///   ([ClipHero]); the clip the viewer shows last comes back selected. The
///   sound toggle sits top-end.
///
/// [day] is the day this frame belongs to, not the selected one: while the
/// panel crossfades to another day, the old frame keeps its clip.
class DiaryMiniPlayer extends StatelessWidget {
  const DiaryMiniPlayer({
    super.key,
    required this.day,
    this.mediaHeight = height,
  });

  /// The video surface: a tap plays or pauses.
  static const Key surfaceKey = Key('diaryMiniPlayer.surface');

  /// Expand to the viewer.
  static const Key expandKey = Key('diaryMiniPlayer.expand');

  static const Key soundKey = Key('diaryMiniPlayer.sound');

  /// The frame's height.
  static const double height = 196;

  final LocalDay day;

  /// How tall this frame is: [height], or 16:9 of a tablet's pane.
  final double mediaHeight;

  /// Shows [clip], on its day, with the chevrons' tick.
  static void _step(BuildContext context, ClipRef clip) {
    unawaited(OsdHaptic.selection.play());
    context.read<DiaryCubit>().showDay(clip.day, clip: clip);
  }

  @override
  Widget build(BuildContext context) {
    final (List<ClipRef> clips, int position) = context.select(
      (DiaryCubit cubit) => (
        cubit.state.clipsOf(day),
        cubit.state.selected == day ? cubit.state.shownPosition : 0,
      ),
    );
    if (clips.isEmpty) return SizedBox(height: mediaHeight);
    final ClipRef clip = clips[position.clamp(0, clips.length - 1)];
    final PlayerNeighbours neighbours = context.select(
      (DiaryCubit cubit) => cubit.state.neighboursOf(clip),
    );
    final ClipRef? previous = neighbours.previous;
    final ClipRef? next = neighbours.next;
    return SizedBox(
      height: mediaHeight,
      child: ViewerSwipe(
        onPrevious: previous == null ? null : () => _step(context, previous),
        onNext: next == null ? null : () => _step(context, next),
        builder: (BuildContext context, Animation<double> shift) =>
            AnimatedBuilder(
              animation: shift,
              builder: (BuildContext context, Widget? child) =>
                  Transform.translate(
                    offset: Offset(shift.value, 0),
                    child: child,
                  ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(OsdRadius.r4),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _PlayerPage(day: day, clip: clip),
                    if (clips.length > 1)
                      PositionedDirectional(
                        end: 12,
                        bottom: 14,
                        child: IgnorePointer(
                          child: PageDots(
                            count: clips.length,
                            position: position.toDouble(),
                            style: PageDotsStyle.onMedia,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}

/// The clip shown, playing, with its controls.
class _PlayerPage extends StatelessWidget {
  const _PlayerPage({required this.day, required this.clip});

  final LocalDay day;
  final ClipRef clip;

  @override
  Widget build(BuildContext context) {
    final (
      bool selected,
      bool autoPlay,
      bool muted,
      VideoOrientation orientation,
      bool flies,
      bool underViewer,
      bool covered,
    ) = context.select(
      (DiaryCubit cubit) => (
        cubit.state.selected == day,
        cubit.state.autoPlay,
        cubit.state.muted,
        cubit.state.profile.orientation,
        cubit.state.viewerOrigin == ViewerOrigin.player,
        cubit.state.viewerOpen,
        cubit.state.isCovered(clip),
      ),
    );
    // This clip's own neighbours: a day fading out keeps its own, so it
    // never asks the pool for its clip again.
    final PlayerNeighbours neighbours = context.select(
      (DiaryCubit cubit) => cubit.state.neighboursOf(clip),
    );
    final List<ClipRef> warm = <ClipRef>[
      ?neighbours.previous,
      ?neighbours.next,
    ];
    return ClipHero(
      clip: clip,
      radius: OsdRadius.r4,
      slot: ClipThumbnailSlot.player,
      orientation: orientation,
      enabled: flies,
      // Under the viewer (it shows the Diary while dragged away) the player
      // holds still, and plays on once the viewer closes.
      child: TickerMode(
        enabled: !underViewer,
        child: NeighbourPosters(
          clips: warm,
          child: ClipPlayerView(
            clip: clip,
            orientation: orientation,
            neighbours: warm,
            autoPlay: selected && autoPlay,
            muted: muted,
            revealPrivate: !covered,
            onRevealed: () => context.read<DiaryCubit>().revealClip(clip),
            onCovered: () => context.read<DiaryCubit>().coverClip(clip),
            overlayBuilder:
                (
                  BuildContext context,
                  ClipPlayback playback,
                  ClipPlayerControls controls,
                ) => _PlayerControls(
                  clip: clip,
                  day: day,
                  playback: playback,
                  controls: controls,
                  muted: muted,
                  autoPlay: selected && autoPlay,
                ),
          ),
        ),
      ),
    );
  }
}

/// What sits over the video: the play button, expand, the sound toggle;
/// the error block when the clip can't be played.
class _PlayerControls extends StatelessWidget {
  const _PlayerControls({
    required this.clip,
    required this.day,
    required this.playback,
    required this.controls,
    required this.muted,
    required this.autoPlay,
  });

  final ClipRef clip;
  final LocalDay day;
  final ClipPlayback playback;
  final ClipPlayerControls controls;
  final bool muted;

  /// The clip plays on its own (once it can be seen: [ClipAutoplay]).
  final bool autoPlay;

  Future<void> _toggle(DiaryCubit cubit) async {
    final bool play = !playback.isPlaying;
    await Future.wait(<Future<void>>[
      controls.toggle(),
      cubit.playbackChosen(playing: play),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (playback.phase == ClipPlaybackPhase.failed) {
      return PlayerErrorBlock(
        title: Strings.playerErrorTitle,
        body: Strings.playerErrorBody,
      );
    }
    final DiaryCubit cubit = context.read<DiaryCubit>();
    final bool paused = switch (playback.phase) {
      ClipPlaybackPhase.paused || ClipPlaybackPhase.completed => true,
      _ => false,
    };
    return ClipAutoplay(
      enabled: autoPlay,
      playback: playback,
      controls: controls,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Semantics(
            button: true,
            label: DiaryFormats.of(context).fullDate(day),
            onTapHint: playback.isPlaying ? Strings.playerPause : Strings.play,
            onTap: () => unawaited(_toggle(cubit)),
            excludeSemantics: true,
            child: GestureDetector(
              key: DiaryMiniPlayer.surfaceKey,
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(_toggle(cubit)),
              child: Center(child: PlayOverlayButton(visible: paused)),
            ),
          ),
          PositionedDirectional(
            top: 10,
            start: 10,
            child: VideoOverlayIconButton(
              key: DiaryMiniPlayer.expandKey,
              icon: OsdIcons.openInFull,
              tooltip: Strings.playerOpenFullScreen,
              onPressed: () =>
                  unawaited(DiaryViewerFlow.open(context, clip: clip)),
            ),
          ),
          PositionedDirectional(
            top: 10,
            end: 10,
            child: _SoundToggle(muted: muted, onPressed: cubit.toggleSound),
          ),
        ],
      ),
    );
  }
}

/// The sound toggle: `volume_off` while muted, `volume_up` with sound, the
/// incoming glyph scaling in.
class _SoundToggle extends StatelessWidget {
  const _SoundToggle({required this.muted, required this.onPressed});

  /// The glyph swap, between `OsdMotion.pressIn` and `fast`.
  static const Duration _swap = Duration(milliseconds: 120);
  static const double _fromScale = .8;

  final bool muted;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    key: DiaryMiniPlayer.soundKey,
    duration: OsdMotion.d(context, _swap),
    switchInCurve: OsdMotion.curve(context, OsdMotion.fastCurve),
    transitionBuilder: (Widget child, Animation<double> animation) =>
        OsdMotion.reduced(context)
        ? FadeTransition(opacity: animation, child: child)
        : ScaleTransition(
            scale: Tween<double>(begin: _fromScale, end: 1).animate(animation),
            child: child,
          ),
    child: VideoOverlayIconButton(
      key: ValueKey<bool>(muted),
      icon: muted ? OsdIcons.volumeOff : OsdIcons.volumeUp,
      fill: 1,
      tooltip: muted ? Strings.playerUnmute : Strings.playerMute,
      onPressed: () => unawaited(onPressed()),
    ),
  );
}
