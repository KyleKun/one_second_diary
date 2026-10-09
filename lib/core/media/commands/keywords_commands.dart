import 'package:one_second_diary/core/media/types/keywords_tag.dart';

/// Writing a clip's tags, without re-encoding. The same remux as
/// `PrivacyCommands`: every path is one element, so spaces (iOS's
/// `Application Support`) never split it.
abstract final class KeywordsCommands {
  /// Copies the clip into [output] with its `keywords` tag set to [tags]
  /// (an empty list deletes the tag): video, audio and any subtitle stream
  /// are stream-copied (`0:a?` keeps a silent clip working, `0:s?` one
  /// without subtitles).
  ///
  /// The clip is input 0 so ffmpeg's default metadata mapping copies its
  /// other global tags (artist, album, comment, location, description,
  /// synopsis) as they are. [output] must have the clip's file name:
  /// Android publishes under the temp file's name.
  static List<String> set({
    required String clip,
    required String output,
    required List<String> tags,
  }) => <String>[
    '-i',
    clip,
    '-c',
    'copy',
    '-map',
    '0:v',
    '-map',
    '0:a?',
    '-map',
    '0:s?',
    '-metadata',
    'keywords=${KeywordsTag.format(tags)}',
    output,
    '-y',
  ];
}
