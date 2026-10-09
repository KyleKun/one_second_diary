import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/player_handle.dart';
import 'package:one_second_diary/core/platform/player_state.dart';
import 'package:one_second_diary/core/router/app_route.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_metadata_cache.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/data/shown_player.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_playback.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_player_view.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_thumbnail_view.dart';
import 'package:one_second_diary/features/diary/presentation/diary_opener.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/features/settings/data/settings_repository.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_pill_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/play_overlay_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/viewer_top_bar.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_loading_delay.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_spinner.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';
import 'package:one_second_diary/shared/widgets/progress/viewer_progress_bar.dart';
import 'package:one_second_diary/shared/widgets/surfaces/player_error_block.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The clips of one place, always dark: swipe between them; a tap plays or
/// pauses the one shown, and while playing each clip's end moves on to the
/// next, until the last one ends. "Open day" opens the Diary on the clip's
/// day.
///
/// Only the page shown holds a `ClipPlayerView` (the others show their
/// posters), so a page built mid-swipe never takes the shown player; the
/// neighbours are kept warm, so a swipe plays at once. A private clip stays
/// under its cover, and the chain with it, until the user taps it.
class PlaceClipsPage extends StatefulWidget {
  const PlaceClipsPage({super.key, required this.args});

  final PlaceClipsArgs args;

  @override
  State<PlaceClipsPage> createState() => _PlaceClipsPageState();
}

class _PlaceClipsPageState extends State<PlaceClipsPage> {
  static const Duration _advance = Duration(milliseconds: 280);
  static const Curve _advanceCurve = Curves.easeOutCubic;

  late final PageController _pages = PageController(
    initialPage: widget.args.initialIndex,
  );
  late final _ShownPlayback _playback = _ShownPlayback(
    pool: context.read<PlayerPool>(),
    paths: context.read<AppPaths>(),
    clip: _clips[_index],
  );
  late int _index = widget.args.initialIndex;
  late bool _playing = widget.args.autoplay;
  late bool _muted = !context
      .read<SettingsRepository>()
      .calendarAutoSound
      .value;

  /// The private clips the user uncovered here.
  final Set<ClipRef> _revealed = <ClipRef>{};

  List<ClipRef> get _clips => widget.args.clips;

  ClipRef get _clip => _clips[_index];

  @override
  void dispose() {
    _playback.dispose();
    _pages.dispose();
    super.dispose();
  }

  /// The clip on page [index] played to its end. A page swiped away may
  /// still report in the frame before it goes: only the page shown moves on.
  void _onCompleted(int index) {
    if (index != _index || !_playing || !mounted) return;
    if (index < _clips.length - 1) {
      unawaited(
        _pages.nextPage(
          duration: OsdMotion.d(context, _advance),
          curve: _advanceCurve,
        ),
      );
    } else {
      setState(() => _playing = false);
    }
  }

  void _toggle(ClipPlayback playback, ClipPlayerControls controls) {
    final bool play = !playback.isPlaying;
    unawaited(play ? controls.play() : controls.pause());
    setState(() => _playing = play);
  }

  void _onRevealed(ClipRef clip) => setState(() {
    _revealed.add(clip);
    _playing = true;
  });

  void _onPage(int index) {
    _playback.follow(_clips[index]);
    setState(() => _index = index);
  }

  /// The sound toggle: remembers the choice (`calendarAutoSound`), as the
  /// Diary's viewer does.
  Future<void> _toggleSound() async {
    final bool on = _muted;
    setState(() => _muted = !on);
    try {
      await context.read<SettingsRepository>().calendarAutoSound.set(on);
    } on StorageException catch (error, stackTrace) {
      if (!mounted) return;
      context.read<AppLogger>().warning(
        'PLACES',
        "Could not remember the viewer's sound choice",
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _openDay() {
    context.read<DiaryOpener>().showDay(_clip.day);
    AppRoute.diary.go(context);
  }

  /// The clip's own place, else the page's title.
  String _placeOf(BuildContext context, ClipRef clip) {
    final FileStamp? stamp = context
        .read<ClipRepository>()
        .snapshotOf(clip.profile)
        ?.stampOf(clip);
    final String place = stamp == null
        ? ''
        : context
                  .read<ClipMetadataCache>()
                  .lookup(relPath: clip.relPath, stamp: stamp)
                  ?.locationText
                  ?.trim() ??
              '';
    return place.isEmpty ? widget.args.title : place;
  }

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final ClipRef clip = _clip;
    final VideoOrientation orientation = context.select(
      (ProfilesCubit cubit) => cubit.state.profiles
          .firstWhere(
            (Profile profile) => profile.key == clip.profile,
            orElse: () => cubit.state.active,
          )
          .orientation,
    );
    return Scaffold(
      backgroundColor: OsdMedia.letterbox,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            ViewerTopBar(
              onClose: () => context.pop(),
              closeTooltip: CommonLabels.of(context).close,
              title: widget.args.title,
              subtitle: LocaleFormats.of(
                context,
              ).date('yMMMd').format(clip.day.toLocalDateTime()),
              muted: _muted,
              onToggleMute: () => unawaited(_toggleSound()),
              muteTooltip: Strings.playerMute,
              unmuteTooltip: Strings.playerUnmute,
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _clips.length,
                onPageChanged: _onPage,
                itemBuilder: (BuildContext context, int i) => _ClipFrame(
                  orientation: orientation,
                  child: i == _index
                      ? ClipPlayerView(
                          key: ValueKey<ClipRef>(_clips[i]),
                          clip: _clips[i],
                          slot: ClipThumbnailSlot.viewer,
                          orientation: orientation,
                          radius: OsdRadius.r12,
                          neighbours: <ClipRef>[
                            if (i > 0) _clips[i - 1],
                            if (i < _clips.length - 1) _clips[i + 1],
                          ],
                          autoPlay: _playing,
                          loop: false,
                          muted: _muted,
                          revealPrivate: _revealed.contains(_clips[i]),
                          onRevealed: () => _onRevealed(_clips[i]),
                          onCovered: () =>
                              setState(() => _revealed.remove(_clips[i])),
                          onCompleted: () => _onCompleted(i),
                          overlayBuilder:
                              (
                                BuildContext context,
                                ClipPlayback playback,
                                ClipPlayerControls controls,
                              ) => _Controls(
                                playback: playback,
                                advancing: _playing && i < _clips.length - 1,
                                onTap: () => _toggle(playback, controls),
                              ),
                        )
                      : ClipThumbnailView(
                          clip: _clips[i],
                          slot: ClipThumbnailSlot.viewer,
                          orientation: orientation,
                          radius: OsdRadius.r12,
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Column(
                spacing: 14,
                children: <Widget>[
                  _Progress(playback: _playback),
                  Row(
                    spacing: 10,
                    children: <Widget>[
                      OsdIcon(OsdIcons.place, size: 18, color: colors.mu),
                      Expanded(
                        child: Text(
                          _placeOf(context, clip),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.label14.copyWith(color: colors.tx),
                        ),
                      ),
                      Text(
                        Strings.viewerClipPosition(
                          index: _index + 1,
                          count: _clips.length,
                        ),
                        style: typography.caption13.copyWith(color: colors.mu),
                      ),
                      OsdPillButton(
                        label: Strings.placeClipsOpenDay,
                        onPressed: _openDay,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One page's frame: the profile's shape, centred.
class _ClipFrame extends StatelessWidget {
  const _ClipFrame({required this.orientation, required this.child});

  final VideoOrientation orientation;
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: orientation == VideoOrientation.portrait ? 9 / 16 : 16 / 9,
      child: child,
    ),
  );
}

/// Over the clip shown: the tap that plays or pauses, the play (or replay)
/// circle while it rests, the loading spinner, or the error block.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.playback,
    required this.advancing,
    required this.onTap,
  });

  static const double _spinner = 28;

  final ClipPlayback playback;

  /// The next clip follows this one's end: no replay circle then.
  final bool advancing;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (playback.phase == ClipPlaybackPhase.failed) {
      return PlayerErrorBlock(
        title: Strings.playerErrorTitle,
        body: Strings.playerErrorBody,
      );
    }
    final bool ended = playback.phase == ClipPlaybackPhase.completed;
    final bool resting =
        playback.phase == ClipPlaybackPhase.paused || (ended && !advancing);
    return Semantics(
      button: true,
      label: playback.isPlaying ? Strings.playerPause : Strings.play,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: OsdLoadingDelay(
            loading: playback.phase == ClipPlaybackPhase.loading,
            builder: (BuildContext context, bool showLoading) => showLoading
                ? const OsdSpinner(size: _spinner, color: OsdMedia.onMedia)
                : PlayOverlayButton(visible: resting, ended: ended),
          ),
        ),
      ),
    );
  }
}

/// The player of the clip shown, as the page's `PlayerPool` shows it: its
/// state while the pool shows that clip, else null. [follow] moves it to
/// another clip.
final class _ShownPlayback extends ChangeNotifier
    implements ValueListenable<PlayerState?> {
  _ShownPlayback({
    required this._pool,
    required this._paths,
    required ClipRef clip,
  }) : _path = _paths.absoluteFromVideos(clip.relPath) {
    _pool.shown.addListener(_onShown);
    _onShown();
  }

  final PlayerPool _pool;
  final AppPaths _paths;
  String _path;
  PlayerHandle? _handle;
  bool _deferred = false;
  bool _disposed = false;

  @override
  PlayerState? get value => _handle?.value.value;

  void follow(ClipRef clip) {
    final String path = _paths.absoluteFromVideos(clip.relPath);
    if (path == _path) return;
    _path = path;
    _onShown();
  }

  void _onShown() {
    final ShownPlayer? shown = _pool.shown.value;
    final PlayerHandle? handle = shown?.path == _path ? shown?.handle : null;
    if (identical(handle, _handle)) return;
    _handle?.value.removeListener(_changed);
    _handle = handle;
    handle?.value.addListener(_changed);
    _changed();
  }

  // A player may report mid-frame (a pause as a page goes away): the
  // listeners hear it after the frame, so they can always rebuild.
  void _changed() {
    if (SchedulerBinding.instance.schedulerPhase !=
        SchedulerPhase.persistentCallbacks) {
      notifyListeners();
      return;
    }
    if (_deferred) return;
    _deferred = true;
    scheduleMicrotask(() {
      _deferred = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _handle?.value.removeListener(_changed);
    _pool.shown.removeListener(_onShown);
    super.dispose();
  }
}

/// The progress bar: how far the clip shown has played. The player reports
/// its position only now and then, so while it plays a ticker moves the
/// bar on from the last report; a report a little behind the bar is the
/// player's lag and never pulls it back.
class _Progress extends StatefulWidget {
  const _Progress({required this.playback});

  final ValueListenable<PlayerState?> playback;

  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress>
    with SingleTickerProviderStateMixin {
  static const Duration _lag = Duration(milliseconds: 250);

  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  Duration _from = Duration.zero;
  Duration _fromAt = Duration.zero;
  Duration? _reportedPosition;
  Duration _now = Duration.zero;
  late final Ticker _ticker = createTicker((Duration elapsed) {
    _now = elapsed;
    _update();
  });

  @override
  void initState() {
    super.initState();
    widget.playback.addListener(_reported);
    _reported();
  }

  @override
  void dispose() {
    widget.playback.removeListener(_reported);
    _ticker.dispose();
    _progress.dispose();
    super.dispose();
  }

  Duration get _shown =>
      _from + (_ticker.isActive ? _now - _fromAt : Duration.zero);

  void _reported() {
    final PlayerState? state = widget.playback.value;
    if (state == null || !state.playing) {
      _ticker.stop();
      _now = Duration.zero;
      _fromAt = Duration.zero;
      _from = state?.position ?? Duration.zero;
      _reportedPosition = state?.position;
      _update();
      return;
    }
    final bool moved = state.position != _reportedPosition;
    _reportedPosition = state.position;
    if (!_ticker.isActive) {
      _from = state.position;
      _now = Duration.zero;
      _fromAt = Duration.zero;
      _ticker.start();
    } else if (moved) {
      final Duration shown = _shown;
      final bool lagging =
          state.position <= shown && shown - state.position < _lag;
      _from = lagging ? shown : state.position;
      _fromAt = _now;
    }
    _update();
  }

  void _update() {
    final PlayerState? state = widget.playback.value;
    if (state == null || state.duration <= Duration.zero) {
      _progress.value = 0;
      return;
    }
    final Duration position = state.completed ? state.duration : _shown;
    _progress.value = (position.inMicroseconds / state.duration.inMicroseconds)
        .clamp(0, 1);
  }

  @override
  Widget build(BuildContext context) => ViewerProgressBar(progress: _progress);
}
