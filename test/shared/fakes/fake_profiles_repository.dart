import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_change.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/domain/profiles_snapshot.dart';

/// A profile for tests: [key] (Default when omitted) with [orientation]
/// and, when given, its write-once [format] (legacy on [orientation]
/// otherwise, as the real repository reads a profile with none stored).
Profile testProfile({
  ProfileKey key = ProfileKey.defaultProfile,
  VideoOrientation orientation = VideoOrientation.landscape,
  ClipFormat? format,
}) => Profile(
  key: key,
  displayName: key.isDefault ? 'Default' : key.value,
  orientation: orientation,
  avatarRelPath: null,
  format: format,
);

/// A [ProfilesRepository] over an in-memory list, which the test changes
/// with [activate], [addProfile] and [removeProfile]; each announces itself
/// like the real repository: a [ProfileChange] on [changes], then the new
/// snapshot on [watch].
class FakeProfilesRepository extends Fake implements ProfilesRepository {
  FakeProfilesRepository({
    List<Profile>? profiles,
    this._active = ProfileKey.defaultProfile,
  }) : _profiles = profiles ?? <Profile>[testProfile()];

  final List<Profile> _profiles;
  ProfileKey _active;

  final StreamController<ProfilesSnapshot> _snapshots =
      StreamController<ProfilesSnapshot>.broadcast();
  final StreamController<ProfileChange> _changes =
      StreamController<ProfileChange>.broadcast();

  @override
  List<Profile> get profiles => List<Profile>.unmodifiable(_profiles);

  @override
  Profile get active =>
      _profiles.firstWhere((Profile profile) => profile.key == _active);

  /// As the real repository answers: the profile's format, or the active
  /// profile's for a key that is not a profile.
  @override
  ClipFormat formatOf(ProfileKey key) {
    for (final Profile profile in _profiles) {
      if (profile.key == key) return profile.format;
    }
    return active.format;
  }

  ProfilesSnapshot get _snapshot =>
      ProfilesSnapshot(profiles: profiles, active: active);

  @override
  Stream<ProfilesSnapshot> watch() => Stream<ProfilesSnapshot>.multi((
    MultiStreamController<ProfilesSnapshot> listener,
  ) {
    listener.add(_snapshot);
    final StreamSubscription<ProfilesSnapshot> changes = _snapshots.stream
        .listen(listener.add);
    listener.onCancel = changes.cancel;
  });

  @override
  Stream<ProfileChange> get changes => _changes.stream;

  @override
  Future<void> activate(ProfileKey key) async {
    _active = key;
    _snapshots.add(_snapshot);
  }

  /// A profile created (or found on the phone and added back).
  void addProfile(Profile profile) {
    _profiles.add(profile);
    _changes.add(ProfileAdded(profile.key));
    _snapshots.add(_snapshot);
  }

  void removeProfile(ProfileKey key) {
    _profiles.removeWhere((Profile profile) => profile.key == key);
    _changes.add(ProfileRemoved(key));
    _snapshots.add(_snapshot);
  }

  Future<void> close() async {
    await _snapshots.close();
    await _changes.close();
  }
}
