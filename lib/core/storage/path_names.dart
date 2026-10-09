/// Names inside the diary folder (`AppPaths.videos`) and beside it that
/// several layers must agree on, in one place. Pure Dart, so domain types
/// such as `ClipRef` can use it without `dart:io`.
abstract final class PathNames {
  /// The top-level folder of the named profiles' clips,
  /// `Profiles/<key>/`. Default's clips are everywhere else, except here and
  /// in [moviesFolder] (decided by path segment).
  static const String profilesFolder = 'Profiles';

  /// The top-level folder of every profile's movies.
  static const String moviesFolder = 'Movies';

  /// The folder BESIDE the diary (a sibling of `AppPaths.videos`, never
  /// inside it, so the clip scanner never sees it) that holds the originals
  /// the app keeps: processed imports and, with "Keep original recordings",
  /// every in-app recording (`AppPaths.originals`). Files
  /// inside keep their path relative to the diary.
  static const String originalsFolder = 'OneSecondDiary Originals';

  /// The empty marker file that keeps Android galleries out of a folder
  /// (`<originals>/.nomedia`). iOS needs none.
  static const String noMedia = '.nomedia';

  /// The last segment of [path]; the whole [path] when it has no `/`.
  static String fileNameOf(String path) =>
      path.substring(path.lastIndexOf('/') + 1);
}
