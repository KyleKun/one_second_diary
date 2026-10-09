import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/platform/player_factory.dart';
import 'package:one_second_diary/core/platform/player_handle.dart';
import 'package:one_second_diary/core/platform/player_state.dart';
import 'package:one_second_diary/features/clips/data/shown_player.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';

/// The video players of one screen (Diary mini player, Today card, viewer):
/// the selected clip plus its previous and next recorded clips, warm and
/// paused, so stepping through the diary plays at once.
///
/// - at most three players live: the selected clip and its two neighbours;
///   anything else is disposed as soon as it is not wanted;
/// - the old clip stays on screen until the new player is ready ([shown]
///   changes then), and only then leaves: paused and back at its start if
///   it is a neighbour (coming back to it plays it from the start),
///   disposed otherwise;
/// - every [select] and [setMuted] takes a generation number, so a player
///   that finishes loading after a newer call is never shown;
/// - a player is keyed by file; a [select] of a file rewritten since its
///   player opened (a replaced clip: the same name, new bytes) opens it
///   again instead of reusing the player. ExoPlayer keeps the sample table
///   it parsed when it opened and reads the file again on a seek or a
///   loop, and new bytes under the old table fail (`Invalid NAL length`);
/// - looping and volume are set together once a player is initialised;
/// - all players share one audio mode: muted players mix with other apps'
///   audio, audible ones take audio focus. On iOS the mode is app-wide and
///   the last player to initialise wins, so [setMuted] rebuilds every
///   player in the new mode, keeping the clip on screen, its position and
///   its play state.
///
/// Playing and pausing the [shown] player is the screen's call (autoplay
/// and the user's taps); a clip that cannot be played is shown anyway, its
/// handle carrying the error, and logged.
///
/// Kept a plain class (not final) so screen tests can fake it.
class PlayerPool {
  PlayerPool({
    required this._factory,
    required this._logger,
    required this._muted,
  });

  final PlayerFactory _factory;
  final AppLogger _logger;
  bool _muted;

  static const String _tag = 'CALENDAR';

  final ValueNotifier<ShownPlayer?> _shown = ValueNotifier<ShownPlayer?>(null);

  /// Live players by file.
  final Map<String, _Player> _players = <String, _Player>{};

  /// The latest [select]: what [setMuted] shows again with new players.
  ({String path, List<String> neighbours})? _selection;

  /// Bumped by every [select] and [setMuted]: an older call that finishes
  /// later is stale and changes nothing.
  int _generation = 0;

  bool _disposed = false;

  /// The player on screen: null until the first selected clip is ready.
  ValueListenable<ShownPlayer?> get shown => _shown;

  double get _volume => _muted ? 0 : 1;

  /// Shows the clip at [path] once its player is ready, and keeps
  /// [neighbours] (at most two: the previous and next recorded clips) warm.
  /// Completes when it is shown, or when a newer call made it stale.
  Future<void> select(
    String path, {
    List<String> neighbours = const <String>[],
  }) async {
    if (neighbours.length > 2) {
      throw ArgumentError.value(
        neighbours,
        'neighbours',
        'at most the previous and the next clip',
      );
    }
    _selection = (path: path, neighbours: neighbours);
    await _show(path, neighbours);
  }

  /// Mutes or unmutes: the clip on screen changes volume at once, then
  /// every player is rebuilt in the matching audio mode (see the class
  /// doc).
  Future<void> setMuted(bool muted) async {
    if (_disposed || muted == _muted) return;
    _muted = muted;
    final ShownPlayer? shown = _shown.value;
    unawaited(shown?.handle.setVolume(_volume)); // heard at once
    final ({String path, List<String> neighbours})? selection = _selection;
    if (selection == null) return;
    // Every player was made with the other mixing value, and on iOS the
    // last one to initialise sets it for the whole app: start over. The
    // clip on screen stays there until its replacement is ready. Only the
    // on-screen HANDLE leaves the pool undisposed: a replacement of the same
    // clip still loading from a previous toggle is disposed like any other.
    for (final MapEntry<String, _Player> entry in _players.entries.toList()) {
      if (identical(entry.value.handle, shown?.handle)) {
        _players.remove(entry.key);
      } else {
        unawaited(_drop(entry.key));
      }
    }
    await _show(
      selection.path,
      selection.neighbours,
      carryOver: shown?.path == selection.path
          ? shown?.handle.value.value
          : null,
    );
  }

  /// Gives up the player of the clip at [path] to another screen's pool
  /// ([adopt]), when it is ready and playable: the viewer takes the
  /// Diary's warm player, so the clip it opens on plays at once. The player
  /// leaves this pool undisposed (its new owner disposes it) and, when it
  /// was on screen, the screen: [shown] turns null, and the screen shows
  /// the clip's poster until it selects a clip again. Null, and nothing
  /// changes, when no ready player of [path] is here.
  ShownPlayer? release(String path) {
    if (_disposed) return null;
    final ShownPlayer? onScreen = _shown.value;
    final PlayerHandle? handle = onScreen?.path == path
        ? onScreen!.handle
        : _players[path]?.handle;
    if (handle == null) return null;
    final PlayerState state = handle.value.value;
    if (!state.initialized || state.error != null) return null;
    if (identical(_players[path]?.handle, handle)) _players.remove(path);
    if (identical(onScreen?.handle, handle)) {
      // A select of this clip still finishing must not show it again.
      _generation++;
      _shown.value = null;
    }
    return ShownPlayer(path: path, handle: handle);
  }

  /// Takes over [player], [release]d by another pool: a later [select] of
  /// its clip shows it without opening the file again. It is set to start
  /// over (paused at the start) with this pool's looping and volume, and
  /// this pool disposes it from now on. Its audio mode stays the one it was
  /// made with (see [PlayerFactory.create]): a player made muted and mixing
  /// keeps mixing with the user's music while this pool plays it aloud.
  void adopt(ShownPlayer player) {
    if (_disposed || _players.containsKey(player.path)) {
      unawaited(player.handle.dispose());
      return;
    }
    _players[player.path] = _Player(
      player.handle,
      _takeOver(player.path, player.handle),
      _stampOf(player.path),
    );
  }

  /// Disposes every player; a select still loading shows nothing. Calling
  /// it again does nothing.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _generation++; // a select still loading is now stale
    final PlayerHandle? onScreen = _shown.value?.handle;
    _shown.dispose();
    await Future.wait(<Future<void>>[
      for (final String path in _players.keys.toList()) _drop(path),
      if (onScreen != null) onScreen.dispose(),
    ]);
  }

  /// Shows [path] once its player is ready (the old clip stays on screen
  /// until then) and keeps [neighbours] warm. [carryOver] is the state of
  /// the player this one replaces for the same clip.
  Future<void> _show(
    String path,
    List<String> neighbours, {
    PlayerState? carryOver,
  }) async {
    final int generation = ++_generation;
    final Set<String> wanted = <String>{path, ...neighbours};
    _dropAllBut(wanted);
    final _Player? pooled = _players[path];
    if (pooled != null) {
      // Only a pooled player costs a wait here: a fresh one opens at once,
      // so a dispose racing this call still finds it.
      await _forgetIfRewritten(path, pooled);
      if (generation != _generation) return;
    }
    final _Player player = _players[path] ??= _open(path);
    await player.ready;
    if (generation != _generation) return;
    if (carryOver != null) {
      // One that had played to its end stays at the start, ready to replay.
      if (!carryOver.completed) await player.handle.seekTo(carryOver.position);
      if (carryOver.playing) await player.handle.play();
      if (generation != _generation) return;
    }
    final ShownPlayer? old = _shown.value;
    _shown.value = ShownPlayer(path: path, handle: player.handle);
    // The old player leaves (paused if it is a warm neighbour, else
    // disposed) before the neighbours are warmed, so there are never more
    // than three players. Both start synchronously: a dispose racing this
    // call finds every player.
    final Future<void> leaving = _leave(old, wanted, player.handle);
    for (final String neighbour in neighbours) {
      _players[neighbour] ??= _open(neighbour);
    }
    await leaving;
  }

  Future<void> _leave(
    ShownPlayer? old,
    Set<String> wanted,
    PlayerHandle replacement,
  ) {
    if (old == null || identical(old.handle, replacement)) {
      return Future<void>.value();
    }
    final bool pooled = identical(_players[old.path]?.handle, old.handle);
    if (!pooled) return old.handle.dispose();
    return wanted.contains(old.path) ? _rest(old.handle) : _drop(old.path);
  }

  /// Leaves a warm neighbour paused at its start.
  static Future<void> _rest(PlayerHandle handle) async {
    await handle.pause();
    await handle.seekTo(Duration.zero);
  }

  _Player _open(String path) {
    final PlayerHandle handle = _factory.create(path, mixWithOthers: _muted);
    return _Player(handle, _prepare(path, handle), _stampOf(path));
  }

  /// Takes [player] out of the pool when the file at [path] is not the one
  /// it opened (size or modification time changed: a replaced clip), so
  /// the next open reads the new file. One not on screen is disposed; the
  /// one on screen stays there until its replacement is ready, then
  /// [_leave] disposes it.
  Future<void> _forgetIfRewritten(String path, _Player player) async {
    final FileStamp? opened = await player.stamp;
    final FileStamp? now = await _stampOf(path);
    if (_disposed || opened == now || !identical(_players[path], player)) {
      return;
    }
    _logger.verbose(_tag, 'The file of $path was rewritten: opening it again');
    _players.remove(path);
    if (!identical(player.handle, _shown.value?.handle)) {
      unawaited(player.handle.dispose());
    }
  }

  /// The size and modification time of the file at [path]; null when it
  /// cannot be read (missing, or not a file at all).
  static Future<FileStamp?> _stampOf(String path) async {
    final FileStat stat = await File(path).stat();
    if (stat.type != FileSystemEntityType.file) return null;
    return FileStamp(
      sizeBytes: stat.size,
      modifiedMs: stat.modified.millisecondsSinceEpoch,
    );
  }

  /// Opens [handle] and sets it looping at the pool's volume. Never throws:
  /// a clip that cannot be played is logged, and its handle reports the
  /// error for the screen to show.
  Future<void> _prepare(String path, PlayerHandle handle) async {
    try {
      await handle.initialize();
      await Future.wait(<Future<void>>[
        handle.setLooping(true),
        handle.setVolume(_volume),
      ]);
    } on Object catch (error, stackTrace) {
      // The contract does not type the error: a PlatformException from the
      // plugin, anything from a fake.
      _logger.warning(
        _tag,
        'Could not open the player of $path',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Readies an adopted [handle]: paused at the start, looping at the
  /// pool's volume. Never throws (logged).
  Future<void> _takeOver(String path, PlayerHandle handle) async {
    // Adopted as the new screen builds its pool: its old screen still
    // listens to it until its next frame.
    await Future<void>.value();
    try {
      await Future.wait(<Future<void>>[
        handle.pause(),
        handle.seekTo(Duration.zero),
        handle.setLooping(true),
        handle.setVolume(_volume),
      ]);
    } on Object catch (error, stackTrace) {
      _logger.warning(
        _tag,
        'Could not take over the player of $path',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Disposes every player not in [keep] and not on screen. On screen is
  /// decided by handle, not path: after [setMuted] the pool may hold a
  /// second, still loading player of the clip on screen, which goes too.
  void _dropAllBut(Set<String> keep) {
    final PlayerHandle? onScreen = _shown.value?.handle;
    for (final MapEntry<String, _Player> entry in _players.entries.toList()) {
      if (!keep.contains(entry.key) &&
          !identical(entry.value.handle, onScreen)) {
        unawaited(_drop(entry.key));
      }
    }
  }

  Future<void> _drop(String path) async {
    await _players.remove(path)?.handle.dispose();
  }
}

final class _Player {
  _Player(this.handle, this.ready, this.stamp);

  final PlayerHandle handle;

  /// Completes when [handle] is initialised (or failed to).
  final Future<void> ready;

  /// The file as it was when [handle] opened it; null when it could not be
  /// read then.
  final Future<FileStamp?> stamp;
}
