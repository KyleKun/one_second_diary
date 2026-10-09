import 'package:one_second_diary/core/media/types/clip_privacy_tag.dart';

/// Marking a clip private or public, without re-encoding. Every path is one
/// element, so spaces (iOS's `Application Support`) never split it.
abstract final class PrivacyCommands {
  /// Copies the clip into [output] with the privacy tag set
  /// (`description=private=1`) or removed (an empty value deletes the key):
  /// video, audio and any subtitle stream are stream-copied (`0:a?` keeps a
  /// silent clip working, `0:s?` one without subtitles).
  ///
  /// The clip is input 0 so ffmpeg's default metadata mapping copies its
  /// other global tags (artist, album, comment, location) as they are.
  /// [output] must have the clip's file name: Android publishes under the
  /// temp file's name.
  static List<String> tag({
    required String clip,
    required String output,
    required bool private,
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
    'description=${private ? ClipPrivacyTag.description : ''}',
    output,
    '-y',
  ];
}
