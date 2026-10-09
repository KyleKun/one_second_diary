/// The ffprobe argument lists, with the path as its own element. The encoder
/// listing, an ffmpeg command, lives in the gateway that runs it.
abstract final class ProbeCommands {
  /// Prints `audio` when the file has a first audio stream, nothing
  /// otherwise. Run on a gallery video before its save (an empty output
  /// means the save adds a silent track), and on a saved clip whose audio
  /// the save cannot know (a recording, which is never probed before its
  /// save).
  static List<String> audioStream(String path) => <String>[
    '-v',
    'quiet',
    '-select_streams',
    'a:0',
    '-show_entries',
    'stream=codec_type',
    '-of',
    'default=nw=1:nk=1',
    path,
  ];

  /// The format (duration, tags), every stream and the chapters as JSON:
  /// the one probe behind `ClipProbe`, including the `artist` tag that
  /// `ClipProbe.isOsdV15` checks. `-show_chapters` adds a
  /// movie's chapters (`ClipProbe.chapters`), so the movie index gets them
  /// back after a reinstall; a clip has none and the rest of the output is
  /// as before.
  static List<String> streams(String path) => <String>[
    '-v',
    'quiet',
    '-print_format',
    'json',
    '-show_format',
    '-show_streams',
    '-show_chapters',
    path,
  ];

  /// One line per packet of the first video stream, `<pts_time>,<flags>`
  /// (`0.300000,K__`), read by `KeyframeProbeParser` into the clip's
  /// frame count and keyframe positions, for movies with transitions. No
  /// frame is decoded.
  static List<String> keyframes(String path) => <String>[
    '-v',
    'quiet',
    '-select_streams',
    'v:0',
    '-show_entries',
    'packet=pts_time,flags',
    '-of',
    'csv=p=0',
    path,
  ];
}
