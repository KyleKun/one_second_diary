import 'dart:async';

import 'package:one_second_diary/features/clips/data/clip_metadata_backfill.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/domain/profiles_snapshot.dart';

/// The active profile's clip index for the Journey cubits: the snapshot in
/// memory at once, then each new one, switching with the profile; and the
/// metadata backfill's progress while a snapshot's facts are still being
/// learnt ([awaitBackfill]).
///
/// Call [start] once the owner can take the callbacks; [close] stops
/// everything at once.
final class DiaryFollower {
  DiaryFollower({
    required this._profiles,
    required this._clips,
    required this._backfill,
    required this.onLoading,
    required this.onIndex,
    required this.onFailed,
    required this.onMetadata,
  });

  final ProfilesRepository _profiles;
  final ClipRepository _clips;
  final ClipMetadataBackfill _backfill;

  /// The active profile has no snapshot in memory yet.
  final void Function() onLoading;

  /// A snapshot of the active profile to show.
  final void Function(ClipIndex index) onIndex;

  /// The diary could not be read before any snapshot (`ClipRepository`
  /// logged why, and sends its next snapshot when a rescan works).
  final void Function() onFailed;

  /// The backfill learnt more about [shown]'s clips, or finished.
  final void Function() onMetadata;

  StreamSubscription<ProfilesSnapshot>? _profilesChanges;
  StreamSubscription<ClipIndex>? _index;
  StreamSubscription<void>? _backfillProgress;
  bool _awaitingBackfill = false;
  bool _closed = false;
  ProfileKey? _profile;
  ClipIndex? _shown;

  /// The profile followed.
  ProfileKey? get profile => _profile;

  /// The snapshot shown; null while loading.
  ClipIndex? get shown => _shown;

  void start() {
    _follow(_profiles.active.key);
    _profilesChanges = _profiles.watch().listen(
      (ProfilesSnapshot snapshot) => _follow(snapshot.active.key),
    );
  }

  /// Stops following at once, without waiting for the streams.
  void close() {
    _closed = true;
    unawaited(_profilesChanges?.cancel());
    unawaited(_index?.cancel());
    unawaited(_backfillProgress?.cancel());
  }

  /// Reads the followed profile's folder again after a failure and shows
  /// the result, unless a snapshot arrived meanwhile. Throws what
  /// `ClipRepository.rescan` throws.
  Future<void> rescan() async {
    final ProfileKey? profile = _profile;
    if (profile == null) return;
    final ClipIndex index = await _clips.rescan(profile);
    if (!_closed && _profile == profile && _shown == null) _show(index);
  }

  /// Tells [onMetadata] as the running backfill reports progress (a first
  /// backfill of a long diary takes minutes) and once it is idle. A
  /// backfill that is idle answers at once (a clip it could not probe stays
  /// unknown until its file changes), so this never loops.
  Future<void> awaitBackfill() async {
    if (_awaitingBackfill) return;
    _awaitingBackfill = true;
    _backfillProgress = _backfill.progress.listen((_) => onMetadata());
    try {
      // The library wiring feeds the backfill the snapshot just shown: let
      // it, so the wait covers that snapshot.
      await Future<void>.value();
      await _backfill.whenIdle;
    } finally {
      _awaitingBackfill = false;
      unawaited(_backfillProgress?.cancel());
      _backfillProgress = null;
    }
    if (!_closed && _shown != null) onMetadata();
  }

  void _follow(ProfileKey profile) {
    if (profile == _profile) return;
    _profile = profile;
    unawaited(_index?.cancel());
    final ClipIndex? index = _clips.snapshotOf(profile);
    if (index != null) {
      _show(index);
    } else {
      _shown = null;
      onLoading();
    }
    _index = _clips
        .watch(profile)
        .listen(
          _show,
          onError: (Object _) {
            if (_shown == null) onFailed();
          },
        );
  }

  void _show(ClipIndex index) {
    _shown = index;
    onIndex(index);
  }
}
