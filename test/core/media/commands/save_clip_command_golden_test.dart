// Golden: the save argv for every combination of options, a few readable cases pinned
// element by element and the whole matrix composed from literal pieces (the canvas per
// orientation, the args per encoder, the stamp per style) and compared element by
// element. ffmpeg's arguments are binding: when a case fails, the readable cases and the
// tests in this folder show what changed.
//
// Every save carries ONE `-force_key_frames <head>,<tail>` pair right after
// `-pix_fmt yuv420p`: a keyframe 10 frames from each end of the clip (times rounded down
// to 4 decimals, `0.3333,1.1666` for 1.5 s), so a movie with transitions can cut the
// clip there by stream copy.
//
// For the LEGACY format (`ClipFormat.legacy`) libx264 takes `-preset medium`, and the
// end is exactly the selection (1500 ms, 2734 ms, 10500 ms in the fixtures). Any other
// format (HEVC, 4K, 60 fps, stereo) is its own argv, pinned below.

import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/commands/clip_render_files.dart';
import 'package:one_second_diary/core/media/commands/save_clip_command.dart';
import 'package:one_second_diary/core/media/policy/video_encoder.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/clip_location.dart';
import 'package:one_second_diary/core/media/types/clip_render_request.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

import '../../../support/track_1a/platform_layouts.dart';

/// The three H.264 encoders of the legacy format.
const List<VideoEncoder> h264Encoders = <VideoEncoder>[
  VideoEncoder.libx264,
  VideoEncoder.videoToolbox,
  VideoEncoder.mediaCodec,
];

/// Scratch files where the app puts them, the font in fontsDir; on iOS the text
/// files sit in Application Support too, so every path has a space.
ClipRenderFiles filesFor(Layout layout, String album) {
  final String scratch = layout == ios
      ? '${layout.internal}/scratch job'
      : '${layout.cache}/scratch/job-1';
  return ClipRenderFiles(
    subtitles: '$scratch/subtitles.srt',
    font: '${layout.internal}/YuseiMagic-Regular.v1.ttf',
    dateText: '$scratch/date.txt',
    locationText: '$scratch/location.txt',
    output: album == 'Default'
        ? '$scratch/2026-09-28.mp4'
        : '${layout.videos}Profiles/$album/2026-09-28-2.mp4',
  );
}

const List<int> colors = <int>[0xFFFFFF, 0xE53935, 0x212121, 0x0A0B0C];
const List<String> places = <String>[
  'Tokyo, "Japan"',
  "Val d'Isère",
  'São Paulo, Brazil',
  '',
];
const List<(int, int)> trims = <(int, int)>[
  (0, 1500),
  (1234, 2734),
  (0, 10500),
];
const List<double> photoDurations = <double>[1, 1.5, 2, 3, 5, 10];

/// Where the save came from: a recording, a gallery video with audio or one
/// without audio (silent track added).
enum Source { recording, galleryWithAudio, galleryWithoutAudio }

typedef VideoCase = ({
  String label,
  VideoRender request,
  ClipRenderFiles files,
  VideoEncoder encoder,
  bool silent,
});

typedef PhotoCase = ({
  String label,
  PhotoRender request,
  ClipRenderFiles files,
  VideoEncoder encoder,
});

/// Every legacy video save on [layout]: 144 cases.
List<VideoCase> videoCases(Layout layout) {
  final List<VideoCase> cases = <VideoCase>[];
  int n = 0;
  for (final StampFormat format in StampFormat.values) {
    for (final bool geotag in <bool>[false, true]) {
      for (final bool subs in <bool>[false, true]) {
        for (final Source source in Source.values) {
          for (final VideoOrientation orientation in VideoOrientation.values) {
            for (final VideoEncoder encoder in h264Encoders) {
              n++;
              final String album = n.isEven ? 'Default' : 'My Trip';
              final (int start, int end) = trims[n % trims.length];
              cases.add((
                label:
                    '${format.name} geotag:$geotag subs:$subs ${source.name} '
                    '${orientation.name} ${encoder.name}',
                request: VideoRender(
                  sourcePath: source == Source.recording
                      ? '${layout.cache}/REC_$n.mp4'
                      : '${layout.cache}/picker $n/IMG_$n.MOV',
                  fromRecording: source == Source.recording,
                  trimStartMs: start,
                  trimEndMs: end,
                  outputFileName: '2026-09-28.mp4',
                  stampText: 'unused by the argv',
                  stampStyle: StampStyle(
                    format: format,
                    rgb: colors[n % colors.length],
                    outline: n % 3 != 0,
                  ),
                  legacyStampFont: false,
                  location: geotag
                      ? ClipLocation(
                          enabled: true,
                          text: places[n % places.length],
                          latitude: n.isEven ? 35.7148 : -23.55,
                          longitude: n.isEven ? 139.7967 : -46.63,
                        )
                      : const ClipLocation.off(),
                  subtitles: subs ? 'Walk around Asakusa' : '',
                  format: ClipFormat.legacy(orientation),
                  albumLabel: album,
                ),
                files: filesFor(layout, album),
                encoder: encoder,
                silent: source == Source.galleryWithoutAudio,
              ));
            }
          }
        }
      }
    }
  }
  return cases;
}

/// Every legacy photo save on [layout]: 288 cases.
List<PhotoCase> photoCases(Layout layout) {
  final List<PhotoCase> cases = <PhotoCase>[];
  int n = 0;
  for (final StampFormat format in StampFormat.values) {
    for (final bool geotag in <bool>[false, true]) {
      for (final bool subs in <bool>[false, true]) {
        for (final VideoOrientation orientation in VideoOrientation.values) {
          for (final VideoEncoder encoder in h264Encoders) {
            for (final double seconds in photoDurations) {
              n++;
              final String album = n.isEven ? 'Default' : 'My Trip';
              cases.add((
                label:
                    '${format.name} geotag:$geotag subs:$subs '
                    '${orientation.name} ${encoder.name} ${seconds}s',
                request: PhotoRender(
                  photoPath: '${layout.cache}/picker $n/IMG_$n.HEIC',
                  durationSeconds: seconds,
                  outputFileName: '2026-09-28.mp4',
                  stampText: 'unused by the argv',
                  stampStyle: StampStyle(
                    format: format,
                    rgb: colors[n % colors.length],
                    outline: n % 3 != 0,
                  ),
                  legacyStampFont: false,
                  location: geotag
                      ? ClipLocation(
                          enabled: true,
                          text: places[n % places.length],
                          latitude: 48.8566,
                          longitude: 2.3522,
                        )
                      : const ClipLocation.off(),
                  subtitles: subs ? 'Sunday market' : '',
                  format: ClipFormat.legacy(orientation),
                  albumLabel: album,
                ),
                files: filesFor(layout, album),
                encoder: encoder,
              ));
            }
          }
        }
      }
    }
  }
  return cases;
}

List<String> videoArgv(VideoCase c) => SaveClipCommand.video(
  c.request,
  files: c.files,
  encoder: c.encoder,
  addSilentAudio: c.silent,
);

List<String> photoArgv(PhotoCase c) =>
    SaveClipCommand.photo(c.request, files: c.files, encoder: c.encoder);

// The literal pieces every legacy argv is made of.

const Map<VideoOrientation, String> canvasOf = <VideoOrientation, String>{
  VideoOrientation.landscape:
      'scale=1920:1080:force_original_aspect_ratio=decrease,'
      'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black',
  VideoOrientation.portrait:
      'scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920',
};

const Map<VideoEncoder, List<String>> encoderArgs =
    <VideoEncoder, List<String>>{
      VideoEncoder.libx264: <String>[
        '-c:v', 'libx264', '-crf', '20', '-preset', 'medium', //
      ],
      VideoEncoder.videoToolbox: <String>[
        '-c:v', 'h264_videotoolbox', '-b:v', '12000k', //
        '-profile:v', 'high', '-allow_sw', '1',
      ],
      VideoEncoder.mediaCodec: <String>[
        '-c:v', 'h264_mediacodec', '-b:v', '12000k', //
      ],
    };

const List<String> legacyAudio = <String>[
  '-r', '30', '-ac', '1', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k', //
];

const List<String> silentInput = <String>[
  '-f', 'lavfi', '-i', 'anullsrc=channel_layout=mono:sample_rate=48000', //
];

/// The keyframe times of the fixtures (10 frames from each end at 30 fps).
const Map<int, String> keyframesOf = <int, String>{
  1000: '0.3333,0.6666',
  1500: '0.3333,1.1666',
  2000: '0.3333,1.6666',
  3000: '0.3333,2.6666',
  5000: '0.3333,4.6666',
  10000: '0.3333,9.6666',
  10500: '0.3333,10.1666',
};

/// The inverse of an RGB colour, as the outline.
String hex(int rgb) => '0x${rgb.toRadixString(16).padLeft(6, '0')}';

/// The two drawtexts of [style] at the legacy size, the place one with
/// [geotag].
String stamps(
  StampStyle style, {
  required String font,
  required String dateText,
  required String locationText,
  required bool geotag,
}) {
  final String colour =
      "fontsize=40.0:fontcolor='${hex(style.rgb)}':"
      'borderw=${style.outline ? '1.0' : '0.0'}:'
      'bordercolor=${hex(style.rgb ^ 0xFFFFFF)}';
  final String date = switch (style.format) {
    StampFormat.numeric =>
      'drawtext=fontfile=$font:textfile=$dateText:$colour:'
          'x=w-tw-40:y=40:expansion=none',
    StampFormat.written =>
      'drawtext=fontfile=$font:textfile=$dateText:$colour:'
          'x=40:y=h-th-40:expansion=none',
  };
  final String place = geotag
      ? ', drawtext=textfile=$locationText:fontfile=$font:$colour:'
            'x=w-tw-40:y=h-th-40:expansion=none'
      : '';
  return '$date$place';
}

/// The `location` tag's value: `<±lat><±lon>/<place>` with the place's
/// double quotes escaped as the save's `LocationTag` writes them.
String locationTag(ClipLocation location) =>
    '${location.latitude! >= 0 ? '+' : ''}${location.latitude}'
    '${location.longitude! >= 0 ? '+' : ''}${location.longitude}'
    '/${location.text!.replaceAll('"', r'\"')}';

/// The legacy video argv of [c], from the literal pieces.
List<String> expectedVideo(VideoCase c) {
  final VideoRender r = c.request;
  final bool geotag = r.location.enabled;
  final bool subs = r.subtitles.isNotEmpty;
  return <String>[
    '-i', c.files.subtitles, //
    '-ss', '${r.trimStartMs}ms', '-to', '${r.trimEndMs}ms',
    '-i', r.sourcePath,
    if (c.silent) ...<String>[...silentInput, '-shortest'],
    '-metadata', 'artist=One Second Diary (v1.5)',
    '-metadata', 'album=${r.albumLabel}',
    '-metadata',
    if (r.fromRecording)
      'comment=origin=osd_recording'
    else
      'comment=origin=gallery',
    if (geotag) ...<String>['-metadata', 'location=${locationTag(r.location)}'],
    '-vf',
    '[in]${canvasOf[r.orientation]},'
        '${stamps(r.stampStyle, font: c.files.font, dateText: c.files.dateText, locationText: c.files.locationText, geotag: geotag)}'
        '[out]',
    ...legacyAudio,
    ...encoderArgs[c.encoder]!,
    '-pix_fmt', 'yuv420p',
    '-force_key_frames', keyframesOf[r.trimEndMs - r.trimStartMs]!,
    if (subs) ...<String>['-c:s', 'mov_text'],
    '-map', '1:v',
    '-map',
    if (c.silent) '2:a' else '1:a?',
    if (subs) ...<String>['-map', '0:s', '-disposition:s:0', 'default'],
    c.files.output, '-y',
  ];
}

/// The legacy photo argv of [c], from the literal pieces.
List<String> expectedPhoto(PhotoCase c) {
  final PhotoRender r = c.request;
  final bool geotag = r.location.enabled;
  final bool subs = r.subtitles.isNotEmpty;
  return <String>[
    '-i', c.files.subtitles, //
    '-loop', '1', '-framerate', '30',
    '-i', r.photoPath,
    ...silentInput,
    '-metadata', 'artist=One Second Diary (v1.5)',
    '-metadata', 'album=${r.albumLabel}',
    '-metadata', 'comment=origin=gallery_photo',
    if (geotag) ...<String>['-metadata', 'location=${locationTag(r.location)}'],
    '-vf',
    '[in]${canvasOf[r.orientation]},'
        '${stamps(r.stampStyle, font: c.files.font, dateText: c.files.dateText, locationText: c.files.locationText, geotag: geotag)}'
        '[out]',
    ...legacyAudio,
    ...encoderArgs[c.encoder]!,
    '-pix_fmt', 'yuv420p',
    '-force_key_frames', keyframesOf[(r.durationSeconds * 1000).round()]!,
    '-t', '${r.durationSeconds}',
    if (subs) ...<String>['-c:s', 'mov_text'],
    '-map', '1:v', '-map', '2:a',
    if (subs) ...<String>['-map', '0:s', '-disposition:s:0', 'default'],
    c.files.output, '-y',
  ];
}

final String aScratch = '${android.cache}/scratch/job-1';
final String iScratch = '${ios.internal}/scratch job';
final String aFont = '${android.internal}/YuseiMagic-Regular.v1.ttf';
final String iFont = '${ios.internal}/YuseiMagic-Regular.v1.ttf';

/// File locations with the text files and the font in the internal folder,
/// the clip written straight into the videos folder.
const String v17Internal =
    '/data/user/0/com.kylekun.one_second_diary/app_flutter';
const String v17Videos = '/storage/emulated/0/DCIM/OneSecondDiary/';
const ClipRenderFiles v17Files = ClipRenderFiles(
  subtitles: '$v17Internal/subtitles.srt',
  font: '$v17Internal/magic.ttf',
  dateText: '$v17Internal/date.txt',
  locationText: '$v17Internal/location.txt',
  output: '${v17Videos}2026-09-28.mp4',
);
const StampStyle whiteNumeric = StampStyle(
  format: StampFormat.numeric,
  rgb: 0xFFFFFF,
  outline: true,
);

/// The Ultra preset: 4K60 HEVC stereo.
const ClipFormat ultra = ClipFormat(
  tier: ResolutionTier.p2160,
  orientation: VideoOrientation.landscape,
  codec: VideoCodec.hevc,
  fps: FrameRate.f60,
  channels: AudioChannels.stereo,
  range: DynamicRange.sdr,
);

/// The Smaller files preset on a portrait canvas: 1080p30 HEVC stereo.
const ClipFormat smallerFilesPortrait = ClipFormat(
  tier: ResolutionTier.p1080,
  orientation: VideoOrientation.portrait,
  codec: VideoCodec.hevc,
  fps: FrameRate.f30,
  channels: AudioChannels.stereo,
  range: DynamicRange.sdr,
);

/// 720p H.264 30 mono, landscape.
const ClipFormat small = ClipFormat(
  tier: ResolutionTier.p720,
  orientation: VideoOrientation.landscape,
  codec: VideoCodec.h264,
  fps: FrameRate.f30,
  channels: AudioChannels.mono,
  range: DynamicRange.sdr,
);

/// Range conversions, letter for letter (also pinned in range_filter_test): an HDR
/// source into an SDR profile, an SDR source into an HLG one, a PQ source into an HLG one.
const String hdrToSdr =
    'zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,'
    'tonemap=hable,zscale=t=bt709:m=bt709:r=tv,format=yuv420p';
const String sdrToHlg =
    'zscale=pin=bt709:tin=bt709:min=bt709:t=linear:npl=100,'
    'format=gbrpf32le,exposure=exposure=-2.3,zscale=p=bt2020,'
    'zscale=t=arib-std-b67:m=bt2020nc:r=tv:npl=1000,format=yuv420p10le';
const String pqToHlg =
    'zscale=t=linear:npl=1000,format=gbrpf32le,'
    'zscale=t=arib-std-b67:m=bt2020nc:r=tv:npl=1000,format=yuv420p10le';

/// The HLG output settings: 10-bit p010le, the BT.2100 tags, hvc1.
const List<String> hlgOutput = <String>[
  '-pix_fmt', 'p010le', //
  '-color_primaries', 'bt2020', '-color_trc', 'arib-std-b67',
  '-colorspace', 'bt2020nc',
  '-tag:v', 'hvc1',
];

/// 1080p30 HEVC stereo HLG, landscape.
const ClipFormat hlg1080 = ClipFormat(
  tier: ResolutionTier.p1080,
  orientation: VideoOrientation.landscape,
  codec: VideoCodec.hevc,
  fps: FrameRate.f30,
  channels: AudioChannels.stereo,
  range: DynamicRange.hlg,
);

/// An imported video whose probe said [transfer] of its colour.
VideoRender hdrImport(ClipFormat format, {required String? transfer}) =>
    VideoRender(
      sourcePath: '/c/picker 1/IMG_1.MOV',
      fromRecording: false,
      imported: true,
      trimStartMs: 0,
      trimEndMs: 1500,
      outputFileName: '2026-09-28.mp4',
      stampText: '',
      stampStyle: whiteNumeric,
      legacyStampFont: false,
      location: const ClipLocation.off(),
      subtitles: '',
      format: format,
      albumLabel: 'Default',
      sourceColorTransfer: transfer,
    );

extension on ClipFormat {
  ClipFormat copyWithTier(ResolutionTier tier) => ClipFormat(
    tier: tier,
    orientation: orientation,
    codec: codec,
    fps: fps,
    channels: channels,
    range: range,
  );
}

VideoRender recordingIn(ClipFormat format, {SourceFrame? frame}) => VideoRender(
  sourcePath: '/c/REC.mp4',
  fromRecording: true,
  trimStartMs: 0,
  trimEndMs: 1500,
  outputFileName: '2026-09-28.mp4',
  stampText: '',
  stampStyle: whiteNumeric,
  legacyStampFont: false,
  location: const ClipLocation.off(),
  subtitles: '',
  format: format,
  albumLabel: 'Default',
  frame: frame,
);

void main() {
  // Between them these rows pin, element by element: the SRT as input 0, the input-side
  // -ss/-to in whole ms, the tags and origins, the location tag, the canvas pad/crop,
  // drawtext through textfile=, -r 30, mono AAC 48 kHz 256k, every encoder's args,
  // -pix_fmt yuv420p, the silent track of a silent gallery video (anullsrc + -shortest,
  // mapped 2:a), the photo's -loop 1 -framerate 30 and -t, the default mov_text stream
  // from input 0, and the keyframes after the encode settings.
  test('readable cases: the argv v1.7 handed ffmpeg, plus the D27 '
      'keyframes and the D29 preset', () {
    VideoCase video(Layout layout, String label) =>
        videoCases(layout).singleWhere((VideoCase c) => c.label == label);
    PhotoCase photo(Layout layout, String label) =>
        photoCases(layout).singleWhere((PhotoCase c) => c.label == label);

    final List<(String, List<String>, List<String>)> cases =
        <(String, List<String>, List<String>)>[
          (
            'Android recording, numeric, landscape, libx264, in a profile',
            videoArgv(
              video(
                android,
                'numeric geotag:false subs:false recording landscape libx264',
              ),
            ),
            <String>[
              '-i', '$aScratch/subtitles.srt', //
              '-ss', '1234ms', '-to', '2734ms',
              '-i', '${android.cache}/REC_1.mp4',
              '-metadata', 'artist=One Second Diary (v1.5)',
              '-metadata', 'album=My Trip',
              '-metadata', 'comment=origin=osd_recording',
              '-vf',
              '[in]scale=1920:1080:force_original_aspect_ratio=decrease,'
                  'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,'
                  'drawtext=fontfile=$aFont:textfile=$aScratch/date.txt:'
                  "fontsize=40.0:fontcolor='0xe53935':borderw=1.0:"
                  'bordercolor=0x1ac6ca:x=w-tw-40:y=40:expansion=none[out]',
              '-r', '30', '-ac', '1', '-ar', '48000', //
              '-c:a', 'aac', '-b:a', '256k',
              '-c:v', 'libx264', '-crf', '20', '-preset', 'medium',
              '-pix_fmt',
              'yuv420p',
              '-force_key_frames',
              '0.3333,1.1666',
              '-map',
              '1:v',
              '-map',
              '1:a?',
              '${android.videos}Profiles/My Trip/2026-09-28-2.mp4', '-y',
            ],
          ),
          (
            'Android gallery without audio, written, geotag, subtitles, '
                'portrait, MediaCodec',
            videoArgv(
              video(
                android,
                'written geotag:true subs:true galleryWithoutAudio portrait '
                'mediaCodec',
              ),
            ),
            <String>[
              '-i', '$aScratch/subtitles.srt', //
              '-ss', '0ms', '-to', '1500ms',
              '-i', '${android.cache}/picker 144/IMG_144.MOV',
              '-f', 'lavfi',
              '-i', 'anullsrc=channel_layout=mono:sample_rate=48000',
              '-shortest',
              '-metadata', 'artist=One Second Diary (v1.5)',
              '-metadata', 'album=Default',
              '-metadata', 'comment=origin=gallery',
              '-metadata', r'location=+35.7148+139.7967/Tokyo, \"Japan\"',
              '-vf',
              '[in]scale=1080:1920:force_original_aspect_ratio=increase,'
                  'crop=1080:1920,'
                  'drawtext=fontfile=$aFont:textfile=$aScratch/date.txt:'
                  "fontsize=40.0:fontcolor='0xffffff':borderw=0.0:"
                  'bordercolor=0x000000:x=40:y=h-th-40:expansion=none, '
                  'drawtext=textfile=$aScratch/location.txt:fontfile=$aFont:'
                  "fontsize=40.0:fontcolor='0xffffff':borderw=0.0:"
                  'bordercolor=0x000000:x=w-tw-40:y=h-th-40:'
                  'expansion=none[out]',
              '-r', '30', '-ac', '1', '-ar', '48000', //
              '-c:a', 'aac', '-b:a', '256k',
              '-c:v', 'h264_mediacodec', '-b:v', '12000k',
              '-pix_fmt',
              'yuv420p',
              '-force_key_frames',
              '0.3333,1.1666',
              '-c:s',
              'mov_text',
              '-map', '1:v', '-map', '2:a', '-map', '0:s',
              '-disposition:s:0', 'default',
              '$aScratch/2026-09-28.mp4', '-y',
            ],
          ),
          (
            'iOS gallery with audio, written, geotag, subtitles, landscape, '
                'VideoToolbox: every path with a space whole',
            videoArgv(
              video(
                ios,
                'written geotag:true subs:true galleryWithAudio landscape '
                'videoToolbox',
              ),
            ),
            <String>[
              '-i', '$iScratch/subtitles.srt', //
              '-ss', '0ms', '-to', '10500ms',
              '-i', '${ios.cache}/picker 134/IMG_134.MOV',
              '-metadata', 'artist=One Second Diary (v1.5)',
              '-metadata', 'album=Default',
              '-metadata', 'comment=origin=gallery',
              '-metadata', 'location=+35.7148+139.7967/São Paulo, Brazil',
              '-vf',
              '[in]scale=1920:1080:force_original_aspect_ratio=decrease,'
                  'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,'
                  'drawtext=fontfile=$iFont:textfile=$iScratch/date.txt:'
                  "fontsize=40.0:fontcolor='0x212121':borderw=1.0:"
                  'bordercolor=0xdedede:x=40:y=h-th-40:expansion=none, '
                  'drawtext=textfile=$iScratch/location.txt:fontfile=$iFont:'
                  "fontsize=40.0:fontcolor='0x212121':borderw=1.0:"
                  'bordercolor=0xdedede:x=w-tw-40:y=h-th-40:'
                  'expansion=none[out]',
              '-r', '30', '-ac', '1', '-ar', '48000', //
              '-c:a', 'aac', '-b:a', '256k',
              '-c:v', 'h264_videotoolbox', '-b:v', '12000k',
              '-profile:v', 'high', '-allow_sw', '1',
              '-pix_fmt',
              'yuv420p',
              '-force_key_frames',
              '0.3333,10.1666',
              '-c:s',
              'mov_text',
              '-map', '1:v', '-map', '1:a?', '-map', '0:s',
              '-disposition:s:0', 'default',
              '$iScratch/2026-09-28.mp4', '-y',
            ],
          ),
          (
            'Android photo, numeric, landscape, libx264, 1.5 s',
            photoArgv(
              photo(
                android,
                'numeric geotag:false subs:false landscape libx264 1.5s',
              ),
            ),
            <String>[
              '-i', '$aScratch/subtitles.srt', //
              '-loop', '1', '-framerate', '30',
              '-i', '${android.cache}/picker 2/IMG_2.HEIC',
              '-f', 'lavfi',
              '-i', 'anullsrc=channel_layout=mono:sample_rate=48000',
              '-metadata', 'artist=One Second Diary (v1.5)',
              '-metadata', 'album=Default',
              '-metadata', 'comment=origin=gallery_photo',
              '-vf',
              '[in]scale=1920:1080:force_original_aspect_ratio=decrease,'
                  'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,'
                  'drawtext=fontfile=$aFont:textfile=$aScratch/date.txt:'
                  "fontsize=40.0:fontcolor='0x212121':borderw=1.0:"
                  'bordercolor=0xdedede:x=w-tw-40:y=40:expansion=none[out]',
              '-r', '30', '-ac', '1', '-ar', '48000', //
              '-c:a', 'aac', '-b:a', '256k',
              '-c:v', 'libx264', '-crf', '20', '-preset', 'medium',
              '-pix_fmt',
              'yuv420p',
              '-force_key_frames',
              '0.3333,1.1666',
              '-t',
              '1.5',
              '-map', '1:v', '-map', '2:a',
              '$aScratch/2026-09-28.mp4', '-y',
            ],
          ),
          (
            'iOS photo, written, geotag without a place, subtitles, '
                'portrait, VideoToolbox, in a profile',
            photoArgv(
              photo(
                ios,
                'written geotag:true subs:true portrait videoToolbox 2.0s',
              ),
            ),
            <String>[
              '-i', '$iScratch/subtitles.srt', //
              '-loop', '1', '-framerate', '30',
              '-i', '${ios.cache}/picker 279/IMG_279.HEIC',
              '-f', 'lavfi',
              '-i', 'anullsrc=channel_layout=mono:sample_rate=48000',
              '-metadata', 'artist=One Second Diary (v1.5)',
              '-metadata', 'album=My Trip',
              '-metadata', 'comment=origin=gallery_photo',
              '-metadata', 'location=+48.8566+2.3522/',
              '-vf',
              '[in]scale=1080:1920:force_original_aspect_ratio=increase,'
                  'crop=1080:1920,'
                  'drawtext=fontfile=$iFont:textfile=$iScratch/date.txt:'
                  "fontsize=40.0:fontcolor='0x0a0b0c':borderw=0.0:"
                  'bordercolor=0xf5f4f3:x=40:y=h-th-40:expansion=none, '
                  'drawtext=textfile=$iScratch/location.txt:fontfile=$iFont:'
                  "fontsize=40.0:fontcolor='0x0a0b0c':borderw=0.0:"
                  'bordercolor=0xf5f4f3:x=w-tw-40:y=h-th-40:'
                  'expansion=none[out]',
              '-r', '30', '-ac', '1', '-ar', '48000', //
              '-c:a', 'aac', '-b:a', '256k',
              '-c:v', 'h264_videotoolbox', '-b:v', '12000k',
              '-profile:v', 'high', '-allow_sw', '1',
              '-pix_fmt',
              'yuv420p',
              '-force_key_frames',
              '0.3333,1.6666',
              '-t',
              '2.0',
              '-c:s',
              'mov_text',
              '-map', '1:v', '-map', '2:a', '-map', '0:s',
              '-disposition:s:0', 'default',
              '${ios.videos}Profiles/My Trip/2026-09-28-2.mp4', '-y',
            ],
          ),
          (
            'a recording: srt input 0, input-side trim, stamp, libx264',
            SaveClipCommand.video(
              const VideoRender(
                sourcePath:
                    '/data/user/0/com.kylekun.one_second_diary/cache/'
                    'REC123.mp4',
                fromRecording: true,
                trimStartMs: 0,
                trimEndMs: 1500,
                outputFileName: '2026-09-28.mp4',
                stampText: '09/28/2026',
                stampStyle: whiteNumeric,
                legacyStampFont: false,
                location: ClipLocation.off(),
                subtitles: '',
                format: ClipFormat.legacy(VideoOrientation.landscape),
                albumLabel: 'Default',
              ),
              files: v17Files,
              encoder: VideoEncoder.libx264,
              addSilentAudio: false,
            ),
            <String>[
              '-i', '$v17Internal/subtitles.srt', //
              '-ss', '0ms', '-to', '1500ms',
              '-i',
              '/data/user/0/com.kylekun.one_second_diary/cache/REC123.mp4',
              '-metadata', 'artist=One Second Diary (v1.5)',
              '-metadata', 'album=Default',
              '-metadata', 'comment=origin=osd_recording',
              '-vf',
              '[in]scale=1920:1080:force_original_aspect_ratio=decrease,'
                  'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,'
                  'drawtext=fontfile=$v17Internal/magic.ttf:'
                  'textfile=$v17Internal/date.txt:fontsize=40.0:'
                  "fontcolor='0xffffff':borderw=1.0:bordercolor=0x000000:"
                  'x=w-tw-40:y=40:expansion=none[out]',
              '-r', '30', '-ac', '1', '-ar', '48000', //
              '-c:a', 'aac', '-b:a', '256k',
              '-c:v', 'libx264', '-crf', '20', '-preset', 'medium',
              '-pix_fmt',
              'yuv420p',
              '-force_key_frames',
              '0.3333,1.1666',
              '-map',
              '1:v',
              '-map',
              '1:a?',
              '${v17Videos}2026-09-28.mp4', '-y',
            ],
          ),
          // A still looped at 30 fps for -t seconds, always a silent track.
          (
            'a written-date photo at v1.7 file locations',
            SaveClipCommand.photo(
              const PhotoRender(
                photoPath: '/storage/emulated/0/DCIM/Camera/IMG_1.jpg',
                durationSeconds: 1.5,
                outputFileName: '2026-09-20.mp4',
                stampText: 'September 20, 2026',
                stampStyle: StampStyle(
                  format: StampFormat.written,
                  rgb: 0xFFFFFF,
                  outline: true,
                ),
                legacyStampFont: false,
                location: ClipLocation.off(),
                subtitles: '',
                format: ClipFormat.legacy(VideoOrientation.landscape),
                albumLabel: 'Default',
              ),
              files: v17Files,
              encoder: VideoEncoder.libx264,
            ),
            <String>[
              '-i', '$v17Internal/subtitles.srt', //
              '-loop', '1', '-framerate', '30',
              '-i', '/storage/emulated/0/DCIM/Camera/IMG_1.jpg',
              '-f', 'lavfi',
              '-i', 'anullsrc=channel_layout=mono:sample_rate=48000',
              '-metadata', 'artist=One Second Diary (v1.5)',
              '-metadata', 'album=Default',
              '-metadata', 'comment=origin=gallery_photo',
              '-vf',
              '[in]scale=1920:1080:force_original_aspect_ratio=decrease,'
                  'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,'
                  'drawtext=fontfile=$v17Internal/magic.ttf:'
                  'textfile=$v17Internal/date.txt:fontsize=40.0:'
                  "fontcolor='0xffffff':borderw=1.0:bordercolor=0x000000:"
                  'x=40:y=h-th-40:expansion=none[out]',
              '-r', '30', '-ac', '1', '-ar', '48000', //
              '-c:a', 'aac', '-b:a', '256k',
              '-c:v', 'libx264', '-crf', '20', '-preset', 'medium',
              '-pix_fmt',
              'yuv420p',
              '-force_key_frames',
              '0.3333,1.1666',
              '-t',
              '1.5',
              '-map', '1:v', '-map', '2:a',
              '${v17Videos}2026-09-28.mp4', '-y',
            ],
          ),
        ];
    for (final (String name, List<String> argv, List<String> v17) in cases) {
      expect(argv, v17, reason: name);
    }
  });

  // The whole legacy matrix, element by element, composed from the literal pieces above
  // (no engine code builds an expectation).
  test("every legacy video save is v1.7's argv plus the D27 keyframes and "
      'the D29 preset, Android and iOS', () {
    for (final Layout layout in <Layout>[android, ios]) {
      final List<VideoCase> cases = videoCases(layout);
      expect(cases, hasLength(144));
      for (final VideoCase c in cases) {
        expect(
          videoArgv(c),
          expectedVideo(c),
          reason: '${layout.name} ${c.label}',
        );
      }
    }
  });

  test("every legacy photo save is v1.7's argv plus the D27 keyframes and "
      'the D29 preset, Android and iOS', () {
    for (final Layout layout in <Layout>[android, ios]) {
      final List<PhotoCase> cases = photoCases(layout);
      expect(cases, hasLength(288));
      for (final PhotoCase c in cases) {
        expect(
          photoArgv(c),
          expectedPhoto(c),
          reason: '${layout.name} ${c.label}',
        );
      }
    }
  });

  test('photo durations print as v1.7 printed them (Dart doubles)', () {
    final List<String> printed = <String>[
      for (final double seconds in photoDurations)
        () {
          final List<String> argv = SaveClipCommand.photo(
            PhotoRender(
              photoPath: '/p.jpg',
              durationSeconds: seconds,
              outputFileName: '2026-09-28.mp4',
              stampText: '',
              stampStyle: whiteNumeric,
              legacyStampFont: false,
              location: const ClipLocation.off(),
              subtitles: '',
              format: const ClipFormat.legacy(VideoOrientation.landscape),
              albumLabel: 'Default',
            ),
            files: filesFor(android, 'Default'),
            encoder: VideoEncoder.libx264,
          );
          return argv[argv.indexOf('-t') + 1];
        }(),
    ];
    expect(printed, <String>['1.0', '1.5', '2.0', '3.0', '5.0', '10.0']);
  });

  // A typed place without a fix gets no location tag: "+0+0/<place>" would be Null Island.
  // A place with only one coordinate is not tagged either; every typed place is still
  // burned in, and rides in the notes tag (`synopsis=place=…`) right before -vf so the
  // Diary and search still know it.
  test('a typed place without a fix: v1.7 minus the Null Island tag, plus '
      'the place in the notes tag', () {
    for (final ClipLocation location in <ClipLocation>[
      const ClipLocation(enabled: true, text: 'Paris'),
      const ClipLocation(enabled: true, text: 'Paris', latitude: 48.85),
      const ClipLocation(enabled: true, text: 'Paris', longitude: 2.35),
    ]) {
      expect(
        SaveClipCommand.video(
          VideoRender(
            sourcePath: '/c/REC.mp4',
            fromRecording: true,
            trimStartMs: 0,
            trimEndMs: 1500,
            outputFileName: '2026-09-28.mp4',
            stampText: '',
            stampStyle: whiteNumeric,
            legacyStampFont: false,
            location: location,
            subtitles: '',
            format: const ClipFormat.legacy(VideoOrientation.landscape),
            albumLabel: 'Default',
          ),
          files: filesFor(android, 'Default'),
          encoder: VideoEncoder.libx264,
          addSilentAudio: false,
        ),
        <String>[
          '-i', '$aScratch/subtitles.srt', //
          '-ss', '0ms', '-to', '1500ms', '-i', '/c/REC.mp4',
          '-metadata', 'artist=One Second Diary (v1.5)',
          '-metadata', 'album=Default',
          '-metadata', 'comment=origin=osd_recording',
          '-metadata', 'synopsis=place=Paris',
          '-vf',
          '[in]scale=1920:1080:force_original_aspect_ratio=decrease,'
              'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,'
              'drawtext=fontfile=$aFont:textfile=$aScratch/date.txt:'
              "fontsize=40.0:fontcolor='0xffffff':borderw=1.0:"
              'bordercolor=0x000000:x=w-tw-40:y=40:expansion=none, '
              'drawtext=textfile=$aScratch/location.txt:fontfile=$aFont:'
              "fontsize=40.0:fontcolor='0xffffff':borderw=1.0:"
              'bordercolor=0x000000:x=w-tw-40:y=h-th-40:expansion=none[out]',
          '-r', '30', '-ac', '1', '-ar', '48000', //
          '-c:a', 'aac', '-b:a', '256k',
          '-c:v', 'libx264', '-crf', '20', '-preset', 'medium',
          '-pix_fmt',
          'yuv420p',
          '-force_key_frames',
          '0.3333,1.1666',
          '-map',
          '1:v',
          '-map',
          '1:a?',
          '$aScratch/2026-09-28.mp4', '-y',
        ],
        reason: '(${location.latitude}, ${location.longitude})',
      );
    }
  });

  // Tags and the device note come right after the privacy and location tags, before -vf,
  // and only when the request carries them.
  test('a tagged clip with the device note: the keywords and synopsis tags '
      'after the privacy tag and before -vf; without them, not one new '
      'element', () {
    const String note =
        'device=Android 14 (SDK 34), Google Pixel 8;app=2.0.0;'
        'recorded=2026-09-28T14:33:21.000+02:00';
    const VideoRender plain = VideoRender(
      sourcePath: '/c/REC.mp4',
      fromRecording: true,
      trimStartMs: 0,
      trimEndMs: 1500,
      outputFileName: '2026-09-28.mp4',
      stampText: '',
      stampStyle: whiteNumeric,
      legacyStampFont: false,
      location: ClipLocation(
        enabled: true,
        text: 'Tokyo, Japan',
        latitude: 35.7148,
        longitude: 139.7967,
      ),
      subtitles: '',
      format: ClipFormat.legacy(VideoOrientation.landscape),
      albumLabel: 'Default',
      isPrivate: true,
    );
    final VideoRender tagged = plain
        .withTags(const <String>['bread', 'sour dough'])
        .withDeviceTag(note);
    List<String> argvOf(VideoRender request) => SaveClipCommand.video(
      request,
      files: filesFor(android, 'Default'),
      encoder: VideoEncoder.libx264,
      addSilentAudio: false,
    );
    final List<String> upToTheTags = <String>[
      '-i', '$aScratch/subtitles.srt', //
      '-ss', '0ms', '-to', '1500ms', '-i', '/c/REC.mp4',
      '-metadata', 'artist=One Second Diary (v1.5)',
      '-metadata', 'album=Default',
      '-metadata', 'comment=origin=osd_recording',
      '-metadata', 'location=+35.7148+139.7967/Tokyo, Japan',
      '-metadata', 'description=private=1',
    ];
    const List<String> theTags = <String>[
      '-metadata', 'keywords=bread,sour dough', //
      '-metadata', 'synopsis=$note',
    ];
    final List<String> fromTheFilter = <String>[
      '-vf',
      '[in]scale=1920:1080:force_original_aspect_ratio=decrease,'
          'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,'
          'drawtext=fontfile=$aFont:textfile=$aScratch/date.txt:'
          "fontsize=40.0:fontcolor='0xffffff':borderw=1.0:"
          'bordercolor=0x000000:x=w-tw-40:y=40:expansion=none, '
          'drawtext=textfile=$aScratch/location.txt:fontfile=$aFont:'
          "fontsize=40.0:fontcolor='0xffffff':borderw=1.0:"
          'bordercolor=0x000000:x=w-tw-40:y=h-th-40:expansion=none[out]',
      '-r', '30', '-ac', '1', '-ar', '48000', //
      '-c:a', 'aac', '-b:a', '256k',
      '-c:v', 'libx264', '-crf', '20', '-preset', 'medium',
      '-pix_fmt',
      'yuv420p',
      '-force_key_frames',
      '0.3333,1.1666',
      '-map',
      '1:v',
      '-map',
      '1:a?',
      '$aScratch/2026-09-28.mp4', '-y',
    ];

    expect(argvOf(tagged), <String>[
      ...upToTheTags,
      ...theTags,
      ...fromTheFilter,
    ]);
    expect(argvOf(plain), <String>[...upToTheTags, ...fromTheFilter]);
  });

  // A clip saved without sound takes the silent track exactly as a silent gallery video
  // does (anullsrc, -shortest, mapped 2:a) and its notes tag says muted=1; a photo, silent
  // already, only gains the notes.
  test('a video saved without sound: the silent track in the audio\'s '
      'place and synopsis=muted=1; a photo: the notes alone', () {
    const VideoRender recording = VideoRender(
      sourcePath: '/c/REC.mp4',
      fromRecording: true,
      trimStartMs: 0,
      trimEndMs: 1500,
      outputFileName: '2026-09-28.mp4',
      stampText: '',
      stampStyle: whiteNumeric,
      legacyStampFont: false,
      location: ClipLocation.off(),
      subtitles: '',
      format: ClipFormat.legacy(VideoOrientation.landscape),
      albumLabel: 'Default',
      mute: true,
    );
    final List<String> head = <String>[
      '-i', '$aScratch/subtitles.srt', //
      '-ss', '0ms', '-to', '1500ms', '-i', '/c/REC.mp4',
      '-f', 'lavfi',
      '-i', 'anullsrc=channel_layout=mono:sample_rate=48000',
      '-shortest',
      '-metadata', 'artist=One Second Diary (v1.5)',
      '-metadata', 'album=Default',
      '-metadata', 'comment=origin=osd_recording',
    ];
    final List<String> stampAndEncode = <String>[
      '-vf',
      '[in]scale=1920:1080:force_original_aspect_ratio=decrease,'
          'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,'
          'drawtext=fontfile=$aFont:textfile=$aScratch/date.txt:'
          "fontsize=40.0:fontcolor='0xffffff':borderw=1.0:"
          'bordercolor=0x000000:x=w-tw-40:y=40:expansion=none[out]',
      '-r', '30', '-ac', '1', '-ar', '48000', //
      '-c:a', 'aac', '-b:a', '256k',
      '-c:v', 'libx264', '-crf', '20', '-preset', 'medium',
      '-pix_fmt', 'yuv420p',
      '-force_key_frames', '0.3333,1.1666',
    ];
    List<String> argvOf(VideoRender request) => SaveClipCommand.video(
      request,
      files: filesFor(android, 'Default'),
      encoder: VideoEncoder.libx264,
      addSilentAudio: false,
    );
    expect(argvOf(recording), <String>[
      ...head,
      '-metadata',
      'synopsis=muted=1',
      ...stampAndEncode,
      '-map',
      '1:v',
      '-map',
      '2:a',
      '$aScratch/2026-09-28.mp4',
      '-y',
    ]);
    expect(argvOf(recording.withDeviceTag('device=Pixel')), <String>[
      ...head,
      '-metadata',
      'synopsis=device=Pixel;muted=1',
      ...stampAndEncode,
      '-map',
      '1:v',
      '-map',
      '2:a',
      '$aScratch/2026-09-28.mp4',
      '-y',
    ]);

    const PhotoRender photo = PhotoRender(
      photoPath: '/c/IMG.HEIC',
      durationSeconds: 1.5,
      outputFileName: '2026-09-28.mp4',
      stampText: '',
      stampStyle: whiteNumeric,
      legacyStampFont: false,
      location: ClipLocation.off(),
      subtitles: '',
      format: ClipFormat.legacy(VideoOrientation.landscape),
      albumLabel: 'Default',
      mute: true,
    );
    expect(
      SaveClipCommand.photo(
        photo,
        files: filesFor(android, 'Default'),
        encoder: VideoEncoder.libx264,
      ),
      <String>[
        '-i', '$aScratch/subtitles.srt', //
        '-loop', '1', '-framerate', '30', '-i', '/c/IMG.HEIC',
        '-f', 'lavfi',
        '-i', 'anullsrc=channel_layout=mono:sample_rate=48000',
        '-metadata', 'artist=One Second Diary (v1.5)',
        '-metadata', 'album=Default',
        '-metadata', 'comment=origin=gallery_photo',
        '-metadata', 'synopsis=muted=1',
        ...stampAndEncode,
        '-t', '1.5',
        '-map', '1:v', '-map', '2:a',
        '$aScratch/2026-09-28.mp4', '-y',
      ],
    );
  });

  // GOLDEN: a non-legacy format. The Ultra preset (4K60 HEVC stereo): the v2 marker, the 4K
  // canvas with the stamp at 80 px, -r 60, stereo AAC, the HEVC encoder at the table's
  // bitrate, the pixel format and hvc1 tag, keyframes 20 frames (333 ms) from each end;
  // the silent track of a muted save in stereo.
  test('the Ultra preset: 4K canvas, 80 px stamp, -r 60, stereo, HEVC '
      'hvc1, the v2 marker', () {
    expect(
      SaveClipCommand.video(
        recordingIn(ultra),
        files: filesFor(android, 'Default'),
        encoder: VideoEncoder.hevcMediaCodec,
        addSilentAudio: false,
      ),
      <String>[
        '-i', '$aScratch/subtitles.srt', //
        '-ss', '0ms', '-to', '1500ms', '-i', '/c/REC.mp4',
        '-metadata', 'artist=One Second Diary (v2)',
        '-metadata', 'album=Default',
        '-metadata', 'comment=origin=osd_recording',
        '-vf',
        '[in]scale=3840:2160:force_original_aspect_ratio=decrease,'
            'pad=3840:2160:(ow-iw)/2:(oh-ih)/2:black,'
            'drawtext=fontfile=$aFont:textfile=$aScratch/date.txt:'
            "fontsize=80.0:fontcolor='0xffffff':borderw=2.0:"
            'bordercolor=0x000000:x=w-tw-80:y=80:expansion=none[out]',
        '-r', '60', '-ac', '2', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
        '-c:v', 'hevc_mediacodec', '-b:v', '42000k',
        '-pix_fmt', 'yuv420p', '-tag:v', 'hvc1',
        '-force_key_frames', '0.3333,1.1666',
        '-map', '1:v', '-map', '1:a?',
        '$aScratch/2026-09-28.mp4', '-y',
      ],
    );
    const VideoRender muted = VideoRender(
      sourcePath: '/c/REC.mp4',
      fromRecording: true,
      trimStartMs: 0,
      trimEndMs: 1500,
      outputFileName: '2026-09-28.mp4',
      stampText: '',
      stampStyle: whiteNumeric,
      legacyStampFont: false,
      location: ClipLocation.off(),
      subtitles: '',
      format: ultra,
      albumLabel: 'Default',
      mute: true,
    );
    expect(
      SaveClipCommand.video(
        muted,
        files: filesFor(android, 'Default'),
        encoder: VideoEncoder.hevcMediaCodec,
        addSilentAudio: false,
      ),
      containsAllInOrder(<String>[
        '-f', 'lavfi', //
        '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
        '-shortest',
      ]),
    );
  });

  // GOLDEN: HEVC 1080p stereo on a portrait canvas with VideoToolbox (the
  // Smaller files preset on iOS): the 1080p stamp unchanged, -r 30,
  // stereo, `-profile:v main`, hvc1; and a photo at 60 fps (`-framerate
  // 60`, the keyframes 20 frames in), 720p with the 27 px stamp.
  test('HEVC 1080p stereo on VideoToolbox; a photo at 60 fps; 720p', () {
    expect(
      SaveClipCommand.video(
        recordingIn(smallerFilesPortrait),
        files: filesFor(ios, 'Default'),
        encoder: VideoEncoder.hevcVideoToolbox,
        addSilentAudio: false,
      ),
      <String>[
        '-i', '$iScratch/subtitles.srt', //
        '-ss', '0ms', '-to', '1500ms', '-i', '/c/REC.mp4',
        '-metadata', 'artist=One Second Diary (v2)',
        '-metadata', 'album=Default',
        '-metadata', 'comment=origin=osd_recording',
        '-vf',
        '[in]scale=1080:1920:force_original_aspect_ratio=increase,'
            'crop=1080:1920,'
            'drawtext=fontfile=$iFont:textfile=$iScratch/date.txt:'
            "fontsize=40.0:fontcolor='0xffffff':borderw=1.0:"
            'bordercolor=0x000000:x=w-tw-40:y=40:expansion=none[out]',
        '-r', '30', '-ac', '2', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
        '-c:v', 'hevc_videotoolbox', '-b:v', '8000k',
        '-profile:v', 'main', '-allow_sw', '1',
        '-pix_fmt', 'yuv420p', '-tag:v', 'hvc1',
        '-force_key_frames', '0.3333,1.1666',
        '-map', '1:v', '-map', '1:a?',
        '$iScratch/2026-09-28.mp4', '-y',
      ],
    );
    expect(
      SaveClipCommand.photo(
        const PhotoRender(
          photoPath: '/c/IMG.HEIC',
          durationSeconds: 2,
          outputFileName: '2026-09-28.mp4',
          stampText: '',
          stampStyle: whiteNumeric,
          legacyStampFont: false,
          location: ClipLocation.off(),
          subtitles: '',
          format: ultra,
          albumLabel: 'Default',
        ),
        files: filesFor(android, 'Default'),
        encoder: VideoEncoder.hevcMediaCodec,
      ),
      <String>[
        '-i', '$aScratch/subtitles.srt', //
        '-loop', '1', '-framerate', '60', '-i', '/c/IMG.HEIC',
        '-f', 'lavfi',
        '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
        '-metadata', 'artist=One Second Diary (v2)',
        '-metadata', 'album=Default',
        '-metadata', 'comment=origin=gallery_photo',
        '-vf',
        '[in]scale=3840:2160:force_original_aspect_ratio=decrease,'
            'pad=3840:2160:(ow-iw)/2:(oh-ih)/2:black,'
            'drawtext=fontfile=$aFont:textfile=$aScratch/date.txt:'
            "fontsize=80.0:fontcolor='0xffffff':borderw=2.0:"
            'bordercolor=0x000000:x=w-tw-80:y=80:expansion=none[out]',
        '-r', '60', '-ac', '2', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
        '-c:v', 'hevc_mediacodec', '-b:v', '42000k',
        '-pix_fmt', 'yuv420p', '-tag:v', 'hvc1',
        '-force_key_frames', '0.3333,1.6666',
        '-t', '2.0',
        '-map', '1:v', '-map', '2:a',
        '$aScratch/2026-09-28.mp4', '-y',
      ],
    );
    expect(
      SaveClipCommand.video(
        recordingIn(small),
        files: filesFor(android, 'Default'),
        encoder: VideoEncoder.mediaCodec,
        addSilentAudio: false,
      ),
      <String>[
        '-i', '$aScratch/subtitles.srt', //
        '-ss', '0ms', '-to', '1500ms', '-i', '/c/REC.mp4',
        '-metadata', 'artist=One Second Diary (v2)',
        '-metadata', 'album=Default',
        '-metadata', 'comment=origin=osd_recording',
        '-vf',
        '[in]scale=1280:720:force_original_aspect_ratio=decrease,'
            'pad=1280:720:(ow-iw)/2:(oh-ih)/2:black,'
            'drawtext=fontfile=$aFont:textfile=$aScratch/date.txt:'
            "fontsize=27.0:fontcolor='0xffffff':borderw=1.0:"
            'bordercolor=0x000000:x=w-tw-27:y=27:expansion=none[out]',
        '-r', '30', '-ac', '1', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
        '-c:v', 'h264_mediacodec', '-b:v', '5000k',
        '-pix_fmt', 'yuv420p',
        '-force_key_frames', '0.3333,1.1666',
        '-map', '1:v', '-map', '1:a?',
        '$aScratch/2026-09-28.mp4', '-y',
      ],
    );
  });

  // An imported video goes through the normal save with origin `import`; nothing else
  // differs from a gallery save.
  test('an imported video: origin=import, the gallery argv otherwise', () {
    const VideoRender imported = VideoRender(
      sourcePath: '/v/2026-09-28.mov',
      fromRecording: false,
      imported: true,
      trimStartMs: 0,
      trimEndMs: 1500,
      outputFileName: '2026-09-28.mp4',
      stampText: '',
      stampStyle: whiteNumeric,
      legacyStampFont: false,
      location: ClipLocation.off(),
      subtitles: '',
      format: ClipFormat.legacy(VideoOrientation.landscape),
      albumLabel: 'Default',
    );
    final List<String> argv = SaveClipCommand.video(
      imported,
      files: filesFor(android, 'Default'),
      encoder: VideoEncoder.libx264,
      addSilentAudio: false,
    );
    expect(
      argv,
      containsAllInOrder(<String>['-metadata', 'comment=origin=import']),
    );
    expect(argv, isNot(contains('comment=origin=gallery')));
    expect(imported.asPrivate().origin, imported.origin);
  });

  // GOLDEN: a frame takes the canvas fit's place. A black fill stays a `-vf` chain (scale,
  // crop, pad in whole pixels); a blur fill with bars is a `-filter_complex` graph from the
  // source's `[1:v]`, the stamps after the overlay, and `[v]` mapped in place of `1:v`. A
  // frame at cover gives no bars and the chain whatever the fill.
  test('a framed save: the black chain in -vf; the blur graph in '
      '-filter_complex with [v] mapped', () {
    const SourceFrame fitBlack = SourceFrame(
      frame: ClipFrame(scale: 0.5625),
      sourceWidth: 1920,
      sourceHeight: 1080,
    );
    const SourceFrame fitBlur = SourceFrame(
      frame: ClipFrame(scale: 0.5625, fill: FrameFill.blur),
      sourceWidth: 1920,
      sourceHeight: 1080,
    );
    const ClipFormat portrait = ClipFormat.legacy(VideoOrientation.portrait);
    final String stamp =
        'drawtext=fontfile=$aFont:textfile=$aScratch/date.txt:'
        "fontsize=40.0:fontcolor='0xffffff':borderw=1.0:"
        'bordercolor=0x000000:x=w-tw-40:y=40:expansion=none';
    final List<String> tags = <String>[
      '-metadata', 'artist=One Second Diary (v1.5)', //
      '-metadata', 'album=Default',
      '-metadata', 'comment=origin=osd_recording',
    ];
    final List<String> encode = <String>[
      '-r', '30', '-ac', '1', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k', //
      '-c:v', 'libx264', '-crf', '20', '-preset', 'medium',
      '-pix_fmt', 'yuv420p',
      '-force_key_frames', '0.3333,1.1666',
    ];
    expect(
      SaveClipCommand.video(
        recordingIn(portrait, frame: fitBlack),
        files: filesFor(android, 'Default'),
        encoder: VideoEncoder.libx264,
        addSilentAudio: false,
      ),
      <String>[
        '-i', '$aScratch/subtitles.srt', //
        '-ss', '0ms', '-to', '1500ms', '-i', '/c/REC.mp4',
        ...tags,
        '-vf', '[in]scale=1080:608,pad=1080:1920:0:656:black,$stamp[out]',
        ...encode,
        '-map', '1:v', '-map', '1:a?',
        '$aScratch/2026-09-28.mp4', '-y',
      ],
    );
    expect(
      SaveClipCommand.video(
        recordingIn(portrait, frame: fitBlur),
        files: filesFor(android, 'Default'),
        encoder: VideoEncoder.libx264,
        addSilentAudio: false,
      ),
      <String>[
        '-i', '$aScratch/subtitles.srt', //
        '-ss', '0ms', '-to', '1500ms', '-i', '/c/REC.mp4',
        ...tags,
        // REWRITTEN: the background blurs at the covering size ÷ 8 with
        // sigma 2.5 and is scaled back up (a full-size gblur made a 4K60
        // save take minutes); the same picture, a fraction of the work.
        '-filter_complex',
        '[1:v]split[bg][fg];'
            '[bg]scale=426:240,gblur=sigma=2.5,'
            'scale=3414:1920:flags=bilinear,crop=1080:1920:1168:0[b];'
            '[fg]scale=1080:608[f];'
            '[b][f]overlay=0:656,$stamp[v]',
        ...encode,
        '-map', '[v]', '-map', '1:a?',
        '$aScratch/2026-09-28.mp4', '-y',
      ],
    );
    // A photo framed at 2× on the same-shape canvas: the middle quarter,
    // no bars, the chain whatever the fill.
    expect(
      SaveClipCommand.photo(
        const PhotoRender(
          photoPath: '/c/IMG.jpg',
          durationSeconds: 1.5,
          outputFileName: '2026-09-28.mp4',
          stampText: '',
          stampStyle: whiteNumeric,
          legacyStampFont: false,
          location: ClipLocation.off(),
          subtitles: '',
          format: ClipFormat.legacy(VideoOrientation.landscape),
          albumLabel: 'Default',
          frame: SourceFrame(
            frame: ClipFrame(scale: 2, fill: FrameFill.blur),
            sourceWidth: 4032,
            sourceHeight: 2268,
          ),
        ),
        files: filesFor(android, 'Default'),
        encoder: VideoEncoder.libx264,
      ),
      containsAllInOrder(<String>[
        '-vf',
        '[in]scale=3840:2160,crop=1920:1080:960:540,$stamp[out]',
        '-map',
        '1:v',
      ]),
    );
  });

  // HDR GOLDEN: an HLG profile writes HEVC Main10 on p010le with the BT.2100 colour tags and
  // hvc1 (`ClipEncoding.outputPixelFormat`), the HLG bitrate (x1.2: 9600k at 1080p30, 33600k
  // at 2160p30). The probed transfer decides the conversion in front of the canvas
  // (`RangeFilter`): none for an HLG source, the SDR-to-HLG chain for an in-app recording or
  // a photo, the PQ-to-HLG chain for an HDR10 import; an HDR source into ANY SDR profile is
  // tone-mapped, ending in yuv420p. SDR into SDR: the argv above, untouched.
  test('an HLG import into an HLG profile: decoded 10-bit, stamped, Main10 '
      'on p010le with the BT.2100 tags, no conversion (1080p VideoToolbox, '
      '4K portrait MediaCodec)', () {
    expect(
      SaveClipCommand.video(
        hdrImport(hlg1080, transfer: 'arib-std-b67'),
        files: filesFor(ios, 'Default'),
        encoder: VideoEncoder.hevcVideoToolbox,
        addSilentAudio: false,
      ),
      <String>[
        '-i', '$iScratch/subtitles.srt', //
        '-ss', '0ms', '-to', '1500ms', '-i', '/c/picker 1/IMG_1.MOV',
        '-metadata', 'artist=One Second Diary (v2)',
        '-metadata', 'album=Default',
        '-metadata', 'comment=origin=import',
        '-vf',
        '[in]scale=1920:1080:force_original_aspect_ratio=decrease,'
            'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,'
            'drawtext=fontfile=$iFont:textfile=$iScratch/date.txt:'
            "fontsize=40.0:fontcolor='0xffffff':borderw=1.0:"
            'bordercolor=0x000000:x=w-tw-40:y=40:expansion=none[out]',
        '-r', '30', '-ac', '2', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
        '-c:v', 'hevc_videotoolbox', '-b:v', '9600k',
        '-profile:v', 'main10', '-allow_sw', '1',
        ...hlgOutput,
        '-force_key_frames', '0.3333,1.1666',
        '-map', '1:v', '-map', '1:a?',
        '$iScratch/2026-09-28.mp4', '-y',
      ],
    );
    expect(
      SaveClipCommand.video(
        hdrImport(
          hlg1080
              .withOrientation(VideoOrientation.portrait)
              .copyWithTier(ResolutionTier.p2160),
          transfer: 'arib-std-b67',
        ),
        files: filesFor(android, 'Default'),
        encoder: VideoEncoder.hevcMediaCodec,
        addSilentAudio: false,
      ),
      <String>[
        '-i', '$aScratch/subtitles.srt', //
        '-ss', '0ms', '-to', '1500ms', '-i', '/c/picker 1/IMG_1.MOV',
        '-metadata', 'artist=One Second Diary (v2)',
        '-metadata', 'album=Default',
        '-metadata', 'comment=origin=import',
        '-vf',
        '[in]scale=2160:3840:force_original_aspect_ratio=increase,'
            'crop=2160:3840,'
            'drawtext=fontfile=$aFont:textfile=$aScratch/date.txt:'
            "fontsize=80.0:fontcolor='0xffffff':borderw=2.0:"
            'bordercolor=0x000000:x=w-tw-80:y=80:expansion=none[out]',
        '-r', '30', '-ac', '2', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
        '-c:v', 'hevc_mediacodec', '-b:v', '33600k', '-profile:v', 'main10',
        ...hlgOutput,
        '-force_key_frames', '0.3333,1.1666',
        '-map', '1:v', '-map', '1:a?',
        '$aScratch/2026-09-28.mp4', '-y',
      ],
    );
  });

  test('an SDR source into an HLG profile is raised in front of the canvas: '
      'a recording (MediaCodec), a photo (VideoToolbox); a PQ import takes '
      'the PQ chain', () {
    expect(
      SaveClipCommand.video(
        recordingIn(hlg1080),
        files: filesFor(android, 'Default'),
        encoder: VideoEncoder.hevcMediaCodec,
        addSilentAudio: false,
      ),
      <String>[
        '-i', '$aScratch/subtitles.srt', //
        '-ss', '0ms', '-to', '1500ms', '-i', '/c/REC.mp4',
        '-metadata', 'artist=One Second Diary (v2)',
        '-metadata', 'album=Default',
        '-metadata', 'comment=origin=osd_recording',
        '-vf',
        '[in]$sdrToHlg,'
            'scale=1920:1080:force_original_aspect_ratio=decrease,'
            'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,'
            'drawtext=fontfile=$aFont:textfile=$aScratch/date.txt:'
            "fontsize=40.0:fontcolor='0xffffff':borderw=1.0:"
            'bordercolor=0x000000:x=w-tw-40:y=40:expansion=none[out]',
        '-r', '30', '-ac', '2', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
        '-c:v', 'hevc_mediacodec', '-b:v', '9600k', '-profile:v', 'main10',
        ...hlgOutput,
        '-force_key_frames', '0.3333,1.1666',
        '-map', '1:v', '-map', '1:a?',
        '$aScratch/2026-09-28.mp4', '-y',
      ],
    );
    expect(
      SaveClipCommand.photo(
        const PhotoRender(
          photoPath: '/c/IMG.HEIC',
          durationSeconds: 2,
          outputFileName: '2026-09-28.mp4',
          stampText: '',
          stampStyle: whiteNumeric,
          legacyStampFont: false,
          location: ClipLocation.off(),
          subtitles: '',
          format: hlg1080,
          albumLabel: 'Default',
        ),
        files: filesFor(ios, 'Default'),
        encoder: VideoEncoder.hevcVideoToolbox,
      ),
      <String>[
        '-i', '$iScratch/subtitles.srt', //
        '-loop', '1', '-framerate', '30', '-i', '/c/IMG.HEIC',
        '-f', 'lavfi',
        '-i', 'anullsrc=channel_layout=stereo:sample_rate=48000',
        '-metadata', 'artist=One Second Diary (v2)',
        '-metadata', 'album=Default',
        '-metadata', 'comment=origin=gallery_photo',
        '-vf',
        '[in]$sdrToHlg,'
            'scale=1920:1080:force_original_aspect_ratio=decrease,'
            'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,'
            'drawtext=fontfile=$iFont:textfile=$iScratch/date.txt:'
            "fontsize=40.0:fontcolor='0xffffff':borderw=1.0:"
            'bordercolor=0x000000:x=w-tw-40:y=40:expansion=none[out]',
        '-r', '30', '-ac', '2', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
        '-c:v', 'hevc_videotoolbox', '-b:v', '9600k',
        '-profile:v', 'main10', '-allow_sw', '1',
        ...hlgOutput,
        '-force_key_frames', '0.3333,1.6666',
        '-t', '2.0',
        '-map', '1:v', '-map', '2:a',
        '$iScratch/2026-09-28.mp4', '-y',
      ],
    );
    final List<String> pq = SaveClipCommand.video(
      hdrImport(hlg1080, transfer: 'smpte2084'),
      files: filesFor(ios, 'Default'),
      encoder: VideoEncoder.hevcVideoToolbox,
      addSilentAudio: false,
    );
    expect(
      pq[pq.indexOf('-vf') + 1],
      '[in]$pqToHlg,'
      'scale=1920:1080:force_original_aspect_ratio=decrease,'
      'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,'
      'drawtext=fontfile=$iFont:textfile=$iScratch/date.txt:'
      "fontsize=40.0:fontcolor='0xffffff':borderw=1.0:"
      'bordercolor=0x000000:x=w-tw-40:y=40:expansion=none[out]',
    );
  });

  test('an HDR import into an SDR profile is tone-mapped in front of the '
      'canvas: the legacy format (libx264, its argv otherwise), the Ultra '
      'preset (VideoToolbox); an SDR-tagged source changes nothing', () {
    expect(
      SaveClipCommand.video(
        hdrImport(
          const ClipFormat.legacy(VideoOrientation.landscape),
          transfer: 'arib-std-b67',
        ),
        files: filesFor(android, 'Default'),
        encoder: VideoEncoder.libx264,
        addSilentAudio: false,
      ),
      <String>[
        '-i', '$aScratch/subtitles.srt', //
        '-ss', '0ms', '-to', '1500ms', '-i', '/c/picker 1/IMG_1.MOV',
        '-metadata', 'artist=One Second Diary (v1.5)',
        '-metadata', 'album=Default',
        '-metadata', 'comment=origin=import',
        '-vf',
        '[in]$hdrToSdr,'
            'scale=1920:1080:force_original_aspect_ratio=decrease,'
            'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,'
            'drawtext=fontfile=$aFont:textfile=$aScratch/date.txt:'
            "fontsize=40.0:fontcolor='0xffffff':borderw=1.0:"
            'bordercolor=0x000000:x=w-tw-40:y=40:expansion=none[out]',
        '-r', '30', '-ac', '1', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
        '-c:v', 'libx264', '-crf', '20', '-preset', 'medium',
        '-pix_fmt', 'yuv420p',
        '-force_key_frames', '0.3333,1.1666',
        '-map', '1:v', '-map', '1:a?',
        '$aScratch/2026-09-28.mp4', '-y',
      ],
    );
    expect(
      SaveClipCommand.video(
        hdrImport(ultra, transfer: 'smpte2084'),
        files: filesFor(ios, 'Default'),
        encoder: VideoEncoder.hevcVideoToolbox,
        addSilentAudio: false,
      ),
      <String>[
        '-i', '$iScratch/subtitles.srt', //
        '-ss', '0ms', '-to', '1500ms', '-i', '/c/picker 1/IMG_1.MOV',
        '-metadata', 'artist=One Second Diary (v2)',
        '-metadata', 'album=Default',
        '-metadata', 'comment=origin=import',
        '-vf',
        '[in]$hdrToSdr,'
            'scale=3840:2160:force_original_aspect_ratio=decrease,'
            'pad=3840:2160:(ow-iw)/2:(oh-ih)/2:black,'
            'drawtext=fontfile=$iFont:textfile=$iScratch/date.txt:'
            "fontsize=80.0:fontcolor='0xffffff':borderw=2.0:"
            'bordercolor=0x000000:x=w-tw-80:y=80:expansion=none[out]',
        '-r', '60', '-ac', '2', '-ar', '48000', '-c:a', 'aac', '-b:a', '256k',
        '-c:v', 'hevc_videotoolbox', '-b:v', '42000k',
        '-profile:v', 'main', '-allow_sw', '1',
        '-pix_fmt', 'yuv420p', '-tag:v', 'hvc1',
        '-force_key_frames', '0.3333,1.1666',
        '-map', '1:v', '-map', '1:a?',
        '$iScratch/2026-09-28.mp4', '-y',
      ],
    );
    // An SDR source that says so (bt709) is the untagged case: the legacy
    // argv, byte for byte.
    expect(
      SaveClipCommand.video(
        hdrImport(
          const ClipFormat.legacy(VideoOrientation.landscape),
          transfer: 'bt709',
        ),
        files: filesFor(android, 'Default'),
        encoder: VideoEncoder.libx264,
        addSilentAudio: false,
      ),
      SaveClipCommand.video(
        hdrImport(
          const ClipFormat.legacy(VideoOrientation.landscape),
          transfer: null,
        ),
        files: filesFor(android, 'Default'),
        encoder: VideoEncoder.libx264,
        addSilentAudio: false,
      ),
    );
  });
}
