import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/player_handle.dart';
import 'package:one_second_diary/core/platform/player_state.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/data/shown_player.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_playback.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_privacy_watch.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_thumbnail_view.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// Draws the controls over a [ClipPlayerView] (a play button, the sound
/// toggle, the progress bar) for the clip's [playback]; [controls] play and
/// pause it.
typedef ClipPlayerOverlayBuilder =
    Widget Function(
      BuildContext context,
      ClipPlayback playback,
      ClipPlayerControls controls,
    );

/// A clip playing in its frame, with a player from the screen's `PlayerPool`.
///
/// - the clip's poster ([ClipThumbnailView], the poster tier) shows in the
///   first frame;
/// - the pool opens the clip's player, and the [neighbours] are kept warm, so
///   stepping plays at once;
/// - once its player is ready the video fades in over the poster; another clip
///   never shows the old clip's video;
/// - [autoPlay] plays it once ready; [loop] false plays it once ([onCompleted]
///   then runs, and play starts over); [muted] is the sound toggle: changing
///   it rebuilds the pool's players in that mode (a muted player never takes
///   the user's music), and the clip stays as it was, playing or paused;
/// - a hidden tab or a covered screen (`TickerMode` off) pauses it, and plays
///   it on when it shows again if it was playing; meanwhile only its own
///   player stays in the pool (the neighbours' decoders are released, as
///   phones have few hardware decoders). Going away pauses it. The pool owns
///   the players and releases them when the screen disposes it;
/// - a private clip starts covered: its blurred poster under "Tap to view", no
///   video, no controls, and it never plays on its own. A tap uncovers it and
///   plays it. It starts uncovered with [revealPrivate]; [onRevealed] hears
///   the tap. A clip marked private while it shows is covered at once and
///   paused, whatever [revealPrivate] says; [onCovered] hears it.
///
/// The screen provides the pool, one per screen that plays clips: a
/// `RepositoryProvider` of `sl<PlayerPool>(param1: muted)` that disposes it.
class ClipPlayerView extends StatefulWidget {
  const ClipPlayerView({
    super.key,
    required this.clip,
    this.slot = ClipThumbnailSlot.player,
    this.orientation = VideoOrientation.landscape,
    this.radius = 0,
    this.neighbours = const <ClipRef>[],
    this.autoPlay = false,
    this.loop = true,
    this.muted,
    this.revealPrivate = false,
    this.onRevealed,
    this.onCovered,
    this.overlayBuilder,
    this.onCompleted,
    this.semanticsLabel,
  });

  /// The video layer (it fades in once the player is ready).
  static const Key videoKey = Key('clipPlayerView.video');

  /// The cover of a private clip, which a tap removes.
  static const Key privateCoverKey = Key('clipPlayerView.privateCover');

  final ClipRef clip;

  /// Where it sits: how poster and video fill the frame.
  final ClipThumbnailSlot slot;

  /// The profile's orientation.
  final VideoOrientation orientation;

  final double radius;

  /// The clips to keep warm, at most two (the previous and the next).
  final List<ClipRef> neighbours;

  /// Plays as soon as its player is ready.
  final bool autoPlay;

  /// Plays in a loop; false plays once.
  final bool loop;

  /// Whether it plays without sound; null leaves the pool's mode.
  final bool? muted;

  /// Whether a private clip shows uncovered from the start.
  final bool revealPrivate;

  /// The private clip shown was uncovered by a tap.
  final VoidCallback? onRevealed;

  /// The clip shown was marked private: it is covered again, so whoever
  /// passes [revealPrivate] should drop it.
  final VoidCallback? onCovered;

  /// The controls drawn over the frame.
  final ClipPlayerOverlayBuilder? overlayBuilder;

  /// It played to the end (only without [loop]).
  final VoidCallback? onCompleted;

  /// See `ClipThumbnail.semanticsLabel`.
  final String? semanticsLabel;

  @override
  State<ClipPlayerView> createState() => _ClipPlayerViewState();
}

class _ClipPlayerViewState extends State<ClipPlayerView>
    implements ClipPlayerControls {
  late final PlayerPool _pool = context.read<PlayerPool>();
  late final AppPaths _paths = context.read<AppPaths>();
  late final ClipPrivacyWatch _privacy = ClipPrivacyWatch(
    clips: context.read<ClipRepository>(),
    onChanged: _onPrivacyChanged,
  );

  /// The private clip the user uncovered here.
  ClipRef? _revealed;

  /// The clip was marked private while it showed: covered until tapped,
  /// even with [ClipPlayerView.revealPrivate].
  bool _hidden = false;

  /// Whether the clip is private and still under its cover.
  bool get _covered =>
      _privacy.isPrivate &&
      _revealed != widget.clip &&
      (_hidden || !widget.revealPrivate);

  /// Stands in for the player until the clip's own is ready.
  static final ValueListenable<PlayerState> _noPlayer =
      ValueNotifier<PlayerState>(const PlayerState.uninitialized());

  /// The clip's player once the pool shows it.
  PlayerHandle? _handle;

  /// The file [_handle] plays.
  String? _handlePath;

  /// Paused because the tab was hidden, not by the user, or ready to play
  /// on its own while hidden: it plays when the tab shows.
  bool _pausedByTab = false;

  /// Whether the player is ready and playable (the video shows).
  bool _visible = false;
  bool _tickerEnabled = true;
  bool _completed = false;

  String get _path => _paths.absoluteFromVideos(widget.clip.relPath);

  @override
  void initState() {
    super.initState();
    _privacy.watch(widget.clip);
    _pool.shown.addListener(_onShown);
    final bool? muted = widget.muted;
    if (muted != null) unawaited(_pool.setMuted(muted));
    _select();
    _onShown();
  }

  @override
  void didUpdateWidget(ClipPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool? muted = widget.muted;
    if (muted != null && muted != oldWidget.muted) {
      unawaited(_pool.setMuted(muted));
    }
    if (widget.clip != oldWidget.clip) {
      _revealed = null;
      _hidden = false;
      _privacy.watch(widget.clip);
    }
    if (widget.clip != oldWidget.clip ||
        !listEquals(widget.neighbours, oldWidget.neighbours)) {
      _select();
      _onShown();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool enabled = TickerMode.valuesOf(context).enabled;
    if (enabled == _tickerEnabled) return;
    _tickerEnabled = enabled;
    // Hidden, the screen keeps only this clip's player: its neighbours'
    // decoders go, and warm up again when it shows.
    _select();
    final PlayerHandle? handle = _handle;
    if (handle == null) return;
    if (!enabled && handle.value.value.playing) {
      _pausedByTab = true;
      unawaited(handle.pause());
    } else if (enabled && _pausedByTab) {
      _pausedByTab = false;
      unawaited(handle.play());
    }
  }

  @override
  void dispose() {
    _privacy.dispose();
    _pool.shown.removeListener(_onShown);
    final PlayerHandle? handle = _handle;
    _detach();
    if (handle != null && handle.value.value.playing) {
      unawaited(handle.pause());
    }
    super.dispose();
  }

  void _select() => unawaited(
    _pool.select(
      _path,
      neighbours: <String>[
        if (_tickerEnabled)
          for (final ClipRef neighbour in widget.neighbours)
            _paths.absoluteFromVideos(neighbour.relPath),
      ],
    ),
  );

  /// Takes the pool's player when it shows this clip, and lets it go when
  /// it shows another.
  void _onShown() {
    final ShownPlayer? shown = _pool.shown.value;
    final PlayerHandle? handle = shown?.path == _path ? shown?.handle : null;
    if (identical(handle, _handle)) return;
    // The pool rebuilt this clip's player (the sound toggle) and carried
    // its position and play state over: it must not start playing again.
    final bool rebuilt =
        handle != null && _handle != null && _handlePath == _path;
    _detach();
    _handle = handle;
    if (handle != null) {
      _handlePath = _path;
      handle.value.addListener(_onPlayer);
      _completed = handle.value.value.completed;
      _visible = _playable(handle.value.value);
      unawaited(handle.setLooping(widget.loop));
      if (widget.autoPlay && !rebuilt && !_covered) {
        // Ready while hidden (a covered screen whose player went to the
        // viewer opens it again): it plays once it shows.
        if (_tickerEnabled) {
          unawaited(handle.play());
        } else {
          _pausedByTab = true;
        }
      }
    }
    if (mounted) setState(() {});
  }

  void _detach() {
    _handle?.value.removeListener(_onPlayer);
    _handle = null;
    _handlePath = null;
    _pausedByTab = false;
    _visible = false;
  }

  static bool _playable(PlayerState state) =>
      state.initialized && state.error == null;

  /// The clip shown was marked private (covered and paused at once) or
  /// public (nothing covers it any more).
  void _onPrivacyChanged() {
    if (!mounted) return;
    final bool private = _privacy.isPrivate;
    setState(() {
      _revealed = null;
      _hidden = private;
    });
    if (!private) return;
    unawaited(pause());
    widget.onCovered?.call();
  }

  /// The tap on the cover: the clip shows, and plays.
  void _reveal() {
    setState(() {
      _revealed = widget.clip;
      _hidden = false;
    });
    widget.onRevealed?.call();
    unawaited(play());
  }

  void _onPlayer() {
    final PlayerState state = _handle!.value.value;
    if (state.completed && !_completed) widget.onCompleted?.call();
    _completed = state.completed;
    final bool visible = _playable(state);
    if (visible != _visible) setState(() => _visible = visible);
  }

  @override
  Future<void> play() async {
    final PlayerHandle? handle = _handle;
    if (handle == null) return;
    _pausedByTab = false;
    if (handle.value.value.completed) await handle.seekTo(Duration.zero);
    await handle.play();
  }

  @override
  Future<void> pause() async {
    _pausedByTab = false;
    await _handle?.pause();
  }

  @override
  Future<void> toggle() =>
      (_handle?.value.value.playing ?? false) ? pause() : play();

  @override
  Future<void> seekTo(Duration position) async => _handle?.seekTo(position);

  @override
  Widget build(BuildContext context) {
    final PlayerHandle? handle = _handle;
    final ValueListenable<PlayerState> state = handle?.value ?? _noPlayer;
    final ClipPlayerOverlayBuilder? overlay = widget.overlayBuilder;
    final bool covered = _covered;
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ClipThumbnailView(
              clip: widget.clip,
              slot: widget.slot,
              orientation: widget.orientation,
              obscurePrivate: covered,
              semanticsLabel: widget.semanticsLabel,
            ),
            _Video(
              key: ClipPlayerView.videoKey,
              handle: handle,
              visible: _visible && !covered,
              fit: widget.slot.fitFor(widget.orientation) == ClipFit.cover
                  ? BoxFit.cover
                  : BoxFit.contain,
            ),
            if (covered)
              _PrivateCover(onReveal: _reveal)
            else if (overlay != null)
              ValueListenableBuilder<PlayerState>(
                valueListenable: state,
                builder: (BuildContext context, PlayerState value, _) =>
                    overlay(
                      context,
                      handle == null
                          ? const ClipPlayback.loading()
                          : ClipPlayback.of(value),
                      this,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

/// What covers a private clip until it is tapped: "Tap to view" under the
/// blurred poster's lock, the whole frame the button.
class _PrivateCover extends StatelessWidget {
  const _PrivateCover({required this.onReveal});

  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${Strings.privateVideo}. ${Strings.privateTapToView}',
    onTap: onReveal,
    child: GestureDetector(
      key: ClipPlayerView.privateCoverKey,
      behavior: HitTestBehavior.opaque,
      onTap: onReveal,
      child: ExcludeSemantics(
        child: Align(
          alignment: const Alignment(0, .5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: OsdMedia.scrim55,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                Strings.privateTapToView,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.caption13.copyWith(
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

/// The video, faded in once its player is ready and playable.
class _Video extends StatelessWidget {
  const _Video({
    super.key,
    required this.handle,
    required this.visible,
    required this.fit,
  });

  final PlayerHandle? handle;
  final bool visible;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final PlayerHandle? handle = this.handle;
    return AnimatedOpacity(
      opacity: handle != null && visible ? 1 : 0,
      duration: OsdMotion.d(context, OsdMotion.fast),
      curve: OsdMotion.fastCurve,
      child: handle == null
          ? const SizedBox.shrink()
          : RepaintBoundary(
              child: ClipRect(
                child: FittedBox(
                  fit: fit,
                  child: SizedBox(
                    width: 100 * handle.value.value.aspectRatio,
                    height: 100,
                    child: handle.buildView(),
                  ),
                ),
              ),
            ),
    );
  }
}
