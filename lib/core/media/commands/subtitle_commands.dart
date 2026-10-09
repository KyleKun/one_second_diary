/// Editing and reading a clip's soft subtitles, without re-encoding. Every
/// path is one element, so spaces (iOS's `Application Support`) never split
/// it.
abstract final class SubtitleCommands {
  /// Replaces the clip's subtitles with [subtitles] (an SRT from
  /// `SrtCodec.encode`) into [output]: video and audio stream-copied (`0:a?`
  /// keeps a silent clip working), any old subtitle stream dropped, the new
  /// one default.
  ///
  /// The clip is input 0 so ffmpeg's default metadata mapping copies its
  /// global tags (artist, album, comment, location): a re-subtitled clip
  /// keeps its `osdArtist` tag. [output] must have the clip's file name:
  /// Android publishes under the temp file's name.
  static List<String> remux({
    required String clip,
    required String subtitles,
    required String output,
  }) => <String>[
    '-i',
    clip,
    '-i',
    subtitles,
    '-c:s',
    'mov_text',
    '-c:v',
    'copy',
    '-c:a',
    'copy',
    '-map',
    '0:v',
    '-map',
    '0:a?',
    '-map',
    '1',
    '-disposition:s:0',
    'default',
    output,
    '-y',
  ];

  /// Copies the clip into [output] WITHOUT a subtitle stream (`-sn`), tags
  /// kept as in [remux].
  static List<String> remove({required String clip, required String output}) =>
      <String>[
        '-i',
        clip,
        '-c:v',
        'copy',
        '-c:a',
        'copy',
        '-map',
        '0:v',
        '-map',
        '0:a?',
        '-sn',
        output,
        '-y',
      ];

  /// Writes the clip's subtitle stream to [output], an `.srt` file; read it
  /// with `SrtCodec.decode`. The extension makes ffmpeg pick only the
  /// subtitle stream, so a clip without one FAILS: that failure means "no
  /// subtitles".
  static List<String> extract({required String clip, required String output}) =>
      <String>['-i', clip, output, '-y'];
}
