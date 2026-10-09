/// A movie's two audio tracks (`MovieMusic`): the one playing is first and
/// default. Every path is one element.
abstract final class MovieAudioCommands {
  /// Copies the movie into [output] with its two audio tracks swapped
  /// (`0:a:1` first, then `0:a:0`), the first marked default and the
  /// second not, video, subtitles and chapters stream-copied, and the
  /// movie's `description` set to [description] (which says whether the
  /// music is on). The other global tags are copied by ffmpeg's default
  /// mapping. [output] must have the movie's file name.
  static List<String> swap({
    required String movie,
    required String output,
    required String description,
  }) => <String>[
    '-i',
    movie,
    '-map',
    '0:v',
    '-map',
    '0:a:1',
    '-map',
    '0:a:0',
    '-map',
    '0:s?',
    '-c',
    'copy',
    '-disposition:a:0',
    'default',
    '-disposition:a:1',
    '0',
    '-metadata',
    'description=$description',
    output,
    '-y',
  ];
}
