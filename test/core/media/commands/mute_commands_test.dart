import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/commands/movie_audio_commands.dart';
import 'package:one_second_diary/core/media/commands/mute_commands.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_notes_tag.dart';

import '../../../support/track_1a/platform_layouts.dart';

void main() {
  // Muting is a stream copy of the video and subtitles with a silent mono 48 kHz AAC
  // track in the audio's place, cut with -t (never -shortest: a cue would end it), the
  // other tags copied by default and the notes tag saying muted=1.
  test('muting a clip: video and subtitles copied, a silent track -t long '
      'mapped in the audio\'s place, the notes tag rewritten', () {
    for (final Layout layout in <Layout>[android, ios]) {
      final String clip = '${layout.videos}Profiles/My Trip/2026-09-28.mp4';
      final String output = '${layout.cache}/scratch/out 1/2026-09-28.mp4';
      expect(
        MuteCommands.silence(
          clip: clip,
          output: output,
          durationMs: 1500,
          notes: 'place=Home;muted=1',
        ),
        <String>[
          '-i', clip, //
          '-f', 'lavfi', '-t', '1500ms',
          '-i', 'anullsrc=channel_layout=mono:sample_rate=48000',
          '-map', '0:v', '-map', '1:a', '-map', '0:s?',
          '-c:v', 'copy', '-c:s', 'copy',
          '-ac', '1', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
          '-metadata', 'synopsis=place=Home;muted=1',
          output, '-y',
        ],
        reason: layout.name,
      );
    }
  });

  // A clip of a stereo profile gets a stereo silent track, so the movie's stream copy
  // still matches.
  test('muting a clip of a stereo profile: the silent track in stereo', () {
    expect(
      MuteCommands.silence(
        clip: '/v/2026-09-28.mp4',
        output: '/c/out/2026-09-28.mp4',
        durationMs: 1500,
        notes: 'muted=1',
        channels: AudioChannels.stereo,
      ),
      <String>[
        '-i', '/v/2026-09-28.mp4', //
        '-f', 'lavfi', '-t', '1500ms',
        '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
        '-map', '0:v', '-map', '1:a', '-map', '0:s?',
        '-c:v', 'copy', '-c:s', 'copy',
        '-ac', '2', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
        '-metadata', 'synopsis=muted=1',
        '/c/out/2026-09-28.mp4', '-y',
      ],
    );
  });

  test('the notes the mute writes: muted=1 added to the clip\'s own, alone '
      'without any, once when already there', () {
    expect(MuteCommands.notesFor(null), 'muted=1');
    expect(MuteCommands.notesFor(''), 'muted=1');
    expect(MuteCommands.notesFor('place=Home'), 'place=Home;muted=1');
    expect(
      MuteCommands.notesFor('device=Pixel;place=Home;muted=1'),
      'device=Pixel;place=Home;muted=1',
    );
    expect(ClipNotesTag.isMuted('place=Home;muted=1'), isTrue);
    expect(ClipNotesTag.isMuted('place=Home'), isFalse);
    expect(ClipNotesTag.isMuted(null), isFalse);
  });

  // The movie's two audio tracks swapped: the second first and default,
  // everything else (video, subtitles, chapters, tags) copied; only the
  // description changes, to say which track plays.
  test('swapping a movie\'s audio tracks is a stream copy with 0:a:1 '
      'before 0:a:0, the first default, the description set', () {
    for (final Layout layout in <Layout>[android, ios]) {
      final String movie = '${layout.videos}Movies/OSD-Movie-3-2026-09-28.mp4';
      final String output =
          '${layout.cache}/scratch/out 2/OSD-Movie-3-2026-09-28.mp4';
      expect(
        MovieAudioCommands.swap(
          movie: movie,
          output: output,
          description: 'clips=25;from=2026-09-01;to=2026-09-28;music=off',
        ),
        <String>[
          '-i', movie, //
          '-map', '0:v', '-map', '0:a:1', '-map', '0:a:0', '-map', '0:s?',
          '-c', 'copy',
          '-disposition:a:0', 'default', '-disposition:a:1', '0',
          '-metadata',
          'description=clips=25;from=2026-09-01;to=2026-09-28;music=off',
          output, '-y',
        ],
        reason: layout.name,
      );
    }
  });
}
