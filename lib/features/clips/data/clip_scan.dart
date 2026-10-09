import 'package:one_second_diary/features/clips/domain/clip_index.dart';
import 'package:one_second_diary/features/clips/domain/clip_name_codec.dart';

/// What one scan of a profile's clip folder found. Plain immutable data:
/// it is built in a background isolate and handed back whole.
final class ClipScan {
  const ClipScan({
    required this.index,
    required this.skippedNames,
    required this.unreadableFolders,
    required this.folderStamps,
    this.foreignFiles = const <String>[],
  });

  /// The extensions (lower case, with the dot) of a date-named video the index
  /// does not take but the processing sheet offers: what phones and the Files
  /// app export. `.mp4` in another letter case counts too (`isForeignName`).
  static const List<String> foreignExtensions = <String>[
    '.mov',
    '.m4v',
    '.3gp',
    '.mp4',
  ];

  /// Whether [fileName] is a date-named video with one of
  /// [foreignExtensions] that is NOT a clip name (`2024-01-05.mov`,
  /// `2024-01-05-2.MP4`, `2024-01-05.M4V`): the stem must be exactly what
  /// `ClipNameCodec` accepts, so the file has a day.
  static bool isForeignName(String fileName) {
    final int dot = fileName.lastIndexOf('.');
    if (dot <= 0) return false;
    final String extension = fileName.substring(dot).toLowerCase();
    if (!foreignExtensions.contains(extension)) return false;
    final String asClip = '${fileName.substring(0, dot)}.mp4';
    return ClipNameCodec.parse(asClip) != null && fileName != asClip;
  }

  /// A missing folder's entry in [folderStamps].
  static const int missingFolder = -1;

  final ClipIndex index;

  /// Every folder the scan listed (absolute path) with its modification
  /// time in microseconds, or [missingFolder]. Adding or removing an entry
  /// changes a folder's time on Android and iOS, so comparing these is how
  /// a resume tells whether the Gallery or the Files app changed anything.
  /// Held in memory only (absolute paths are never persisted).
  final Map<String, int> folderStamps;

  /// relPaths of the `.mp4` files (any letter case) whose names are not
  /// clip names, sorted. They are dropped on purpose and logged.
  final List<String> skippedNames;

  /// relPaths (ending in `/`) of sub-folders that could not be listed, so
  /// their clips are missing from [index]. Sorted.
  final List<String> unreadableFolders;

  /// relPaths of the date-named videos with another extension
  /// ([isForeignName]) DIRECTLY in the profile's own folder, sorted. Never
  /// indexed or shown as days; they exist for the processing sheet. A
  /// date-named file inside a user-made sub-folder stays the user's.
  final List<String> foreignFiles;
}
