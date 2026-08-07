import 'dart:io' as io;

import 'package:path_provider/path_provider.dart';

import 'platform_utils.dart';
import 'shared_preferences_util.dart';

/// Owns every directory the app writes to.
///
/// Paths are resolved once per launch and kept in memory. They are
/// deliberately not read back from [SharedPrefsUtil] at call time: on iOS the
/// application container is rooted at a UUID that is regenerated on every
/// reinstall, OS migration and backup restore, so a persisted absolute path
/// silently stops resolving and the user appears to have lost every video.
/// The same keys are still written to [SharedPrefsUtil] because the Android
/// folder migration and older builds read them.
///
/// Layout:
///
/// | | Android | iOS |
/// |---|---|---|
/// | videos   | `<storage root>/DCIM/OneSecondDiary/`         | `<Documents>/OneSecondDiary/` |
/// | movies   | `<storage root>/DCIM/OneSecondDiary/Movies/`  | `<Documents>/OneSecondDiary/Movies/` |
/// | internal | `<Documents>` | `<Application Support>` |
///
/// On iOS the videos live under `Documents` on purpose: combined with
/// `UIFileSharingEnabled` it is the only place the user can browse from the
/// Files app, which is the closest equivalent to the visible DCIM folder used
/// on Android. Scratch files (logs, srt, concat lists, the ffmpeg font) stay in
/// `Application Support` so the folder the user sees only ever contains videos.
class AppPaths {
  AppPaths._();

  static const String folderName = 'OneSecondDiary';

  static String _videos = '';
  static String _movies = '';
  static String _internal = '';
  static bool _isReady = false;

  /// Whether [init] has already resolved the paths.
  static bool get isReady => _isReady;

  /// Folder holding the daily videos of the default profile.
  /// Always ends with a trailing slash.
  static String get videos => _videos;

  /// Folder holding the generated movies. Always ends with a trailing slash.
  static String get movies => _movies;

  /// App private folder for logs and scratch files. No trailing slash, to match
  /// what `path_provider` returns.
  static String get internal => _internal;

  /// Folder holding the videos of [profileName], or [videos] when the name is
  /// empty, which is how the default profile is represented across the app.
  static String profileVideos(String profileName) =>
      profileName.isEmpty ? _videos : '${_videos}Profiles/$profileName/';

  /// Resolves the paths for the current platform. Safe to call more than once.
  static Future<void> init() async {
    if (_isReady) return;

    final String documents = (await getApplicationDocumentsDirectory()).path;

    if (PlatformUtils.isIOS) {
      _internal = (await getApplicationSupportDirectory()).path;
      _videos = withTrailingSlash('$documents/$folderName');
    } else {
      _internal = documents;
      _videos = withTrailingSlash('${await _androidStorageRoot(documents)}/DCIM/$folderName');
    }
    _movies = '${_videos}Movies/';

    await SharedPrefsUtil.putString('internalDirectoryPath', _internal);
    await SharedPrefsUtil.putString('appPath', _videos);
    await SharedPrefsUtil.putString('moviesPath', _movies);

    _isReady = true;
  }

  /// Creates the folders the rest of the app assumes to exist.
  static Future<void> createDirectories() async {
    await io.Directory('$_internal/Logs').create(recursive: true);
    await io.Directory(_videos).create(recursive: true);
    await io.Directory(_movies).create(recursive: true);
  }

  /// Walks up from the app private external folder to the storage root, e.g.
  /// `/storage/emulated/0/Android/data/<package>/files` -> `/storage/emulated/0`.
  static Future<String> _androidStorageRoot(String fallback) async {
    final io.Directory? external = await getExternalStorageDirectory();
    if (external == null) return fallback;
    return storageRootOf(external.path, fallback: fallback);
  }

  /// Visible for testing: the pure part of [_androidStorageRoot].
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

  static String withTrailingSlash(String path) => path.endsWith('/') ? path : '$path/';

  /// Visible for testing.
  static void debugSetPaths({
    required String videos,
    required String movies,
    required String internal,
  }) {
    _videos = videos;
    _movies = movies;
    _internal = internal;
    _isReady = true;
  }

  /// Visible for testing.
  static void debugReset() {
    _videos = '';
    _movies = '';
    _internal = '';
    _isReady = false;
  }
}
