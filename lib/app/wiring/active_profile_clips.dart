import 'dart:async';

import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/domain/profiles_snapshot.dart';

/// What changed about the active profile's clips: [previous] is the
/// snapshot before (null when there was none); [switched] says another
/// profile became active. The new snapshot is `ActiveProfileClips.index`.
typedef ActiveClipsChanged =
    void Function({required ClipIndex? previous, required bool switched});

/// The active profile's clip snapshot, across profile switches, for the
/// wiring that only cares about the active diary (the reminders' recorded
/// days, the downgrade counters). Each such wiring owns one.
final class ActiveProfileClips {
  ActiveProfileClips({required this._profiles, required this._clips});

  final ProfilesRepository _profiles;
  final ClipRepository _clips;

  ActiveClipsChanged? _onChanged;
  StreamSubscription<ProfilesSnapshot>? _profilesChanges;
  StreamSubscription<ClipIndex>? _clipsChanges;
  ProfileKey? _key;
  ClipIndex? _index;

  /// The active profile's latest snapshot; null until its diary is read.
  ClipIndex? get index => _index;

  /// Starts following the active profile. [onChanged] runs at once when its
  /// diary is already read, then for each new snapshot of it, and on each
  /// switch (with the new profile's snapshot as it is then). A failed scan
  /// is left to the screens: `ClipRepository` logs it.
  void listen(ActiveClipsChanged onChanged) {
    assert(_onChanged == null, 'Listened to twice');
    _onChanged = onChanged;
    _key = _profiles.active.key;
    _index = _clips.snapshotOf(_key!);
    if (_index != null) onChanged(previous: null, switched: false);
    _followClipsOf(_key!);
    _profilesChanges = _profiles.watch().listen(_profilesChanged);
  }

  void _profilesChanged(ProfilesSnapshot snapshot) {
    final ProfileKey active = snapshot.active.key;
    if (active == _key) return;
    final ClipIndex? previous = _index;
    _key = active;
    _index = _clips.snapshotOf(active);
    _onChanged!(previous: previous, switched: true);
    _followClipsOf(active);
  }

  void _followClipsOf(ProfileKey profile) {
    unawaited(_clipsChanges?.cancel());
    _clipsChanges = _clips.watch(profile).listen((ClipIndex index) {
      // The stream starts with the snapshot already read.
      if (identical(index, _index)) return;
      final ClipIndex? previous = _index;
      _index = index;
      _onChanged!(previous: previous, switched: false);
    }, onError: (Object _) {});
  }

  Future<void> dispose() async {
    await _profilesChanges?.cancel();
    await _clipsChanges?.cancel();
  }
}
