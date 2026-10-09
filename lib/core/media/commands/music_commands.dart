import 'package:one_second_diary/core/media/types/movie_music.dart';

/// The ffmpeg argument lists of a movie's music (`MovieMusic`): the picked files joined, repeated to the movie's length, and mixed
/// over the videos' own sound. Every path is its own element.
abstract final class MusicCommands {
  /// The movie's audio sample rate and layout: the clips are mono 48 kHz,
  /// music is anything; the mix is stereo 48 kHz.
  static const String sampleRate = '48000';
  static const String stereo = 'stereo';

  /// Joins [tracks] (any format, rate or layout) into one PCM file
  /// [output] (`.wav`): every input is brought to stereo 48 kHz first
  /// (`aformat`; `concat` needs equal formats), then `concat=n=<count>`
  /// lays them end to end. One track gives the same file, converted.
  static List<String> sequence({
    required List<String> tracks,
    required String output,
  }) {
    if (tracks.isEmpty) {
      throw ArgumentError.value(tracks, 'tracks', 'needs one or more');
    }
    final List<String> graph = <String>[
      for (int index = 0; index < tracks.length; index++)
        '[$index:a]aformat=sample_rates=$sampleRate:channel_layouts=$stereo'
            '[${tracks.length == 1 ? 'a' : 'a$index'}]',
      if (tracks.length > 1)
        '${<String>[for (int i = 0; i < tracks.length; i++) '[a$i]'].join()}'
            'concat=n=${tracks.length}:v=0:a=1[a]',
    ];
    return <String>[
      for (final String track in tracks) ...<String>['-i', track],
      '-filter_complex',
      graph.join(';'),
      '-map',
      '[a]',
      '-c:a',
      'pcm_s16le',
      output,
      '-y',
    ];
  }

  /// [sequence]'s file repeated without end (`-stream_loop -1`, an input
  /// option) and cut to [durationMs] (`-t`, an output option) into the PCM
  /// file [output]: the movie's length of music, whatever the tracks'.
  static List<String> loop({
    required String sequence,
    required int durationMs,
    required String output,
  }) => <String>[
    '-stream_loop',
    '-1',
    '-i',
    sequence,
    '-t',
    '${durationMs}ms',
    '-c:a',
    'pcm_s16le',
    output,
    '-y',
  ];

  /// The movie's audio track [output] (`.m4a`, stereo 48 kHz AAC 256k):
  /// the looped [music] at [volume] (`volume=<0–1>`), fading out over the
  /// last `MovieMusic.fadeOutMs` of the [durationMs]-long movie
  /// (`afade=t=out:st=<start>:d=<length>`, so a loop never ends mid-bar;
  /// no fade when the movie is shorter than the fade), mixed with the
  /// videos' own sound [clips] (`amix`, the mono track brought to stereo
  /// first since `amix` needs equal layouts; `duration=first` ends the mix
  /// with the clips' track, `normalize=0` keeps every input's level), or
  /// the faded music alone when [clips] is null (the music plays in place
  /// of the videos' sound).
  static List<String> mix({
    required String music,
    required String? clips,
    required double volume,
    required int durationMs,
    required String output,
  }) {
    final String faded =
        'volume=${volume.toStringAsFixed(2)}'
        '${_fade(durationMs)}';
    final String graph = clips == null
        ? '[0:a]$faded[a]'
        : '[0:a]aformat=sample_rates=$sampleRate:channel_layouts=$stereo[c];'
              '[1:a]$faded[m];'
              '[c][m]amix=inputs=2:duration=first:normalize=0[a]';
    return <String>[
      if (clips != null) ...<String>['-i', clips],
      '-i',
      music,
      '-filter_complex',
      graph,
      '-map',
      '[a]',
      '-ac',
      '2',
      '-ar',
      sampleRate,
      '-c:a',
      'aac',
      '-b:a',
      '256k',
      output,
      '-y',
    ];
  }

  /// `,afade=t=out:st=<seconds>:d=<seconds>` for a movie [durationMs]
  /// long; nothing when the movie is shorter than the fade.
  static String _fade(int durationMs) {
    if (durationMs < MovieMusic.fadeOutMs) return '';
    final String start = ((durationMs - MovieMusic.fadeOutMs) / 1000)
        .toStringAsFixed(3);
    final String length = (MovieMusic.fadeOutMs / 1000).toStringAsFixed(3);
    return ',afade=t=out:st=$start:d=$length';
  }
}
