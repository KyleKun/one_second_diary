import 'package:one_second_diary/core/media/commands/clip_encoding.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_notes_tag.dart';

/// Muting a saved clip: its sound replaced with silence, nothing
/// re-encoded but that silent track. Every path is one element, so spaces
/// (iOS's `Application Support`) never split it.
abstract final class MuteCommands {
  /// Copies the clip into [output] with a silent 48 kHz AAC track in
  /// [channels]'s layout (the profile's; mono for the legacy format)
  /// [durationMs] long in place of its audio
  /// (`ClipEncoding.silentAudioInputOf`, cut with `-t`, never `-shortest`:
  /// a subtitle cue would end it): video and any subtitle stream
  /// stream-copied (`0:s?`), the clip's own audio dropped, and the notes
  /// tag rewritten as [notes] (`ClipNotesTag.withMuted` over the clip's
  /// own, so `muted=1` says it was).
  ///
  /// The clip is input 0 so ffmpeg's default metadata mapping copies its
  /// other global tags (artist, album, comment, location, description,
  /// keywords) as they are. [output] must have the clip's file name:
  /// Android publishes under the temp file's name.
  static List<String> silence({
    required String clip,
    required String output,
    required int durationMs,
    required String notes,
    AudioChannels channels = AudioChannels.mono,
  }) => <String>[
    '-i',
    clip,
    ...ClipEncoding.silentAudioInputOf(channels, durationMs: durationMs),
    '-map',
    '0:v',
    '-map',
    '1:a',
    '-map',
    '0:s?',
    '-c:v',
    'copy',
    '-c:s',
    'copy',
    ...ClipEncoding.audioSettings(channels),
    '-metadata',
    'synopsis=$notes',
    output,
    '-y',
  ];

  /// The `synopsis` value [silence] writes for a clip whose notes tag is
  /// [synopsis] (null for none).
  static String notesFor(String? synopsis) => ClipNotesTag.withMuted(synopsis);
}
