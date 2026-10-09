import 'dart:io';

import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/storage/path_names.dart';
import 'package:one_second_diary/features/profiles/domain/profile_key.dart';
import 'package:path_provider/path_provider.dart';

/// Owns every directory the app reads or writes.
///
/// Paths are resolved once per launch ([resolve]) and kept in memory. They are
/// never read back from storage: on iOS the application container is rooted at
/// a UUID that changes on every reinstall, OS migration and backup restore, so
/// a persisted absolute path silently stops resolving. Anything persisted
/// stores paths relative to [videos] ([relativeToVideos]).
///
/// The resolved folders are also written to the write-only preferences
/// `internalDirectoryPath`, `appPath` and `moviesPath` for older builds; that
/// is the job of the bootstrap (see `PrefKeys`), not of this class.
///
/// Public folders ([videos], [movies], [profileVideos]) end with `/`.
/// Private and purgeable folders have no trailing slash, like
/// `path_provider` returns them.
final class AppPaths {
  /// Builds the layout from already-resolved absolute folders: [internal]
  /// (app private), [videos] (the Default profile's clip folder), and the
  /// OS [temporary] and [cache] folders. Throws an [ArgumentError] for an
  /// empty or relative folder.
  factory AppPaths({
    required String internal,
    required String videos,
    required String temporary,
    required String cache,
  }) {
    _requireAbsolute(internal, 'internal');
    _requireAbsolute(videos, 'videos');
    _requireAbsolute(temporary, 'temporary');
    _requireAbsolute(cache, 'cache');
    return AppPaths._(
      internal: internal,
      videos: withTrailingSlash(videos),
      temporaryDir: temporary,
      cacheDir: cache,
    );
  }

  /// The layout for the platform, from the folders `path_provider` reports
  /// (the pure part of [resolve]).
  ///
  /// | | Android | iOS |
  /// |---|---|---|
  /// | videos   | `<storage root>/DCIM/OneSecondDiary/` | `<Documents>/OneSecondDiary/` |
  /// | internal | `<Documents>` | `<Application Support>` |
  ///
  /// On iOS the videos live under Documents on purpose: with
  /// `UIFileSharingEnabled` it is the only place the user can browse from the
  /// Files app. The Android storage root is the part of [externalStorage]
  /// before its `Android` segment (see [storageRootOf]); when there is none
  /// this throws a [StorageException] instead of quietly writing the diary
  /// into private storage, which an uninstall would delete.
  factory AppPaths.fromPlatform({
    required bool isIOS,
    required String documents,
    required String applicationSupport,
    required String? externalStorage,
    required String temporary,
    required String cache,
  }) {
    if (isIOS) {
      return AppPaths(
        internal: applicationSupport,
        videos: '$documents/$folderName',
        temporary: temporary,
        cache: cache,
      );
    }
    final String root = externalStorage == null
        ? ''
        : storageRootOf(externalStorage, fallback: '');
    if (root.isEmpty) {
      throw StorageException(
        'No Android storage root in external storage "$externalStorage"',
      );
    }
    return AppPaths(
      internal: documents,
      videos: '$root/DCIM/$folderName',
      temporary: temporary,
      cache: cache,
    );
  }

  /// A layout under [root] for tests: `internal/`, `media/OneSecondDiary/`
  /// (as if `media/` were DCIM) and `cache/`, which is both the temporary
  /// and the cache folder, as on devices. Creates nothing.
  factory AppPaths.forTest(Directory root) => AppPaths(
    internal: '${root.path}/internal',
    videos: '${root.path}/media/$folderName',
    temporary: '${root.path}/cache',
    cache: '${root.path}/cache',
  );

  AppPaths._({
    required this.internal,
    required this.videos,
    required this.temporaryDir,
    required this.cacheDir,
  });

  /// Resolves the layout for this launch from `path_provider`. Throws a
  /// [StorageException] on Android when there is no primary external storage
  /// (see [AppPaths.fromPlatform]), and when `path_provider` fails (the
  /// plugin errors as its cause).
  ///
  /// The five platform calls run at once: this is on the cold-start path
  /// before the first frame, where one round trip after another adds up.
  static Future<AppPaths> resolve() async {
    final bool isIOS = Platform.isIOS;
    final Directory documents;
    final Directory applicationSupport;
    final Directory? externalStorage;
    final Directory temporary;
    final Directory cache;
    try {
      (
        documents,
        applicationSupport,
        externalStorage,
        temporary,
        cache,
      ) = await (
        getApplicationDocumentsDirectory(),
        getApplicationSupportDirectory(),
        isIOS ? Future<Directory?>.value() : getExternalStorageDirectory(),
        getTemporaryDirectory(),
        getApplicationCacheDirectory(),
      ).wait;
    } on ParallelWaitError<Object?, Object?> catch (error, stackTrace) {
      Error.throwWithStackTrace(
        StorageException('Could not resolve the app folders', cause: error),
        stackTrace,
      );
    }
    return AppPaths.fromPlatform(
      isIOS: isIOS,
      documents: documents.path,
      applicationSupport: applicationSupport.path,
      externalStorage: externalStorage?.path,
      temporary: temporary.path,
      cache: cache.path,
    );
  }

  /// The app's public folder name, under DCIM (Android) or Documents (iOS).
  static const String folderName = 'OneSecondDiary';

  /// Where older installs put the videos on an Android device without a
  /// storage root: under the app's PRIVATE [documents] folder, invisible in
  /// the Gallery and deleted on uninstall. [AppPaths.fromPlatform] refuses
  /// that layout (it throws), so the error state uses this to tell the user
  /// where clips saved there are. Ends with `/`.
  static String legacyPrivateVideos({required String documents}) =>
      '$documents/DCIM/$folderName/';

  // Public folders: the Gallery on Android, the Files app on iOS.

  /// Folder holding the Default profile's clips. Always ends with `/`.
  final String videos;

  /// Folder holding every profile's movies. Always ends with `/`.
  String get movies => '$videos${PathNames.moviesFolder}/';

  /// Folder holding the clips of [profile]: [videos] for the Default profile,
  /// `<videos>Profiles/<key>/` otherwise. Always ends with `/`.
  String profileVideos(ProfileKey profile) => profile.isDefault
      ? videos
      : '$videos${PathNames.profilesFolder}/${profile.value}/';

  /// The originals folder, BESIDE the diary: the parent of [videos] plus
  /// `OneSecondDiary Originals/` (`DCIM/OneSecondDiary Originals/` on
  /// Android, Documents `/OneSecondDiary Originals/` on iOS), holding
  /// processed imports' originals and kept recordings under their
  /// diary-relative paths
  /// (`PathNames.originalsFolder`). Never inside [videos], so
  /// the clip scanner never sees it; created on first use, not at startup.
  /// Always ends with `/`.
  String get originals => '$_videosParent/${PathNames.originalsFolder}/';

  // Public folders of older installs (Android only).

  /// Where older Android installs kept the clips:
  /// `<storage root>/OneSecondDiary/`, beside DCIM rather than inside it.
  /// Only `LegacyFolderMigration` reads it. Ends with `/`.
  String get legacyAndroidVideos => '$_mediaRootParent/$folderName/';

  /// Where older Android installs kept the movies:
  /// `<storage root>/OSD-Movies/`. Ends with `/`.
  String get legacyAndroidMovies => '$_mediaRootParent/OSD-Movies/';

  /// The folder holding [videos] (DCIM on Android, Documents on iOS).
  String get _videosParent {
    final List<String> segments = videos.split('/')..removeLast();
    return segments.sublist(0, segments.length - 1).join('/');
  }

  /// The folder holding the media root (DCIM): [videos] without its last
  /// two segments.
  String get _mediaRootParent {
    final List<String> segments = videos.split('/')..removeLast();
    return segments.sublist(0, segments.length - 2).join('/');
  }

  // Private folders.

  /// App private folder (Documents on Android, Application Support on iOS).
  final String internal;

  /// Session log files (`yyyy-MM-dd_HH-mm-ss.txt`).
  String get logsDir => '$internal/Logs';

  /// The zipped [logsDir] attached to a bug report (outside [logsDir], so
  /// the zip never contains itself).
  String get logsZipPath => '$internal/logs.zip';

  /// Where the stamp fonts are copied for ffmpeg.
  String get fontsDir => internal;

  /// Sidecar indexes (clip metadata, movie titles). Paths inside them are
  /// always relative (see [relativeToVideos]).
  String get supportIndexDir => '$internal/index';

  /// Clips replaced or deleted by the app, kept until Undo expires.
  String get trashDir => '$internal/trash';

  String get avatarsDir => '$internal/avatars';

  // Purgeable folders: never backed up, and the OS may clear them.
  //
  // On Android and iOS [temporaryDir] and [cacheDir] are the SAME folder
  // (`path_provider` returns the cache folder for both). Never clean either
  // one wholesale: only ever delete inside a named sub-folder you own
  // ([scratchDir], [thumbsDir], [normalizedDir]) or files you created.

  /// The OS temporary folder (where camera and picker plugins put their
  /// outputs). Equal to [cacheDir] on devices.
  final String temporaryDir;

  /// Root of the media engine's per-job scratch folders.
  String get scratchDir => '$temporaryDir/scratch';

  /// The OS cache folder. Equal to [temporaryDir] on devices.
  final String cacheDir;

  String get thumbsDir => '$cacheDir/thumbs';

  /// The media engine's capped cache of normalised movie copies (clips
  /// re-encoded for a movie, reused by later movies while the cap holds
  /// them).
  String get normalizedDir => '$cacheDir/normalized';

  // Relative paths.

  /// [absolutePath] relative to [videos], e.g. `Profiles/Work/2024-01-05.mp4`.
  ///
  /// Persist this form, never the absolute path. Throws an [ArgumentError]
  /// when the path is not inside [videos].
  String relativeToVideos(String absolutePath) {
    final String relative = absolutePath.startsWith(videos)
        ? absolutePath.substring(videos.length)
        : '';
    if (!_isInside(relative)) {
      throw ArgumentError.value(
        absolutePath,
        'absolutePath',
        'is not inside $videos',
      );
    }
    return relative;
  }

  /// The absolute path of [relativePath] (a [relativeToVideos] result) for
  /// this launch. Throws an [ArgumentError] for an empty, absolute or
  /// `..`-escaping path.
  String absoluteFromVideos(String relativePath) {
    if (!_isInside(relativePath)) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'must be a path inside the videos folder',
      );
    }
    return '$videos$relativePath';
  }

  /// [absolutePath] relative to [internal], e.g. `avatars/default-1.jpg`.
  ///
  /// Persist this form for private files such as `Profile.avatarRelPath`:
  /// on iOS [internal] moves with the container UUID on every reinstall or
  /// restore. Throws an [ArgumentError] when the path is not inside
  /// [internal].
  String relativeToInternal(String absolutePath) {
    final String prefix = '$internal/';
    final String relative = absolutePath.startsWith(prefix)
        ? absolutePath.substring(prefix.length)
        : '';
    if (!_isInside(relative)) {
      throw ArgumentError.value(
        absolutePath,
        'absolutePath',
        'is not inside $internal',
      );
    }
    return relative;
  }

  /// The absolute path of [relativePath] (a [relativeToInternal] result)
  /// for this launch. Throws an [ArgumentError] for an empty, absolute or
  /// `..`-escaping path.
  String absoluteFromInternal(String relativePath) {
    if (!_isInside(relativePath)) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'must be a path inside the internal folder',
      );
    }
    return '$internal/$relativePath';
  }

  /// The gallery album holding [absoluteFilePath], relative to the platform
  /// media root (`DCIM/` on Android, `Documents/` on iOS):
  /// `OneSecondDiary`, `OneSecondDiary/Profiles/<key>`,
  /// `OneSecondDiary/Movies`, or a user-made sub-folder. Media store calls
  /// take it explicitly, per call. Throws an [ArgumentError] when the file is
  /// not inside [videos].
  String albumFor(String absoluteFilePath) {
    final String relative = relativeToVideos(absoluteFilePath);
    final int slash = relative.lastIndexOf('/');
    return slash < 0
        ? folderName
        : '$folderName/${relative.substring(0, slash)}';
  }

  /// Creates the folders the app assumes exist at startup: the logs, videos
  /// and movies folders. Profile, scratch, trash and cache folders are
  /// created by their owners right before each write.
  Future<void> createDirectories() async {
    await Directory(logsDir).create(recursive: true);
    await Directory(videos).create(recursive: true);
    await Directory(movies).create(recursive: true);
  }

  /// The pure part of the Android storage-root lookup: walks up from the app
  /// private external folder to the storage root, e.g.
  /// `/storage/emulated/0/Android/data/<package>/files` → `/storage/emulated/0`
  /// (`/storage/emulated/10` for a secondary user, `/storage/XXXX-XXXX` for a
  /// removable volume). Returns [fallback] when there is nothing before an
  /// `Android` segment.
  static String storageRootOf(String externalPath, {required String fallback}) {
    final List<String> folders = externalPath.split('/');
    final StringBuffer root = StringBuffer();
    for (int i = 1; i < folders.length; i++) {
      if (folders[i] == 'Android') break;
      root.write('/${folders[i]}');
    }
    final String result = root.toString();
    return result.isEmpty ? fallback : result;
  }

  static String withTrailingSlash(String path) =>
      path.endsWith('/') ? path : '$path/';

  static void _requireAbsolute(String path, String name) {
    if (!path.startsWith('/')) {
      throw ArgumentError.value(path, name, 'must be an absolute folder');
    }
  }

  static bool _isInside(String relativePath) =>
      relativePath.isNotEmpty &&
      !relativePath.startsWith('/') &&
      !relativePath.split('/').contains('..');
}
