import 'package:one_second_diary/core/media/commands/clip_encoding.dart';
import 'package:one_second_diary/core/media/policy/transition_policy.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/movie_transition.dart';

/// One clip's audio in the movie's audio pass ([TransitionCommands.audio]).
typedef AudioInput = ({String path, String seconds});

/// The ffmpeg argument lists of a movie with transitions: the stream-copied
/// bodies, the rendered boundary segments and the one audio pass, at the
/// movie format's frame rate and audio layout. Every path is its own element.
abstract final class TransitionCommands {
  /// The body of a clip between its cut keyframes, stream-copied without
  /// audio (the movie's audio is one track, [audio]): from keyframe
  /// [headCut] (`-ss` at its exact time, `TransitionPolicy.seekForCopy`;
  /// nothing for 0, the clip's start) up to, not including, keyframe
  /// [tailCut] (`-frames:v`, the count of frames shown before it, which is
  /// exact: every frame shown before a keyframe is decoded before it;
  /// nothing for null, the clip's end). The subtitle stream rides along
  /// (`0:s?`): a cue that started before the cut is kept and starts at 0.
  static List<String> body({
    required String input,
    required String output,
    required int headCut,
    required int? tailCut,
    required FrameRate fps,
  }) => <String>[
    if (headCut > 0) ...<String>[
      '-ss',
      TransitionPolicy.seekForCopy(headCut, fps: fps),
    ],
    '-i',
    input,
    if (tailCut != null) ...<String>['-frames:v', '${tailCut - headCut}'],
    '-map',
    '0:v',
    '-map',
    '0:s?',
    '-c',
    'copy',
    '-an',
    output,
    '-y',
  ];

  /// The frames around one boundary, decoded and rendered again with
  /// [transition]: clip [before] from its tail keyframe [beforeTailCut]
  /// (`-ss` rounded down, `TransitionPolicy.seekForDecode`, so the keyframe
  /// itself is kept) to its end, crossfaded with clip [after] from its
  /// start to its head keyframe [afterHeadCut] (`-t` of that many frames).
  /// `xfade` starts `TransitionPolicy.frames` frames before the end of the
  /// tail (`offset`), so the segment lasts tail + head − the transition
  /// and the movie's clips overlap by exactly it.
  ///
  /// The video is encoded with the clips' own settings
  /// (`ClipEncoding.videoEncodeSettings` of [format]), so its parameter
  /// sets equal the bodies' and the joined MP4's single parameter set
  /// fits every packet. The empty subtitle stream ([emptySubtitles], the
  /// placeholder cue) keeps the segment's stream layout equal to the
  /// bodies'. No audio.
  static List<String> segment({
    required String before,
    required int beforeFrameCount,
    required int beforeTailCut,
    required String after,
    required int afterHeadCut,
    required String emptySubtitles,
    required MovieTransition transition,
    required ClipFormat format,
    required VideoEncoder encoder,
    required String output,
  }) {
    final FrameRate fps = format.fps;
    return <String>[
      '-ss',
      TransitionPolicy.seekForDecode(beforeTailCut, fps: fps),
      '-i',
      before,
      '-t',
      TransitionPolicy.seconds(afterHeadCut, fps: fps),
      '-i',
      after,
      '-i',
      emptySubtitles,
      '-filter_complex',
      '[0:v][1:v]xfade=transition=${transition.xfadeName}'
          ':duration=${TransitionPolicy.durationSeconds(fps)}'
          ':offset=${TransitionPolicy.seconds(beforeFrameCount - beforeTailCut - TransitionPolicy.frames(fps), fps: fps)}'
          '[v]',
      '-map',
      '[v]',
      '-map',
      '2:s',
      '-c:s',
      'mov_text',
      ...ClipEncoding.videoEncodeSettings(format, encoder),
      '-an',
      output,
      '-y',
    ];
  }

  /// The movie's audio from the clips' own audio, in one pass: every input
  /// is cut (or padded with silence) to exactly its video's length
  /// (`apad,atrim`, so clip audio a few samples long or short never drifts
  /// the movie), then joined left to right with `acrossfade` over the
  /// transition's length where [crossfades] says so (one entry per
  /// boundary) or `concat` for a hard cut. [toAac] encodes the movie's
  /// AAC track in [format]'s layout (48 kHz 256k); without, the output is
  /// PCM, for a chunk of a long movie (`TransitionPolicy.audioChunkClips`
  /// clips per pass) that a last pass joins the same way.
  static List<String> audio({
    required List<AudioInput> inputs,
    required List<bool> crossfades,
    required String output,
    required bool toAac,
    required ClipFormat format,
  }) {
    if (inputs.isEmpty) {
      throw ArgumentError.value(inputs, 'inputs', 'needs one or more');
    }
    if (crossfades.length != inputs.length - 1) {
      throw ArgumentError.value(
        crossfades,
        'crossfades',
        'one per boundary, got ${crossfades.length} for ${inputs.length}',
      );
    }
    final String duration = TransitionPolicy.durationSeconds(format.fps);
    final List<String> graph = <String>[
      for (final (int index, AudioInput input) in inputs.indexed)
        '[$index:a]apad,atrim=0:${input.seconds}[a$index]',
    ];
    String joined = 'a0';
    for (int index = 1; index < inputs.length; index++) {
      final String out = index == inputs.length - 1 ? 'a' : 'x$index';
      graph.add(
        crossfades[index - 1]
            ? '[$joined][a$index]acrossfade=d=$duration:c1=tri:c2=tri[$out]'
            : '[$joined][a$index]concat=n=2:v=0:a=1[$out]',
      );
      joined = out;
    }
    if (inputs.length == 1) {
      graph[0] = '[0:a]apad,atrim=0:${inputs[0].seconds}[a]';
    }
    return <String>[
      for (final AudioInput input in inputs) ...<String>['-i', input.path],
      '-filter_complex',
      graph.join(';'),
      '-map',
      '[a]',
      if (toAac)
        ...ClipEncoding.audioSettings(format.channels)
      else ...<String>['-c:a', 'pcm_s16le'],
      output,
      '-y',
    ];
  }
}
