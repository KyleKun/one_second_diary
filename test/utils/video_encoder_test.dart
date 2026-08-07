import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/utils/video_encoder.dart';

/// Trimmed but otherwise verbatim output of `ffmpeg -encoders`.
const String _gplBuild = '''
Encoders:
 V..... = Video
 A..... = Audio
 S..... = Subtitle
 .F.... = Frame-level multithreading
 ..S... = Slice-level multithreading
 ...X.. = Codec is experimental
 ....B. = Supports draw_horiz_band
 .....D = Supports direct rendering method 1
 ------
 V....D libx264              libx264 H.264 / AVC / MPEG-4 AVC (codec h264)
 V....D libx265              libx265 H.265 / HEVC (codec hevc)
 V....D h264_videotoolbox    VideoToolbox H.264 Encoder (codec h264)
 A....D aac                  AAC (Advanced Audio Coding)
 S..... mov_text             3GPP Timed Text subtitle
''';

const String _lgplIosBuild = '''
Encoders:
 V..... = Video
 ------
 V....D h264_videotoolbox    VideoToolbox H.264 Encoder (codec h264)
 A....D aac                  AAC (Advanced Audio Coding)
''';

const String _lgplAndroidBuild = '''
Encoders:
 V..... = Video
 ------
 V....D h264_mediacodec      H.264 Android MediaCodec encoder (codec h264)
 A....D aac                  AAC (Advanced Audio Coding)
''';

void main() {
  group('parseEncoders', () {
    test('reads the encoder names and skips the legend', () {
      final encoders = VideoEncoder.parseEncoders(_gplBuild);

      expect(
        encoders,
        containsAll(<String>['libx264', 'libx265', 'h264_videotoolbox', 'aac', 'mov_text']),
      );
      expect(encoders, isNot(contains('=')));
      expect(encoders, isNot(contains('Video')));
    });

    test('returns nothing for empty or unparseable output', () {
      expect(VideoEncoder.parseEncoders(''), isEmpty);
      expect(VideoEncoder.parseEncoders('ffmpeg: command not found'), isEmpty);
    });
  });

  group('select', () {
    test('prefers VideoToolbox on iOS even when libx264 is available', () {
      // A GPL build would offer libx264, but VideoToolbox is both faster and
      // the only option that can ship on the App Store.
      expect(
        VideoEncoder.select(_gplBuild, isIOS: true),
        VideoEncoder.videoToolbox,
      );
    });

    test('keeps libx264 on Android so GPL builds render exactly as before', () {
      expect(
        VideoEncoder.select(_gplBuild, isIOS: false),
        VideoEncoder.libx264,
      );
    });

    test('falls back to MediaCodec on an LGPL Android build', () {
      expect(
        VideoEncoder.select(_lgplAndroidBuild, isIOS: false),
        VideoEncoder.mediaCodec,
      );
    });

    test('uses VideoToolbox on an LGPL iOS build', () {
      expect(
        VideoEncoder.select(_lgplIosBuild, isIOS: true),
        VideoEncoder.videoToolbox,
      );
    });

    test('falls back to the platform default when the probe returns nothing', () {
      expect(VideoEncoder.select('', isIOS: true), VideoEncoder.videoToolbox);
      expect(VideoEncoder.select('', isIOS: false), VideoEncoder.libx264);
    });
  });

  group('argumentsFor', () {
    test('libx264 keeps the CRF quality target the app has always used', () {
      expect(
        VideoEncoder.argumentsFor(VideoEncoder.libx264),
        '-c:v libx264 -crf 20 -preset slow',
      );
    });

    test('VideoToolbox uses a bitrate target and allows a software fallback', () {
      final String args = VideoEncoder.argumentsFor(VideoEncoder.videoToolbox);

      expect(args, contains('-c:v h264_videotoolbox'));
      expect(args, contains('-b:v ${VideoEncoder.targetBitrateKbps}k'));
      // VideoToolbox has no CRF mode, passing one makes ffmpeg fail.
      expect(args, isNot(contains('-crf')));
      expect(args, isNot(contains('-preset')));
      expect(args, contains('-allow_sw 1'));
    });

    test('MediaCodec uses a bitrate target and no CRF either', () {
      final String args = VideoEncoder.argumentsFor(VideoEncoder.mediaCodec);

      expect(args, contains('-c:v h264_mediacodec'));
      expect(args, isNot(contains('-crf')));
    });

    test('an unknown encoder degrades to the software encoder', () {
      expect(
        VideoEncoder.argumentsFor('h264_nvenc'),
        VideoEncoder.argumentsFor(VideoEncoder.libx264),
      );
    });
  });

  group('name', () {
    tearDown(() => VideoEncoder.debugSetEncoder(null));

    test('reflects what the probe selected', () {
      VideoEncoder.debugSetEncoder(VideoEncoder.videoToolbox);
      expect(VideoEncoder.name, VideoEncoder.videoToolbox);
      expect(VideoEncoder.arguments, contains('h264_videotoolbox'));
    });
  });
}
