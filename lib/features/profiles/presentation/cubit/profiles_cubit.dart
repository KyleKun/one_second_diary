import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/domain/profiles_snapshot.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_state.dart';

/// The profiles for every screen (app-scoped): the list, the active profile
/// and each profile's clip count. Follows `ProfilesRepository.watch()` and
/// each profile's `ClipRepository.watch`; counts appear as the launch reads
/// each diary.
class ProfilesCubit extends Cubit<ProfilesState> {
  ProfilesCubit({
    required ProfilesRepository profiles,
    required this._clips,
    required this._logger,
  }) : _profiles = profiles,
       super(
         ProfilesState(profiles: profiles.profiles, active: profiles.active),
       ) {
    _snapshots = profiles.watch().listen(_snapshotChanged);
    _followCounts(state.profiles);
  }

  final ProfilesRepository _profiles;
  final ClipRepository _clips;
  final AppLogger _logger;

  static const String _tag = 'PROFILES';

  late final StreamSubscription<ProfilesSnapshot> _snapshots;

  /// One clip-snapshot subscription per listed profile.
  final Map<ProfileKey, StreamSubscription<ClipIndex>> _counts =
      <ProfileKey, StreamSubscription<ClipIndex>>{};

  /// Makes [key] the profile new clips go to. The state follows
  /// once the repository announces the switch; a switch the phone refuses
  /// leaves the active profile as it was and says so, once per refusal.
  Future<void> activate(ProfileKey key) async {
    emit(state.copyWith(status: ProfilesStatus.activating, switchingTo: key));
    try {
      await _profiles.activate(key);
      _logger.info(_tag, 'Selected Profile changed!');
      emit(state.copyWith(status: ProfilesStatus.ready));
    } on StorageException catch (error, stackTrace) {
      _logger.error(
        _tag,
        'Could not activate ${key.albumLabel}',
        error: error,
        stackTrace: stackTrace,
      );
      emit(state.copyWith(status: ProfilesStatus.activationFailed));
    }
  }

  /// The app's language changed: Default's name follows it, and the
  /// repository does not announce that on its own.
  void localeChanged() => emit(
    state.copyWith(profiles: _profiles.profiles, active: _profiles.active),
  );

  void _snapshotChanged(ProfilesSnapshot snapshot) {
    _followCounts(snapshot.profiles);
    emit(
      ProfilesState(
        profiles: snapshot.profiles,
        active: snapshot.active,
        clipCounts: <ProfileKey, int>{
          for (final MapEntry<ProfileKey, int> count
              in state.clipCounts.entries)
            if (_counts.containsKey(count.key)) count.key: count.value,
        },
      ),
    );
  }

  /// Follows the clip count of every profile in [profiles], and stops
  /// following the others.
  void _followCounts(List<Profile> profiles) {
    final Set<ProfileKey> listed = <ProfileKey>{
      for (final Profile profile in profiles) profile.key,
    };
    for (final ProfileKey gone in _counts.keys.toList()) {
      if (!listed.contains(gone)) unawaited(_counts.remove(gone)!.cancel());
    }
    for (final ProfileKey key in listed) {
      _counts[key] ??= _clips
          .watch(key)
          .listen(
            (ClipIndex index) => _countChanged(key, index.clipCount),
            onError: (Object error, StackTrace stackTrace) => _logger.warning(
              _tag,
              'Could not count the clips of ${key.albumLabel}',
              error: error,
              stackTrace: stackTrace,
            ),
          );
    }
  }

  void _countChanged(ProfileKey key, int count) => emit(
    state.copyWith(
      clipCounts: <ProfileKey, int>{...state.clipCounts, key: count},
    ),
  );

  @override
  Future<void> close() async {
    await _snapshots.cancel();
    for (final StreamSubscription<ClipIndex> count in _counts.values) {
      await count.cancel();
    }
    _counts.clear();
    return super.close();
  }
}
