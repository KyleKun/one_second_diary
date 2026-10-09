import 'package:one_second_diary/core/media/types/clip_format.dart';

/// The movie join: a stream-copy concat of the clips, plus the movie's tags.
abstract final class ConcatCommand {
  /// Joins the clips listed in [listPath] (`ConcatList`) into [outputPath]:
  ///
  /// - `-f concat -safe 0`: the concat DEMUXER (no re-encode), reading
  ///   absolute paths. Every clip must share codec parameters, and the
  ///   output takes the FIRST clip's stream layout;
  /// - `-r <fps> -map 0 -c copy`: every stream copied; `-r` at the
  ///   format's rate ([fps], 30 for the legacy format) guards
  ///   against audio/video drift in long movies;
  /// - `-y`: the engine refuses an existing [outputPath] before running, so
  ///   nothing is ever overwritten.
  ///
  /// [title] and [comment] become the movie's `title` and `comment` metadata
  /// (movies made by older installs have none), written in the same
  /// stream-copy pass, exactly as `MovieRenderRequest` carries them: the base
  /// title and `profile=<key>`. [description] is the movie's clips and days,
  /// `clips=<n>;from=<yyyy-MM-dd>;to=<yyyy-MM-dd>`, in the same pass. A null
  /// value writes no tag.
  ///
  /// [chaptersPath] is the movie's chapters as an ffmetadata file
  /// (`FfmetadataChapters`), read as a second input right
  /// after the concat list and mapped with `-map_chapters 1`: `-map 0`
  /// still copies every stream of the concat alone, and the metadata flags
  /// are untouched. Null writes no chapters and gives v1.7's argv.
  ///
  /// [audioPath] is the movie's audio track rendered in one pass for a
  /// movie with transitions (`TransitionCommands.audio`),
  /// read as the input right after the list: the video and subtitles come
  /// from the concat (`-map 0:v -map 0:s?`, the bodies carry no audio) and
  /// the audio from it (`-map 1:a`); the chapters are then input 2. Null
  /// keeps `-map 0` and the argv above.
  ///
  /// [secondAudioPath] (a movie with music) is the videos'
  /// own sound, read as input 2 right after [audioPath] (the mix) and
  /// mapped as the second audio track (`-map 2:a`), the first marked
  /// default and the second not (`-disposition:a:0 default
  /// -disposition:a:1 0`), so "music off" is a stream-copy swap of the two
  /// (`MovieAudioCommands.swap`); the chapters are then input 3. It needs
  /// [audioPath]; null keeps the argv above.
  ///
  /// Each path is one element, so spaces (iOS's `Application Support`) never
  /// split it.
  static List<String> build({
    required String listPath,
    required String outputPath,
    FrameRate fps = FrameRate.f30,
    String? title,
    String? comment,
    String? description,
    String? chaptersPath,
    String? audioPath,
    String? secondAudioPath,
  }) {
    if (secondAudioPath != null && audioPath == null) {
      throw ArgumentError.value(
        secondAudioPath,
        'secondAudioPath',
        'needs an audioPath',
      );
    }
    // The chapters file's input index: after the list and the audio tracks.
    final int chaptersInput =
        1 + (audioPath == null ? 0 : 1) + (secondAudioPath == null ? 0 : 1);
    return <String>[
      '-f',
      'concat',
      '-safe',
      '0',
      '-i',
      listPath,
      if (audioPath != null) ...<String>['-i', audioPath],
      if (secondAudioPath != null) ...<String>['-i', secondAudioPath],
      if (chaptersPath != null) ...<String>['-i', chaptersPath],
      '-r',
      '${fps.value}',
      if (audioPath == null) ...<String>['-map', '0'],
      if (audioPath != null) ...<String>['-map', '0:v', '-map', '1:a'],
      if (secondAudioPath != null) ...<String>['-map', '2:a'],
      if (audioPath != null) ...<String>['-map', '0:s?'],
      if (chaptersPath != null) ...<String>['-map_chapters', '$chaptersInput'],
      '-c',
      'copy',
      if (secondAudioPath != null) ...<String>[
        '-disposition:a:0',
        'default',
        '-disposition:a:1',
        '0',
      ],
      if (title != null) ...<String>['-metadata', 'title=$title'],
      if (comment != null) ...<String>['-metadata', 'comment=$comment'],
      if (description != null) ...<String>[
        '-metadata',
        'description=$description',
      ],
      outputPath,
      '-y',
    ];
  }
}
