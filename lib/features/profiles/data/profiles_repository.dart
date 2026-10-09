import 'dart:async';
import 'dart:io';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/platform/clock.dart';
import 'package:one_second_diary/core/platform/media_store_gateway.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/pref_key.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/profiles/data/profile_folders.dart';
import 'package:one_second_diary/features/profiles/data/profile_meta_store.dart';
import 'package:one_second_diary/features/profiles/data/profile_photos.dart';
import 'package:one_second_diary/features/profiles/domain/profile.dart';
import 'package:one_second_diary/features/profiles/domain/profile_change.dart';
import 'package:one_second_diary/features/profiles/domain/profile_clip_facts.dart';
import 'package:one_second_diary/features/profiles/domain/profile_deletion.dart';
import 'package:one_second_diary/features/profiles/domain/profile_folder_keys.dart';
import 'package:one_second_diary/features/profiles/domain/profile_format_inference.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:one_second_diary/features/profiles/domain/profile_name_error.dart';
import 'package:one_second_diary/features/profiles/domain/profile_name_validator.dart';
import 'package:one_second_diary/features/profiles/domain/profiles_snapshot.dart';

/// The diary's profiles, and the ONLY writer of the preference keys that
/// hold them:
/// - `profiles`: labels in creation order. Index 0 is Default, whatever its
///   label; every other entry is its folder key under `Profiles/`. Absent or
///   empty reads as `['Default']` and is never written by reading.
/// - `selectedProfileIndex`: an index into that list; outside it means Default.
/// - `orientation_<key>`: the canvas, written once at creation; missing or
///   unknown means landscape. Still written for older installs.
/// - `clipFormat_<key>`: the clip format, written once beside the canvas;
///   missing or unknown means `ClipFormat.legacy` on that canvas.
/// - `profileMeta`: a display name that differs from the folder key, and the
///   photo. The folder key never changes.
///
/// Profiles are compared by key, never by label: a later entry literally named
/// "Default" is a normal profile in `Profiles/Default/`, shown as "Default (2)".
///
/// A plain class (not final), so cubit tests can fake it.
class ProfilesRepository {
  /// [defaultLabel] gives the Default profile's label in the current
  /// language, read each time it is needed. [clipFacts] reads the newest
  /// clips of a folder found on the phone, so [addFound] can tell its
  /// canvas and format; without it a found folder reads as landscape and
  /// legacy.
  ProfilesRepository({
    required this._prefs,
    required AppPaths paths,
    required MediaStoreGateway mediaStore,
    required Clock clock,
    required this._logger,
    required this._defaultLabel,
    this._clipFacts,
  }) : _paths = paths,
       _meta = ProfileMetaStore(prefs: _prefs, logger: _logger),
       _folders = ProfileFolders(
         paths: paths,
         mediaStore: mediaStore,
         logger: _logger,
       ),
       _photos = ProfilePhotos(paths: paths, clock: clock, logger: _logger);

  final PrefsStore _prefs;
  final AppPaths _paths;
  final AppLogger _logger;
  final String Function() _defaultLabel;
  final ProfileClipFacts? _clipFacts;
  final ProfileMetaStore _meta;
  final ProfileFolders _folders;
  final ProfilePhotos _photos;

  static const String _tag = 'PROFILES';

  // App-scoped, never closed.
  final StreamController<ProfilesSnapshot> _snapshots =
      StreamController<ProfilesSnapshot>.broadcast();
  final StreamController<ProfileChange> _changes =
      StreamController<ProfileChange>.broadcast();

  /// Every profile in list order, Default first, each key once.
  List<Profile> get profiles {
    final Map<ProfileKey, ProfileMeta> meta = _meta.read();
    return <Profile>[for (final ProfileKey key in _keys) _profile(key, meta)];
  }

  /// The profile new clips are recorded into.
  Profile get active => _profile(_activeKey, _meta.read());

  /// The write-once format of [key]'s clips (one source of truth
  /// for every reader): the stored canonical format on the profile's
  /// canvas, or the legacy format there. A key that is not a profile reads
  /// as the active profile's (a profile deleted while a page was open).
  ClipFormat formatOf(ProfileKey key) {
    for (final Profile profile in profiles) {
      if (profile.key == key) return profile.format;
    }
    return active.format;
  }

  /// The current [ProfilesSnapshot] on listen, then a new one after each
  /// change made through this repository.
  Stream<ProfilesSnapshot> watch() => Stream<ProfilesSnapshot>.multi((
    MultiStreamController<ProfilesSnapshot> listener,
  ) {
    listener.add(_snapshot);
    final StreamSubscription<ProfilesSnapshot> changes = _snapshots.stream
        .listen(listener.add);
    listener.onCancel = changes.cancel;
  });

  /// Each profile added or removed through this repository, as it happens,
  /// for the owners of per-profile data (the clip index).
  Stream<ProfileChange> get changes => _changes.stream;

  /// Makes [key] the active profile. Throws an [ArgumentError] when it is
  /// not a profile.
  Future<void> activate(ProfileKey key) async {
    await _prefs.write(PrefKeys.selectedProfileIndex, _indexOf(key));
    _announce();
  }

  /// Makes sure the Default profile exists with a canvas, and returns it.
  /// Each write happens only when needed, so a retry after a kill is safe: the
  /// `profiles` list is kept if non-empty, a stored canvas is kept.
  Future<VideoOrientation> ensureDefaultProfile(
    VideoOrientation orientation,
  ) async {
    if (!_prefs.contains(PrefKeys.profiles) ||
        _prefs.read(PrefKeys.profiles).isEmpty) {
      await _prefs.write(PrefKeys.profiles, PrefKeys.profiles.defaultValue);
    }
    final PrefKey<String> canvas = PrefKeys.orientation(
      ProfileKey.defaultProfile,
    );
    if (_prefs.contains(canvas)) {
      return VideoOrientation.parse(_prefs.read(canvas));
    }
    await _prefs.write(canvas, orientation.name);
    return orientation;
  }

  /// Gives [key] the format [format] unless one is stored (write-once), and
  /// returns the format the profile has; safe to retry after a kill. [format]'s
  /// orientation is ignored: the stored canvas is the profile's.
  /// Throws an [ArgumentError] when [key] is not a profile.
  Future<ClipFormat> ensureFormat(ProfileKey key, ClipFormat format) async {
    _requireProfile(key);
    final VideoOrientation orientation = VideoOrientation.parse(
      _prefs.read(PrefKeys.orientation(key)),
    );
    final ClipFormat? stored = _storedFormat(key, orientation);
    if (stored != null) return stored;
    final ClipFormat wanted = format.withOrientation(orientation);
    await _prefs.write(PrefKeys.clipFormat(key), wanted.toString());
    _logger.info(_tag, 'Profile "${key.value}" records $wanted');
    _announce();
    return wanted;
  }

  /// Why [displayName] can't name a new profile, or null when it can (see
  /// `ProfileNameValidator`): compared with the names every profile shows
  /// now, Default's included.
  ProfileNameError? validateNewName(String displayName) =>
      _validate(displayName, profiles);

  /// Why [key] can't be renamed [displayName], or null when it can: the
  /// rules of [validateNewName], against the OTHER profiles' names.
  /// Default may take its own label back. Throws an [ArgumentError] when
  /// [key] is not a profile.
  ProfileNameError? validateRename({
    required ProfileKey key,
    required String displayName,
  }) {
    _requireProfile(key);
    if (key.isDefault && _isDefaultLabel(displayName)) return null;
    return _validate(
      displayName,
      profiles.where((Profile profile) => profile.key != key),
    );
  }

  /// Creates a profile named [displayName] with the canvas [orientation] and
  /// the clip format [format] (legacy on [orientation] when left out), and makes
  /// it active.
  ///
  /// The folder key comes from the display name (`ProfileFolderKeys`) and is
  /// never one in use, including a folder already on the phone (its old clips
  /// would show under the new canvas). Writes go in an order that never lists a
  /// profile without its canvas.
  ///
  /// Throws an [ArgumentError] for a name [validateNewName] rejects, before
  /// touching anything, and a [StorageException] when a write fails.
  Future<Profile> create({
    required String displayName,
    required VideoOrientation orientation,
    ClipFormat? format,
  }) async {
    _requireValid(displayName, validateNewName(displayName));
    final String name = displayName.trim();
    final ProfileKey key = await _freeKeyFor(name);
    final ClipFormat clipFormat =
        format?.withOrientation(orientation) ?? ClipFormat.legacy(orientation);
    await _createFolder(key);
    await _prefs.write(PrefKeys.orientation(key), orientation.name);
    await _prefs.write(PrefKeys.clipFormat(key), clipFormat.toString());
    if (name != key.value) {
      await _meta.put(key: key, meta: (displayName: name, avatarRelPath: null));
    }
    await _prefs.write(PrefKeys.profiles, <String>[..._labels, key.value]);
    await _prefs.write(PrefKeys.selectedProfileIndex, _indexOf(key));
    _logger.info(
      _tag,
      'Created profile "${key.value}" (${orientation.name}, $clipFormat)',
    );
    _announce(ProfileAdded(key));
    return active;
  }

  /// Shows [key] as [displayName]. Only the name changes: the folder key never
  /// does (a folder rename fails on Android for clips a previous install made).
  /// Throws an [ArgumentError] when [key] is not a profile or [displayName] is
  /// not valid for it ([validateRename]).
  Future<void> rename({
    required ProfileKey key,
    required String displayName,
  }) async {
    _requireValid(
      displayName,
      validateRename(key: key, displayName: displayName),
    );
    final String name = displayName.trim();
    // Default's own label (in any language) is no custom name: it follows
    // the language. A name equal to the key needs no entry either.
    final bool plain = key.isDefault
        ? _isDefaultLabel(name)
        : name == key.value;
    await _meta.put(
      key: key,
      meta: (
        displayName: plain ? null : name,
        avatarRelPath: _meta.read()[key]?.avatarRelPath,
      ),
    );
    _announce();
  }

  /// Uses a copy of the image at [imagePath] as [key]'s photo, in private
  /// storage; the previous photo is deleted once the new one is stored.
  /// Throws an [ArgumentError] when [key] is not a profile, and a
  /// [StorageException] when the copy fails (the current photo is kept).
  Future<void> setPhoto({
    required ProfileKey key,
    required String imagePath,
  }) async {
    _requireProfile(key);
    final ProfileMeta? meta = _meta.read()[key];
    final String photo = await _photos.store(key: key, imagePath: imagePath);
    try {
      await _meta.put(
        key: key,
        meta: (displayName: meta?.displayName, avatarRelPath: photo),
      );
    } on Object {
      await _photos.delete(photo);
      rethrow;
    }
    await _photos.delete(meta?.avatarRelPath);
    _announce();
  }

  /// Removes [key]'s photo (the display name stays). Nothing happens without
  /// one. Throws an [ArgumentError] when [key] is not a profile, and a
  /// [StorageException] when the record can't be stored (the photo is kept).
  Future<void> removePhoto(ProfileKey key) async {
    _requireProfile(key);
    final ProfileMeta? meta = _meta.read()[key];
    final String? photo = meta?.avatarRelPath;
    if (meta == null || photo == null) return;
    await _meta.put(
      key: key,
      meta: (displayName: meta.displayName, avatarRelPath: null),
    );
    await _photos.delete(photo);
    _logger.info(_tag, 'Removed the photo of profile "${key.albumLabel}"');
    _announce();
  }

  /// Deletes the profile [key] with every file in its folder.
  ///
  /// Each file goes through the media store with its own album, so the gallery
  /// forgets it too. A file the media store refuses (Android asks for consent
  /// for clips a previous install made) stays and is listed in the result; the
  /// profile is removed either way, and its folder then shows up in
  /// [foundOnThisPhone]. The canvas and format go only when no file was kept, so
  /// [addFound] can bring a portrait profile back portrait.
  ///
  /// Throws an [ArgumentError], before touching anything, for Default, for a key
  /// that is not a listed profile, and for a key whose folder would not be its
  /// own inside `Profiles/` (older installs accepted any name: a `.` or `..`
  /// segment, an empty one). Throws a [StorageException] when the folder can't
  /// be listed; the profile is then kept.
  Future<ProfileDeletion> delete(ProfileKey key) async {
    if (key.isDefault) {
      throw ArgumentError.value(key.value, 'key', 'Default cannot be deleted');
    }
    _requireProfile(key);
    if (key.value
        .split('/')
        .any((String part) => part.isEmpty || part == '.' || part == '..')) {
      throw ArgumentError.value(key.value, 'key', 'is not inside Profiles/');
    }
    final ProfileKey active = _activeKey;
    final List<String> kept = await _folders.deleteFiles(key);
    if (kept.isNotEmpty) {
      _logger.warning(
        _tag,
        'Deleting profile "${key.value}" kept ${kept.length} file(s) the '
        'media store refused to delete: ${kept.join(', ')}',
      );
    }
    final List<String> labels = _labels;
    await _prefs.write(PrefKeys.profiles, <String>[
      labels.first,
      for (int i = 1; i < labels.length; i++)
        if (ProfileKey.fromLegacyIndex(i, labels[i]) != key) labels[i],
    ]);
    await _prefs.write(
      PrefKeys.selectedProfileIndex,
      active == key ? 0 : _indexOf(active),
    );
    if (kept.isEmpty) {
      await _prefs.remove(PrefKeys.orientation(key));
      await _prefs.remove(PrefKeys.clipFormat(key));
      await _prefs.remove(PrefKeys.recordingLock(key));
    }
    final String? photo = _meta.read()[key]?.avatarRelPath;
    await _meta.put(key: key, meta: (displayName: null, avatarRelPath: null));
    await _photos.delete(photo);
    _logger.info(_tag, 'Deleted profile "${key.value}"');
    _announce(ProfileRemoved(key));
    return ProfileDeletion(keptFiles: kept);
  }

  /// Folders under `Profiles/` that hold clips but that no listed profile
  /// names, sorted: what a reinstall without restored preferences leaves. They
  /// are offered back, never registered silently ([addFound]). Names compare
  /// case-insensitively, as Android's shared storage does; the parent folder of
  /// a listed key with a `/` (`Mom` for `Mom/Dad`) is not offered.
  Future<List<ProfileKey>> foundOnThisPhone() async {
    final Set<String> listed = <String>{
      for (final ProfileKey key in _keys) key.value.toLowerCase(),
    };
    // A listed key with a "/" ("Mom/Dad") lives inside another folder
    // ("Mom"), whose clips are its own.
    bool holdsListed(String folder) =>
        listed.any((String key) => key.startsWith('${folder.toLowerCase()}/'));
    final List<String> folders = await _folders.names()
      ..sort();
    return <ProfileKey>[
      for (final String folder in folders)
        if (!listed.contains(folder.toLowerCase()) &&
            !holdsListed(folder) &&
            await _folders.holdsClip(ProfileKey(folder)))
          ProfileKey(folder),
    ];
  }

  /// Lists the existing folder `Profiles/<key>/` as a profile: appended, not
  /// activated. A key already listed, in any case, is left alone.
  ///
  /// Its canvas and format are the stored ones; without a stored canvas they are
  /// read off its newest clips (`ProfileFormatInference`) and written once. When
  /// the clips can't be read, nothing is written and it reads as landscape and
  /// legacy.
  Future<void> addFound(ProfileKey key) async {
    if (key.isDefault) {
      throw ArgumentError.value(key.value, 'key', 'Default is always listed');
    }
    final String folded = key.value.toLowerCase();
    if (_keys.any((ProfileKey k) => k.value.toLowerCase() == folded)) return;
    await _inferCanvas(key);
    await _prefs.write(PrefKeys.profiles, <String>[..._labels, key.value]);
    _logger.info(_tag, 'Added the folder "${key.value}" as a profile');
    _announce(ProfileAdded(key));
  }

  /// Writes the canvas and format [key]'s newest clips were made for,
  /// when no canvas is stored and the clips can be read.
  Future<void> _inferCanvas(ProfileKey key) async {
    final ProfileClipFacts? clipFacts = _clipFacts;
    if (clipFacts == null || _prefs.contains(PrefKeys.orientation(key))) {
      return;
    }
    final List<ClipMeta> facts = await clipFacts.newestOf(key);
    if (facts.isEmpty) return;
    final (:VideoOrientation orientation, :ClipFormat format) =
        ProfileFormatInference.infer(facts);
    await _prefs.write(PrefKeys.orientation(key), orientation.name);
    await _prefs.write(PrefKeys.clipFormat(key), format.toString());
    _logger.info(
      _tag,
      'The clips of "${key.value}" are ${orientation.name} $format',
    );
  }

  /// The stored `profiles` list, with `['Default']` for an absent or empty
  /// one, so index 0 is always Default.
  List<String> get _labels {
    final List<String> stored = _prefs.read(PrefKeys.profiles);
    return stored.isEmpty ? PrefKeys.profiles.defaultValue : stored;
  }

  /// The profiles' keys in list order: Default, then each other entry once
  /// (an empty entry after index 0 would alias Default and is skipped).
  List<ProfileKey> get _keys {
    final List<String> labels = _labels;
    final Set<ProfileKey> keys = <ProfileKey>{ProfileKey.defaultProfile};
    for (int i = 1; i < labels.length; i++) {
      keys.add(ProfileKey.fromLegacyIndex(i, labels[i]));
    }
    return keys.toList();
  }

  /// The profile `selectedProfileIndex` points at in the stored list, or
  /// Default when it points outside it.
  ProfileKey get _activeKey {
    final List<String> labels = _labels;
    final int index = _prefs.read(PrefKeys.selectedProfileIndex);
    return index >= 0 && index < labels.length
        ? ProfileKey.fromLegacyIndex(index, labels[index])
        : ProfileKey.defaultProfile;
  }

  /// The first index of [key] in the stored list (0 for Default).
  int _indexOf(ProfileKey key) {
    if (key.isDefault) return 0;
    final List<String> labels = _labels;
    for (int i = 1; i < labels.length; i++) {
      if (ProfileKey.fromLegacyIndex(i, labels[i]) == key) return i;
    }
    throw ArgumentError.value(key.value, 'key', 'is not a profile');
  }

  void _requireProfile(ProfileKey key) {
    if (!_keys.contains(key)) {
      throw ArgumentError.value(key.value, 'key', 'is not a profile');
    }
  }

  Profile _profile(ProfileKey key, Map<ProfileKey, ProfileMeta> allMeta) {
    final ProfileMeta? meta = allMeta[key];
    final VideoOrientation orientation = VideoOrientation.parse(
      _prefs.read(PrefKeys.orientation(key)),
    );
    return Profile(
      key: key,
      displayName: meta?.displayName ?? _plainName(key),
      orientation: orientation,
      avatarRelPath: meta?.avatarRelPath,
      format: _storedFormat(key, orientation),
    );
  }

  /// The format stored for [key] on [orientation]; null when none or not
  /// a canonical one (never a guess: it then reads as legacy).
  ClipFormat? _storedFormat(ProfileKey key, VideoOrientation orientation) {
    final PrefKey<String> stored = PrefKeys.clipFormat(key);
    if (!_prefs.contains(stored)) return null;
    return ClipFormat.parse(_prefs.read(stored), orientation);
  }

  /// The name of a profile without a display name of its own: Default's
  /// label, or the folder key, with " (2)" when the key reads as Default.
  String _plainName(ProfileKey key) {
    if (key.isDefault) return _defaultLabel();
    return _isDefaultLabel(key.value) ? '${key.value} (2)' : key.value;
  }

  bool _isDefaultLabel(String name) => ProfileNameValidator.isReserved(
    name,
    localizedDefaultLabel: _defaultLabel(),
  );

  ProfileNameError? _validate(String displayName, Iterable<Profile> others) =>
      ProfileNameValidator.validate(
        displayName,
        existingNames: others.map((Profile profile) => profile.displayName),
        localizedDefaultLabel: _defaultLabel(),
      );

  static void _requireValid(String displayName, ProfileNameError? error) {
    if (error != null) {
      throw ArgumentError.value(displayName, 'displayName', error.name);
    }
  }

  /// A folder key for [name] that no listed profile, folder on the phone,
  /// stored canvas or stored format uses.
  Future<ProfileKey> _freeKeyFor(String name) async {
    final Set<String> taken = <String>{
      for (final ProfileKey key in _keys) key.value.toLowerCase(),
      for (final String folder in await _folders.names()) folder.toLowerCase(),
    };
    return ProfileFolderKeys.forDisplayName(
      name,
      isTaken: (String candidate) =>
          taken.contains(candidate.toLowerCase()) ||
          _prefs.contains(PrefKeys.orientation(ProfileKey(candidate))) ||
          _prefs.contains(PrefKeys.clipFormat(ProfileKey(candidate))),
    );
  }

  Future<void> _createFolder(ProfileKey key) async {
    final String folder = _paths.profileVideos(key);
    try {
      await Directory(folder).create(recursive: true);
    } on FileSystemException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StorageException('Cannot create $folder', cause: error),
        stackTrace,
      );
    }
  }

  ProfilesSnapshot get _snapshot =>
      ProfilesSnapshot(profiles: profiles, active: active);

  /// Tells listeners about a change: [change] on [changes], if any, and
  /// the resulting state on [watch].
  void _announce([ProfileChange? change]) {
    if (change != null) _changes.add(change);
    _snapshots.add(_snapshot);
  }
}
