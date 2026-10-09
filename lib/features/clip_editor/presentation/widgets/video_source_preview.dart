import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/platform/player_handle.dart';
import 'package:one_second_diary/core/platform/player_state.dart';
import 'package:one_second_diary/features/clip_editor/domain/trim_selection.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_state.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/frame_viewport.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/data/shown_player.dart';
import 'package:one_second_diary/shared/widgets/buttons/play_overlay_button.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_loading_delay.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_spinner.dart';
import 'package:one_second_diary/shared/widgets/surfaces/player_error_block.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The video source playing in the editor's preview, with a player from
/// the screen's `PlayerPool`.
///
/// - Once the player is ready it tells the editor the source's length and
///   shape (`EditClipCubit.sourceLoaded`), or that it cannot be played.
/// - It plays the part that will be saved, muted, in a loop; a tap pauses
///   it (the play button shows) and plays it again.
/// - While a finger is on the trim window it pauses on the window's start
///   and follows it; when the finger lifts it plays on from there.
/// - While the clip saves it rests (ffmpeg decodes the same file), a tap
///   does nothing, and it plays on after a cancel or a failure.
/// - A hidden page (`TickerMode` off) pauses it, and it plays on when the
///   page comes back if it was playing. The editor's pool releases the
///   player with the page.
///
/// The video sits in a `RepaintBoundary`; a position tick rebuilds nothing.
class VideoSourcePreview extends StatefulWidget {
  const VideoSourcePreview({
    super.key,
    required this.path,
    required this.canvasAspectRatio,
    this.frame,
  });

  /// The video layer (it fades in once the player is ready).
  static const Key videoKey = Key('videoSourcePreview.video');

  static const Key playKey = Key('videoSourcePreview.play');

  final String path;

  /// The canvas's width / height.
  final double canvasAspectRatio;

  /// How the video sits on the canvas when the clip is framed; null is the
  /// default (fitted into a landscape canvas, covering a portrait one).
  final ClipFrame? frame;

  @override
  State<VideoSourcePreview> createState() => _VideoSourcePreviewState();
}

class _VideoSourcePreviewState extends State<VideoSourcePreview> {
  late final PlayerPool _pool = context.read<PlayerPool>();
  late final EditClipCubit _editor = context.read<EditClipCubit>();

  PlayerHandle? _handle;

  /// The player is ready and playable: the video shows.
  bool _visible = false;
  bool _failed = false;
  bool _playing = false;

  /// The source's length went to the editor.
  bool _loaded = false;

  bool _tickerEnabled = true;

  /// Paused because the page was hidden, not by the user.
  bool _pausedByPage = false;

  /// Whether it played when a finger went down on the trim window.
  bool _playAfterTrim = false;

  /// Whether it played when the save started.
  bool _playAfterSave = false;

  /// Set from each position report while playing: fires at the end of the
  /// part that will be saved.
  Timer? _toTheEnd;

  /// A seek running, and the latest one wanted meanwhile: a drag asks for
  /// a seek per frame, and the player gets only the latest.
  bool _seeking = false;
  int? _nextSeekMs;

  @override
  void initState() {
    super.initState();
    _pool.shown.addListener(_onShown);
    unawaited(_pool.select(widget.path));
    _onShown();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool enabled = TickerMode.valuesOf(context).enabled;
    if (enabled == _tickerEnabled) return;
    _tickerEnabled = enabled;
    final PlayerHandle? handle = _handle;
    if (handle == null) return;
    if (!enabled && handle.value.value.playing) {
      _pausedByPage = true;
      unawaited(handle.pause());
    } else if (enabled && _pausedByPage) {
      _pausedByPage = false;
      unawaited(handle.play());
    }
  }

  @override
  void dispose() {
    // The player stays as it is: the editor's pool releases it with the
    // page, and a preview built again in its place takes it on playing.
    _pool.shown.removeListener(_onShown);
    _handle?.value.removeListener(_onPlayer);
    _toTheEnd?.cancel();
    super.dispose();
  }

  /// Takes the pool's player once it shows the source.
  void _onShown() {
    final ShownPlayer? shown = _pool.shown.value;
    final PlayerHandle? handle = shown?.path == widget.path
        ? shown?.handle
        : null;
    if (handle == null || identical(handle, _handle)) return;
    _handle = handle;
    // The editor loops the kept part itself, from its start.
    unawaited(handle.setLooping(false));
    handle.value.addListener(_onPlayer);
    _onPlayer();
  }

  TrimSelection? get _trim => _editor.state.trim;

  void _onPlayer() {
    final PlayerHandle handle = _handle!;
    final PlayerState state = handle.value.value;
    if (state.error != null) {
      if (!_failed) {
        _editor.sourceFailed();
        setState(() {
          _failed = true;
          _visible = false;
        });
      }
      return;
    }
    if (!state.initialized) return;
    if (!_loaded) {
      _loaded = true;
      _editor.sourceLoaded(state.duration, aspectRatio: state.aspectRatio);
      setState(() => _visible = true);
      _seek(_trim?.startMs ?? 0);
      if (_tickerEnabled) unawaited(handle.play());
    }
    _loop(handle, state);
    // Starting or looping above may have changed the player already.
    final bool playing = handle.value.value.playing;
    if (playing != _playing) setState(() => _playing = playing);
  }

  /// Plays the saved part again from its start once it ran past its end.
  ///
  /// The player reports its position every 100 ms, so from each report a
  /// timer is set to the end: the part plays exactly as long as it is kept.
  void _loop(PlayerHandle handle, PlayerState state) {
    _toTheEnd?.cancel();
    _toTheEnd = null;
    final EditClipState editor = _editor.state;
    final TrimSelection? trim = editor.trim;
    if (trim == null || editor.trimming) return;
    final int end = trim.savedEndMs;
    final int left = end - state.position.inMilliseconds;
    if (state.completed || (state.playing && left <= 0)) {
      _seek(trim.startMs);
      if (state.completed) unawaited(handle.play());
    } else if (state.playing) {
      _toTheEnd = Timer(Duration(milliseconds: left), () {
        _toTheEnd = null;
        if (mounted && handle.value.value.playing && !_editor.state.trimming) {
          _seek(trim.startMs);
        }
      });
    }
  }

  void _seek(int ms) {
    _nextSeekMs = ms;
    if (!_seeking) unawaited(_seekLatest());
  }

  Future<void> _seekLatest() async {
    _seeking = true;
    while (_nextSeekMs != null && mounted) {
      final int ms = _nextSeekMs!;
      _nextSeekMs = null;
      await _handle?.seekTo(Duration(milliseconds: ms));
    }
    _seeking = false;
  }

  /// A finger went down on the trim window, moved it, or lifted.
  void _onTrim(EditClipState state) {
    final PlayerHandle? handle = _handle;
    final TrimSelection? trim = state.trim;
    if (handle == null || trim == null) return;
    if (state.trimming && handle.value.value.playing) {
      _playAfterTrim = true;
      unawaited(handle.pause());
    }
    _seek(trim.startMs);
    if (!state.trimming && _playAfterTrim) {
      _playAfterTrim = false;
      unawaited(handle.play());
    }
  }

  /// The save started, or ended without leaving (cancelled, failed): the
  /// player rests while ffmpeg decodes the same file, and plays on after if
  /// it was playing.
  void _onSaving({required bool saving}) {
    final PlayerHandle? handle = _handle;
    if (handle == null) return;
    if (saving && handle.value.value.playing) {
      _playAfterSave = true;
      unawaited(handle.pause());
    } else if (!saving && _playAfterSave) {
      _playAfterSave = false;
      if (_tickerEnabled) unawaited(handle.play());
    }
  }

  /// A tap: pause, or play. While the clip saves the player rests, so a
  /// tap does nothing.
  Future<void> _toggle() async {
    final PlayerHandle? handle = _handle;
    if (handle == null || !_visible || _editor.state.saving) return;
    _pausedByPage = false;
    if (handle.value.value.playing) {
      await handle.pause();
      return;
    }
    final TrimSelection? trim = _trim;
    if (handle.value.value.completed && trim != null) _seek(trim.startMs);
    await handle.play();
  }

  @override
  Widget build(BuildContext context) {
    final PlayerHandle? handle = _handle;
    return MultiBlocListener(
      listeners: <BlocListener<EditClipCubit, EditClipState>>[
        BlocListener<EditClipCubit, EditClipState>(
          listenWhen: (EditClipState before, EditClipState after) =>
              before.trimming != after.trimming || before.trim != after.trim,
          listener: (BuildContext context, EditClipState state) =>
              _onTrim(state),
        ),
        BlocListener<EditClipCubit, EditClipState>(
          listenWhen: (EditClipState before, EditClipState after) =>
              before.saving != after.saving,
          listener: (BuildContext context, EditClipState state) =>
              _onSaving(saving: state.saving),
        ),
      ],
      child: Semantics(
        button: true,
        label: _playing ? Strings.playerPause : Strings.play,
        onTap: _toggle,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: _toggle,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (_failed)
                Center(
                  child: PlayerErrorBlock(
                    title: Strings.playerErrorTitle,
                    body: Strings.playerErrorBody,
                  ),
                )
              else
                OsdLoadingDelay(
                  loading: !_visible,
                  builder: (BuildContext context, bool show) => show
                      ? const Center(
                          child: OsdSpinner(size: 24, color: OsdMedia.onMedia),
                        )
                      : const SizedBox.shrink(),
                ),
              AnimatedOpacity(
                opacity: handle != null && _visible ? 1 : 0,
                duration: OsdMotion.d(context, OsdMotion.fast),
                curve: OsdMotion.fastCurve,
                child: KeyedSubtree(
                  key: VideoSourcePreview.videoKey,
                  child: handle == null
                      ? const SizedBox.shrink()
                      : RepaintBoundary(
                          child: FrameViewport(
                            aspectRatio: handle.value.value.aspectRatio,
                            canvasAspectRatio: widget.canvasAspectRatio,
                            frame: widget.frame,
                            blurred: handle.buildView(),
                            child: handle.buildView(),
                          ),
                        ),
                ),
              ),
              Center(
                child: BlocSelector<EditClipCubit, EditClipState, bool>(
                  selector: (EditClipState state) => state.trimming,
                  builder: (BuildContext context, bool trimming) =>
                      PlayOverlayButton(
                        key: VideoSourcePreview.playKey,
                        visible: _visible && !_playing && !trimming,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
