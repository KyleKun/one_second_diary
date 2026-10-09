import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/commands/music_commands.dart';
import 'package:one_second_diary/core/media/types/movie_music.dart';

import '../../../support/track_1a/platform_layouts.dart';

void main() {
  // The music chain: every track to stereo 48 kHz, then concat; the loop with
  // -stream_loop -1 cut by -t; the mix with the music's volume and a 2 s fade-out over
  // the clips' track brought to stereo, amix ending with the clips (duration=first) at
  // their own levels (normalize=0); stereo 48 kHz AAC 256k out.
  test('sequence: one track is a conversion, three are converted then '
      'concatenated, as PCM', () {
    for (final Layout layout in <Layout>[android, ios]) {
      final String music = '${layout.cache}/scratch/music-1';
      final String job = '${layout.cache}/scratch/job-1';
      expect(
        MusicCommands.sequence(
          tracks: <String>['$music/0-my song.mp3'],
          output: '$job/sequence.wav',
        ),
        <String>[
          '-i', '$music/0-my song.mp3', //
          '-filter_complex',
          '[0:a]aformat=sample_rates=48000:channel_layouts=stereo[a]',
          '-map', '[a]', '-c:a', 'pcm_s16le',
          '$job/sequence.wav', '-y',
        ],
        reason: layout.name,
      );
      expect(
        MusicCommands.sequence(
          tracks: <String>[
            '$music/0-a.mp3',
            '$music/1-b.m4a',
            '$music/2-c.wav',
          ],
          output: '$job/sequence.wav',
        ),
        <String>[
          '-i', '$music/0-a.mp3', '-i', '$music/1-b.m4a', //
          '-i', '$music/2-c.wav',
          '-filter_complex',
          '[0:a]aformat=sample_rates=48000:channel_layouts=stereo[a0];'
              '[1:a]aformat=sample_rates=48000:channel_layouts=stereo[a1];'
              '[2:a]aformat=sample_rates=48000:channel_layouts=stereo[a2];'
              '[a0][a1][a2]concat=n=3:v=0:a=1[a]',
          '-map', '[a]', '-c:a', 'pcm_s16le',
          '$job/sequence.wav', '-y',
        ],
        reason: layout.name,
      );
    }
    expect(
      () => MusicCommands.sequence(tracks: const <String>[], output: 'x'),
      throwsArgumentError,
    );
  });

  test('loop: the sequence repeated without end, cut to the movie\'s '
      'length', () {
    expect(
      MusicCommands.loop(
        sequence: '/scratch job/sequence.wav',
        durationMs: 183400,
        output: '/scratch job/loop.wav',
      ),
      <String>[
        '-stream_loop', '-1', '-i', '/scratch job/sequence.wav', //
        '-t', '183400ms', '-c:a', 'pcm_s16le',
        '/scratch job/loop.wav', '-y',
      ],
    );
  });

  test('mix: the music at its volume with the fade-out over the clips\' '
      'track, or alone; a movie shorter than the fade gets none', () {
    const String loop = '/scratch job/loop.wav';
    const String clips = '/scratch job/audio.m4a';
    const String out = '/scratch job/mix.m4a';
    const List<String> encode = <String>[
      '-map', '[a]', '-ac', '2', '-ar', '48000', //
      '-c:a', 'aac', '-b:a', '256k', out, '-y',
    ];
    expect(
      MusicCommands.mix(
        music: loop,
        clips: clips,
        volume: MovieMusic.defaultVolume,
        durationMs: 183400,
        output: out,
      ),
      <String>[
        '-i', clips, '-i', loop, //
        '-filter_complex',
        '[0:a]aformat=sample_rates=48000:channel_layouts=stereo[c];'
            '[1:a]volume=0.50,afade=t=out:st=181.400:d=2.000[m];'
            '[c][m]amix=inputs=2:duration=first:normalize=0[a]',
        ...encode,
      ],
    );
    expect(
      MusicCommands.mix(
        music: loop,
        clips: null,
        volume: 1,
        durationMs: 3500,
        output: out,
      ),
      <String>[
        '-i', loop, //
        '-filter_complex',
        '[0:a]volume=1.00,afade=t=out:st=1.500:d=2.000[a]',
        ...encode,
      ],
    );
    expect(
      MusicCommands.mix(
        music: loop,
        clips: null,
        volume: 0.25,
        durationMs: 1500,
        output: out,
      ),
      <String>[
        '-i', loop, '-filter_complex', '[0:a]volume=0.25[a]', ...encode, //
      ],
    );
  });
}
