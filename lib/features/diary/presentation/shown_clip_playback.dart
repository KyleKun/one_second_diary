import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:one_second_diary/core/platform/player_handle.dart';
import 'package:one_second_diary/core/platform/player_state.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/data/shown_player.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';

/// The player of one clip as the screen's `PlayerPool` shows it, for what
/// sits outside the `ClipPlayerView` (the viewer's progress bar under the
/// video, the Share tile that waits while the clip can't be played): its
/// [PlayerState] while the pool shows that clip, else null.
///
/// It notifies on each change of that player; [follow] moves it to
/// another clip. A player may report while the frame is being built (a
/// pause as a view goes away): that report reaches the listeners right
/// after the frame, so they can always rebuild.
final class ShownClipPlayback extends ChangeNotifier
    implements ValueListenable<PlayerState?> {
  ShownClipPlayback({
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

  @override
  PlayerState? get value => _handle?.value.value;

  /// Plays the clip again from its start (a tap on the progress bar).
  Future<void> restart() async {
    final PlayerHandle? handle = _handle;
    if (handle == null) return;
    await handle.seekTo(Duration.zero);
    await handle.play();
  }

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

  bool _deferred = false;
  bool _disposed = false;

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
