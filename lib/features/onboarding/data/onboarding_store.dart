import 'dart:io';

import 'package:one_second_diary/core/logging/app_logger.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/core/storage/legacy_prefs_mirror.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/core/storage/pref_key.dart';
import 'package:one_second_diary/core/storage/pref_keys.dart';
import 'package:one_second_diary/core/storage/prefs_store.dart';
import 'package:one_second_diary/features/clips/domain/clip_meta.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/profiles/data/profiles_repository.dart';
import 'package:one_second_diary/features/profiles/domain/profile_clip_facts.dart';
import 'package:one_second_diary/features/profiles/domain/profile_format_inference.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';

/// Whether the user finished onboarding, and finishing it safely.
///
/// Onboarding is done if and only if `showIntro == false`. [complete]
/// writes everything else first and `showIntro` last, and every write is
/// idempotent, so a process killed at any point simply shows onboarding
/// again, and the retry completes.
///
/// A plain class (not final), so cubit tests can fake it.
class OnboardingStore {
  /// [clipFacts] reads Default's newest clips on a reinstall, so the canvas and format they were made for are kept;
  /// without it such a reinstall reads as landscape and legacy.
  OnboardingStore({
    required this._prefs,
    required this._profiles,
    required this._mirror,
    required this._paths,
    required this._logger,
    this._clipFacts,
  });

  final PrefsStore _prefs;
  final ProfilesRepository _profiles;
  final LegacyPrefsMirror _mirror;
  final AppPaths _paths;
  final AppLogger _logger;
  final ProfileClipFacts? _clipFacts;

  /// The format Default's clips on disk were made for, found with the
  /// canvas by [fixedDefaultOrientation]; null when nothing fixed it.
  ClipFormat? _inferredFormat;

  static const String _tag = 'ONBOARDING';

  /// Top-level folders of the videos folder that hold other profiles'
  /// clips and the movies, not Default's clips; skipped only to save the
  /// walk, since `ClipRef` already refuses their files.
  static const Set<String> _otherTrees = <String>{
    PathNames.profilesFolder,
    PathNames.moviesFolder,
  };

  static final PrefKey<String> _defaultOrientationKey = PrefKeys.orientation(
    ProfileKey.defaultProfile,
  );

  /// True if and only if `showIntro` is exactly `false`: absent and `true`
  /// both mean "show onboarding", so an existing user is never onboarded
  /// again.
  bool get isOnboarded => _prefs.read(PrefKeys.showIntro) == false;

  /// The Default profile's canvas when it is already decided, so the
  /// orientation step must not ask; null when it asks.
  ///
  /// - An `orientation_` stored by an onboarding that was killed before
  ///   `showIntro` is that choice: it is written once and never changed.
  /// - Otherwise, Default clips already on disk (a reinstall, or cleared app
  ///   data) fix the canvas: the one their newest clips were made for
  ///   (`ProfileFormatInference`, with their format for
  ///   [fixedDefaultFormat]), or landscape when they cannot be read. Only
  ///   Default's clips count: leftover movies and other profiles' clips
  ///   don't decide Default's canvas.
  /// - Without the storage permission ([canReadGallery] false), the videos
  ///   folder merely existing means a reinstall, so landscape. The folder
  ///   can't be looked into then: on scoped storage (Android 11+, which
  ///   every reinstall gets) the listing does not fail, it just shows none
  ///   of the files an earlier install made.
  ///
  /// Pass [canReadGallery] true when the media-library permission is granted
  /// (`PermissionFeature.mediaLibrary` checks as granted; always on iOS).
  /// Call it before anything creates the videos folder
  /// (`AppPaths.createDirectories`, the Default profile's first clip): on a
  /// fresh install the folder must not exist yet.
  ///
  /// Walks the videos folder with async IO and stops at the first clip.
  Future<VideoOrientation?> fixedDefaultOrientation({
    required bool canReadGallery,
  }) async {
    if (_prefs.contains(_defaultOrientationKey)) {
      return VideoOrientation.parse(_prefs.read(_defaultOrientationKey));
    }
    if (!canReadGallery) {
      return await _diaryFolderExists() ? VideoOrientation.landscape : null;
    }
    if (!await _hasDefaultClips()) return null;
    return _inferDefaultCanvas();
  }

  /// The format of Default's clips on disk, when [fixedDefaultOrientation]
  /// found them and could read them; null otherwise (the phone check then
  /// chooses).
  ClipFormat? get fixedDefaultFormat => _inferredFormat;

  /// The canvas Default's newest clips were made for, remembering their
  /// format; landscape when they cannot be read.
  Future<VideoOrientation> _inferDefaultCanvas() async {
    final ProfileClipFacts? clipFacts = _clipFacts;
    if (clipFacts == null) return VideoOrientation.landscape;
    final List<ClipMeta> facts = await clipFacts.newestOf(
      ProfileKey.defaultProfile,
    );
    if (facts.isEmpty) return VideoOrientation.landscape;
    final (:VideoOrientation orientation, :ClipFormat format) =
        ProfileFormatInference.infer(facts);
    _inferredFormat = format;
    _logger.info(
      _tag,
      'Default clips on the phone are ${orientation.name} $format',
    );
    return orientation;
  }

  /// Finishes onboarding with [defaultOrientation] as the Default profile's
  /// canvas (pass [fixedDefaultOrientation] when it is not null) and
  /// [defaultFormat] as its clip format (the phone check's choice; on a
  /// reinstall [fixedDefaultFormat] wins over it, logged when they differ;
  /// neither given, the format stays absent and reads as legacy).
  ///
  /// In order, each write skipped when already done:
  /// 1. the Default profile: `profiles = ['Default']` unless a non-empty list
  ///    is stored (never overwrite one: it may name other profiles);
  /// 2. its `orientation_`, unless stored: a stored canvas is kept, even if
  ///    [defaultOrientation] differs (logged as a warning). Steps 1 and 2
  ///    are `ProfilesRepository.ensureDefaultProfile`, the only writer of
  ///    the profile keys;
  /// 3. its `clipFormat_`, unless stored (`ProfilesRepository.ensureFormat`,
  ///    written once);
  /// 4. the first-run `videoCount = 0` and `movieCount = 1`, which an older
  ///    app version reading these prefs requires (`LegacyPrefsMirror`);
  /// 5. `showIntro = false`, last.
  ///
  /// Throws a `StorageException` when the platform refuses a write; the user
  /// is then not onboarded and calling it again is safe.
  Future<void> complete({
    required VideoOrientation defaultOrientation,
    ClipFormat? defaultFormat,
  }) async {
    final VideoOrientation kept = await _profiles.ensureDefaultProfile(
      defaultOrientation,
    );
    if (kept != defaultOrientation) {
      _logger.warning(
        _tag,
        'Asked for ${defaultOrientation.name}, but the Default profile is '
        'already ${kept.name}; keeping it',
      );
    }
    // A reinstall's clips decide the format, as they decide the canvas:
    // the phone check's pick serves the next profile then.
    final ClipFormat? inferred = _inferredFormat;
    final ClipFormat? format = inferred ?? defaultFormat;
    if (inferred != null &&
        defaultFormat != null &&
        inferred.withOrientation(kept) != defaultFormat.withOrientation(kept)) {
      _logger.warning(
        _tag,
        'Asked for $defaultFormat, but the Default clips on the phone are '
        '$inferred; keeping that',
      );
    }
    if (format != null) {
      await _profiles.ensureFormat(ProfileKey.defaultProfile, format);
    }
    await _mirror.writeFirstRunCounters();
    await _prefs.write(PrefKeys.showIntro, false);
    _logger.info(_tag, 'Completed; Default profile is ${kept.name}');
  }

  /// Whether the videos folder exists, for when it can't be read. Logged
  /// when it does, so a bug report shows why the orientation step was
  /// skipped.
  Future<bool> _diaryFolderExists() async {
    final bool exists = await Directory(_paths.videos).exists();
    if (exists) {
      _logger.warning(
        _tag,
        'No storage permission to look for clips in ${_paths.videos}; '
        'the folder exists, so assuming a reinstall (landscape)',
      );
    }
    return exists;
  }

  /// Whether the Default profile has a clip on disk: a file named like a
  /// clip anywhere under the videos folder (user-made sub-folders
  /// included), except in the top-level `Profiles/` and `Movies/` folders.
  Future<bool> _hasDefaultClips() async {
    final String root = _paths.videos;
    final List<Directory> folders = <Directory>[Directory(root)];
    while (folders.isNotEmpty) {
      final Directory folder = folders.removeLast();
      final bool atRoot = folder.path == root;
      try {
        await for (final FileSystemEntity entity in folder.list(
          followLinks: false,
        )) {
          if (entity is File &&
              ClipRef.tryParse(
                    profile: ProfileKey.defaultProfile,
                    relPath: _paths.relativeToVideos(entity.path),
                  ) !=
                  null) {
            return true;
          }
          final String name = PathNames.fileNameOf(entity.path);
          if (entity is Directory && !(atRoot && _otherTrees.contains(name))) {
            folders.add(entity);
          }
        }
      } on PathNotFoundException {
        // No diary folder: a fresh install. A sub-folder that vanished
        // mid-walk holds nothing either.
      } on FileSystemException catch (error, stackTrace) {
        _logger.warning(
          _tag,
          'Cannot read ${folder.path} to look for existing clips',
          error: error,
          stackTrace: stackTrace,
        );
        // The diary folder exists but its listing fails (Android 10 and
        // below answers EACCES): assume clips, so their canvas stays
        // landscape. An unreadable sub-folder is skipped.
        if (atRoot) return true;
      }
    }
    return false;
  }
}
