import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/movie_plan.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_probe.dart';
import 'package:one_second_diary/core/media/types/clip_schema.dart';
import 'package:one_second_diary/core/media/types/movie_clip.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

const ClipFormat _legacy = ClipFormat.legacy(VideoOrientation.landscape);
const ClipFormat _legacyPortrait = ClipFormat.legacy(VideoOrientation.portrait);
const ClipFormat _ultra = ClipFormat(
  tier: ResolutionTier.p2160,
  orientation: VideoOrientation.landscape,
  codec: VideoCodec.hevc,
  fps: FrameRate.f60,
  channels: AudioChannels.stereo,
  range: DynamicRange.sdr,
);

/// A clip with every fact of the legacy format on the landscape canvas,
/// subtitles as given.
MovieClip osdClip({
  String path = '/videos/2024-01-05.mp4',
  bool? isOsdV15 = true,
  bool? hasAudio = true,
  bool? hasSubtitleStream = false,
  int? width = 1920,
  int? height = 1080,
  String? codec = 'h264',
  int? durationMs = 1500,
  double? fps = 30,
  int? channels = 1,
  String? pixelFormat = 'yuv420p',
  String? colorTransfer,
  ClipSchema? schema,
}) => MovieClip(
  path: path,
  durationMs: durationMs,
  isOsdV15: isOsdV15,
  hasAudio: hasAudio,
  hasSubtitleStream: hasSubtitleStream,
  width: width,
  height: height,
  codec: codec,
  fps: fps,
  channels: channels,
  pixelFormat: pixelFormat,
  colorTransfer: colorTransfer,
  schema: schema,
);

/// A clip with every fact of the Ultra preset (4K60 HEVC stereo).
MovieClip ultraClip({int? channels = 2, double? fps = 60}) => osdClip(
  isOsdV15: false,
  width: 3840,
  height: 2160,
  codec: 'hevc',
  fps: fps,
  channels: channels,
);

void main() {
  // The facts decide, never the artist marker. A clip is joined as it is when its codec,
  // canvas, frame rate, pixel format, dynamic range and audio layout are the movie format's.
  test('needsNormalising: which clips get a normalised copy', () {
    final List<(String, MovieClip, ClipFormat, bool)>
    cases = <(String, MovieClip, ClipFormat, bool)>[
      ('a legacy clip in a legacy movie', osdClip(), _legacy, false),
      (
        'a pre-D29 cache entry (schema not read yet) goes by the facts',
        osdClip(isOsdV15: false),
        _legacy,
        false,
      ),
      (
        'a foreign clip is normalised even when every fact matches: the '
            'facts cannot see rotation, parameter sets or the sample rate '
            '(PLAN_backup_sheet §6.4; review 2026-10-07)',
        osdClip(isOsdV15: false, schema: ClipSchema.other),
        _legacy,
        true,
      ),
      (
        'our own v2 clip with matching facts is joined raw',
        osdClip(isOsdV15: false, schema: ClipSchema.v2),
        _legacy,
        false,
      ),
      (
        'no audio stream (the concat needs one in every clip)',
        osdClip(hasAudio: false, channels: null),
        _legacy,
        true,
      ),
      ('stereo in a mono movie', osdClip(channels: 2), _legacy, true),
      ('another codec', osdClip(codec: 'hevc'), _legacy, true),
      ('60 fps in a 30 fps movie', osdClip(fps: 60), _legacy, true),
      ('29.97 fps', osdClip(fps: 29.97), _legacy, true),
      ('30.001 fps is 30', osdClip(fps: 30.001), _legacy, false),
      (
        '10-bit in an SDR movie',
        osdClip(pixelFormat: 'yuv420p10le'),
        _legacy,
        true,
      ),
      (
        'an HDR transfer in an SDR movie',
        osdClip(colorTransfer: 'arib-std-b67'),
        _legacy,
        true,
      ),
      ('PQ is HDR too', osdClip(colorTransfer: 'smpte2084'), _legacy, true),
      (
        'a tagged SDR transfer is fine',
        osdClip(colorTransfer: 'bt709'),
        _legacy,
        false,
      ),
      (
        'an unknown pixel format is compared when known only',
        osdClip(pixelFormat: null),
        _legacy,
        false,
      ),
      (
        'the portrait canvas in a landscape movie',
        osdClip(width: 1080, height: 1920),
        _legacy,
        true,
      ),
      ('a smaller canvas', osdClip(width: 1280, height: 720), _legacy, true),
      (
        '1080x1920 in a portrait movie',
        osdClip(width: 1080, height: 1920),
        _legacyPortrait,
        false,
      ),
      ('1920x1080 in a portrait movie', osdClip(), _legacyPortrait, true),
      ('a 4K60 HEVC stereo clip in an Ultra movie', ultraClip(), _ultra, false),
      ('a legacy clip in an Ultra movie', osdClip(), _ultra, true),
      (
        'a 4K60 HEVC mono clip in an Ultra movie: the sound alone',
        ultraClip(channels: 1),
        _ultra,
        true,
      ),
    ];
    for (final (String name, MovieClip clip, ClipFormat format, bool needs)
        in cases) {
      expect(
        MoviePlan.needsNormalising(clip, format: format),
        needs,
        reason: name,
      );
    }
    // The one caller that still names the legacy canvas by orientation.
    expect(
      MoviePlan.needsNormalising(
        osdClip(),
        orientation: VideoOrientation.landscape,
      ),
      isFalse,
    );
  });

  // When the video matches and only the sound differs, the engine copies
  // the video and re-encodes or adds the audio (the cheaper path).
  test('videoMatches and audioMatches tell the two halves apart', () {
    expect(MoviePlan.videoMatches(osdClip(channels: 2), _legacy), isTrue);
    expect(MoviePlan.audioMatches(osdClip(channels: 2), _legacy), isFalse);
    expect(MoviePlan.videoMatches(osdClip(codec: 'hevc'), _legacy), isFalse);
    expect(MoviePlan.audioMatches(osdClip(codec: 'hevc'), _legacy), isTrue);
    expect(
      MoviePlan.audioMatches(osdClip(hasAudio: false, channels: null), _legacy),
      isFalse,
    );
    expect(MoviePlan.videoMatches(ultraClip(channels: 1), _ultra), isTrue);
    expect(MoviePlan.audioMatches(ultraClip(channels: 1), _ultra), isFalse);
  });

  test('isHdr: the HLG and PQ transfers; nothing else, null included', () {
    expect(MoviePlan.isHdr('arib-std-b67'), isTrue);
    expect(MoviePlan.isHdr('smpte2084'), isTrue);
    expect(MoviePlan.isHdr('bt709'), isFalse);
    expect(MoviePlan.isHdr(null), isFalse);
    expect(MoviePlan.pixelFormatOf(_legacy), 'yuv420p');
  });

  // The concat demuxer takes the FIRST clip's stream layout, so a first clip
  // without a subtitle stream drops every later clip's subtitles. A clip
  // saved without text has no subtitle stream. A normalised first clip needs
  // no fix: its copy gets an empty subtitle stream (step E).
  test('needsFirstClipSubtitles: only when the first clip has none and a '
      'later one has subtitles', () {
    final List<(String, List<MovieClip>, bool)> cases =
        <(String, List<MovieClip>, bool)>[
          (
            'a later clip has subtitles',
            <MovieClip>[osdClip(), osdClip(), osdClip(hasSubtitleStream: true)],
            true,
          ),
          (
            'the first clip has subtitles',
            <MovieClip>[osdClip(hasSubtitleStream: true), osdClip()],
            false,
          ),
          ('no clip has subtitles', <MovieClip>[osdClip(), osdClip()], false),
          (
            'the first clip is normalised',
            <MovieClip>[
              osdClip(codec: 'hevc'),
              osdClip(hasSubtitleStream: true),
            ],
            false,
          ),
        ];
    for (final (String name, List<MovieClip> clips, bool needs) in cases) {
      expect(
        MoviePlan.needsFirstClipSubtitles(clips, format: _legacy),
        needs,
        reason: name,
      );
    }
  });

  // A null fact means unknown; the engine probes that clip once and never guesses. The
  // channel count counts only for a clip with audio; the pixel format and transfer are
  // compared when known.
  test('a clip needs a probe when any fact the plan reads is unknown', () {
    expect(MoviePlan.hasUnknownFacts(osdClip()), isFalse);
    expect(MoviePlan.hasUnknownFacts(osdClip(isOsdV15: null)), isFalse);
    expect(MoviePlan.hasUnknownFacts(osdClip(pixelFormat: null)), isFalse);
    expect(
      MoviePlan.hasUnknownFacts(osdClip(hasAudio: false, channels: null)),
      isFalse,
    );
    final Map<String, MovieClip> unknown = <String, MovieClip>{
      'duration': osdClip(durationMs: null),
      'audio': osdClip(hasAudio: null),
      'subtitle stream': osdClip(hasSubtitleStream: null),
      'width': osdClip(width: null),
      'height': osdClip(height: null),
      'codec': osdClip(codec: null),
      'fps': osdClip(fps: null),
      'channels of a clip with audio': osdClip(channels: null),
    };
    for (final MapEntry<String, MovieClip>(:String key, :MovieClip value)
        in unknown.entries) {
      expect(MoviePlan.hasUnknownFacts(value), isTrue, reason: key);
    }
  });

  test('a probe fills only the unknown facts, the new ones included', () {
    const ClipProbe probe = ClipProbe(
      durationMs: 2002,
      hasAudio: false,
      hasSubtitleStream: true,
      artist: 'One Second Diary (v2)',
      album: null,
      comment: null,
      locationTag: null,
      title: null,
      width: 1280,
      height: 720,
      codec: 'hevc',
      fps: 59.94,
      channels: 2,
      pixelFormat: 'yuv420p10le',
      colorTransfer: 'arib-std-b67',
    );

    final MovieClip some = MoviePlan.withProbe(
      osdClip(durationMs: null, hasAudio: null, codec: null),
      probe: probe,
    );
    expect((some.durationMs, some.hasAudio, some.codec), (2002, false, 'hevc'));
    expect((some.width, some.fps, some.channels), (1920, 30.0, 1));
    expect(some.pixelFormat, 'yuv420p', reason: 'known facts are kept');
    final MovieClip filled = MoviePlan.withProbe(
      osdClip(
        isOsdV15: null,
        hasSubtitleStream: null,
        width: null,
        fps: null,
        channels: null,
        pixelFormat: null,
      ),
      probe: probe,
    );
    expect(filled.isOsdV15, isFalse);
    expect(filled.schema, ClipSchema.v2);
    expect(filled.hasSubtitleStream, isTrue);
    expect(filled.width, 1280);
    expect(filled.fps, 59.94);
    expect(filled.channels, 2);
    expect(filled.pixelFormat, 'yuv420p10le');
    expect(filled.colorTransfer, 'arib-std-b67');
    expect(filled.height, 1080, reason: 'a known fact is kept');
  });

  // An HLG movie stream-copies a clip whose transfer is HLG and whose pixel format, when
  // known, is 10-bit; everything else is normalised on a copy (RangeFilter decides the
  // conversion there). A PQ clip is HDR but not HLG.
  test('HLG facts: which clips join an HLG movie raw', () {
    const ClipFormat hlg = ClipFormat(
      tier: ResolutionTier.p1080,
      orientation: VideoOrientation.landscape,
      codec: VideoCodec.hevc,
      fps: FrameRate.f30,
      channels: AudioChannels.stereo,
      range: DynamicRange.hlg,
    );
    MovieClip hlgClip({
      String? pixelFormat = 'yuv420p10le',
      String? colorTransfer = 'arib-std-b67',
    }) => osdClip(
      isOsdV15: false,
      codec: 'hevc',
      channels: 2,
      pixelFormat: pixelFormat,
      colorTransfer: colorTransfer,
      schema: ClipSchema.v2,
    );
    expect(MoviePlan.pixelFormatOf(hlg), 'yuv420p10le');
    final List<(String, MovieClip, ClipFormat, bool)> cases =
        <(String, MovieClip, ClipFormat, bool)>[
          ('an HLG clip in an HLG movie', hlgClip(), hlg, false),
          (
            'an HLG clip whose pixel format is unknown',
            hlgClip(pixelFormat: null),
            hlg,
            false,
          ),
          (
            'an 8-bit HEVC clip in an HLG movie',
            hlgClip(pixelFormat: 'yuv420p', colorTransfer: null),
            hlg,
            true,
          ),
          (
            'a 10-bit clip without the HLG transfer',
            hlgClip(colorTransfer: null),
            hlg,
            true,
          ),
          (
            'a PQ clip in an HLG movie: HDR, but not HLG',
            hlgClip(colorTransfer: 'smpte2084'),
            hlg,
            true,
          ),
          (
            'an HLG clip in an SDR movie of the same canvas and codec',
            hlgClip(),
            ClipFormatPreset.smallerFiles.format(VideoOrientation.landscape),
            true,
          ),
        ];
    for (final (String name, MovieClip clip, ClipFormat format, bool needs)
        in cases) {
      expect(
        MoviePlan.needsNormalising(clip, format: format),
        needs,
        reason: name,
      );
    }
  });
}
