/// The file list of ffmpeg's concat demuxer (`-f concat -safe 0 -i <list>`).
abstract final class ConcatList {
  /// One `file '<absolute path>'` line per clip, in movie order, joined by
  /// CRLF with no trailing newline.
  ///
  /// Paths are the clips' REAL absolute paths (sub-folder clips included),
  /// which is why `-safe 0` is needed. A `'` is escaped as `'\''` (close the
  /// quote, an escaped quote, reopen): profile names and user-made folders
  /// can contain one.
  ///
  /// With [durations] (seconds with 6 decimals, one per path, as
  /// `TransitionPolicy.seconds` writes them) each file line is followed by
  /// a `duration <seconds>` line: the demuxer then places the next file
  /// after exactly that much, whatever the file's own streams say (a
  /// body cut for a transition keeps a subtitle cue longer than its video).
  /// Without, the list is v1.7's.
  static String content(List<String> absolutePaths, {List<String>? durations}) {
    if (durations != null && durations.length != absolutePaths.length) {
      throw ArgumentError.value(
        durations,
        'durations',
        'one per path, got ${durations.length} for ${absolutePaths.length}',
      );
    }
    return <String>[
      for (final (int index, String path) in absolutePaths.indexed) ...<String>[
        "file '${path.replaceAll("'", r"'\''")}'",
        if (durations != null) 'duration ${durations[index]}',
      ],
    ].join('\r\n');
  }
}
