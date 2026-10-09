import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/stamp_filter.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

const String internal = '/data/user/0/com.kylekun.one_second_diary/app_flutter';
const String ios =
    '/var/mobile/Containers/Data/Application/X/Library/Application Support';

const StampStyle whiteNumeric = StampStyle(
  format: StampFormat.numeric,
  rgb: 0xFFFFFF,
  outline: true,
);

ClipFormat formatOf(ResolutionTier tier, VideoOrientation orientation) =>
    ClipFormat(
      tier: tier,
      orientation: orientation,
      codec: VideoCodec.hevc,
      fps: FrameRate.f30,
      channels: AudioChannels.stereo,
      range: DynamicRange.sdr,
    );

void main() {
  // The default stamp is numeric, top right, white on black. A written date sits at the
  // bottom left; the location at the bottom right, in the date colour, after ", ". Text
  // always through textfile= (never text=), fontsize 40, the outline in the inverted colour.
  test("StampFilter.videoFilter: v1.7's stamp filters at 1080p", () {
    expect(
      StampFilter.videoFilter(
        format: const ClipFormat.legacy(VideoOrientation.landscape),
        style: whiteNumeric,
        fontPath: '$internal/magic.ttf',
        dateTextPath: '$internal/date.txt',
        locationTextPath: null,
      ),
      (
        complex: false,
        value:
            '[in]scale=1920:1080:force_original_aspect_ratio=decrease,'
            'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,'
            'drawtext=fontfile=$internal/magic.ttf:textfile=$internal/date.txt:'
            "fontsize=40.0:fontcolor='0xffffff':borderw=1.0:bordercolor=0x000000:"
            'x=w-tw-40:y=40:expansion=none[out]',
      ),
      reason: 'numeric, landscape, no location',
    );
    expect(
      StampFilter.videoFilter(
        format: const ClipFormat.legacy(VideoOrientation.portrait),
        style: const StampStyle(
          format: StampFormat.written,
          rgb: 0xE53935,
          outline: false,
        ),
        fontPath: '$ios/font.ttf',
        dateTextPath: '$ios/date.txt',
        locationTextPath: '$ios/location.txt',
      ),
      (
        complex: false,
        value:
            '[in]scale=1080:1920:force_original_aspect_ratio=increase,'
            'crop=1080:1920,'
            'drawtext=fontfile=$ios/font.ttf:textfile=$ios/date.txt:'
            "fontsize=40.0:fontcolor='0xe53935':borderw=0.0:bordercolor=0x1ac6ca:"
            'x=40:y=h-th-40:expansion=none, '
            'drawtext=textfile=$ios/location.txt:fontfile=$ios/font.ttf:'
            "fontsize=40.0:fontcolor='0xe53935':borderw=0.0:bordercolor=0x1ac6ca:"
            'x=w-tw-40:y=h-th-40:expansion=none[out]',
      ),
      reason: 'written, portrait, with a location',
    );
  });

  // k = shortSide / 1080, 40k px of type and margin, 1k of outline, whole pixels; fontsize
  // and borderw printed as Dart doubles.
  test('the stamp scales with the canvas: 27 px at 720p, 53 at 1440p, 80 '
      'at 4K; the outline 1, 1 and 2', () {
    const Map<ResolutionTier, (int, int)> sizes = <ResolutionTier, (int, int)>{
      ResolutionTier.p720: (27, 1),
      ResolutionTier.p1080: (40, 1),
      ResolutionTier.p1440: (53, 1),
      ResolutionTier.p2160: (80, 2),
    };
    for (final MapEntry<ResolutionTier, (int, int)> row in sizes.entries) {
      final ClipFormat format = formatOf(row.key, VideoOrientation.landscape);
      final (int size, int outline) = row.value;
      expect(StampFilter.fontSizeFor(format), size, reason: '${row.key}');
      expect(StampFilter.marginFor(format), size);
      expect(StampFilter.outlineWidthFor(format), outline);
    }
    expect(
      StampFilter.videoFilter(
        format: formatOf(ResolutionTier.p2160, VideoOrientation.portrait),
        style: whiteNumeric,
        fontPath: '$internal/magic.ttf',
        dateTextPath: '$internal/date.txt',
        locationTextPath: '$internal/location.txt',
      ).value,
      '[in]scale=2160:3840:force_original_aspect_ratio=increase,'
      'crop=2160:3840,'
      'drawtext=fontfile=$internal/magic.ttf:textfile=$internal/date.txt:'
      "fontsize=80.0:fontcolor='0xffffff':borderw=2.0:bordercolor=0x000000:"
      'x=w-tw-80:y=80:expansion=none, '
      'drawtext=textfile=$internal/location.txt:fontfile=$internal/magic.ttf:'
      "fontsize=80.0:fontcolor='0xffffff':borderw=2.0:bordercolor=0x000000:"
      'x=w-tw-80:y=h-th-80:expansion=none[out]',
    );
    expect(
      StampFilter.videoFilter(
        format: formatOf(ResolutionTier.p720, VideoOrientation.landscape),
        style: const StampStyle(
          format: StampFormat.written,
          rgb: 0x212121,
          outline: false,
        ),
        fontPath: '$internal/magic.ttf',
        dateTextPath: '$internal/date.txt',
        locationTextPath: null,
      ).value,
      '[in]scale=1280:720:force_original_aspect_ratio=decrease,'
      'pad=1280:720:(ow-iw)/2:(oh-ih)/2:black,'
      'drawtext=fontfile=$internal/magic.ttf:textfile=$internal/date.txt:'
      "fontsize=27.0:fontcolor='0x212121':borderw=0.0:bordercolor=0xdedede:"
      'x=27:y=h-th-27:expansion=none[out]',
    );
  });

  // The text size (owner request 2026-10-07): 32 and 48 px at 1080p for a
  // small and a large stamp, scaled with the canvas like the medium 40;
  // the margin and the outline do not follow it (the stamp keeps its
  // inset and its 1 px ring), and the place takes the same size as the
  // date. A style without a size is medium: the goldens above are the
  // default and did not change.
  test('a small or a large stamp changes fontsize alone, on the date and '
      'the place, at 1080p and at 4K', () {
    const Map<(StampSize, ResolutionTier), int> sizes =
        <(StampSize, ResolutionTier), int>{
          (StampSize.small, ResolutionTier.p1080): 32,
          (StampSize.large, ResolutionTier.p1080): 48,
          (StampSize.small, ResolutionTier.p2160): 64,
          (StampSize.large, ResolutionTier.p2160): 96,
          (StampSize.small, ResolutionTier.p720): 21,
          (StampSize.large, ResolutionTier.p720): 32,
          (StampSize.small, ResolutionTier.p1440): 43,
          (StampSize.large, ResolutionTier.p1440): 64,
        };
    for (final MapEntry<(StampSize, ResolutionTier), int> row
        in sizes.entries) {
      final (StampSize size, ResolutionTier tier) = row.key;
      final ClipFormat format = formatOf(tier, VideoOrientation.portrait);
      expect(StampFilter.fontSizeFor(format, size), row.value, reason: '$row');
      expect(
        StampFilter.fontSizeFor(format),
        StampFilter.fontSizeFor(format, StampSize.medium),
        reason: 'the default is medium',
      );
    }
    expect(
      const StampStyle(
        format: StampFormat.numeric,
        rgb: 0xFFFFFF,
        outline: true,
      ).size,
      StampSize.medium,
    );

    expect(
      StampFilter.videoFilter(
        format: const ClipFormat.legacy(VideoOrientation.portrait),
        style: const StampStyle(
          format: StampFormat.written,
          rgb: 0xFFFFFF,
          outline: true,
          size: StampSize.large,
        ),
        fontPath: '$internal/magic.ttf',
        dateTextPath: '$internal/date.txt',
        locationTextPath: '$internal/location.txt',
      ),
      (
        complex: false,
        value:
            '[in]scale=1080:1920:force_original_aspect_ratio=increase,'
            'crop=1080:1920,'
            'drawtext=fontfile=$internal/magic.ttf:textfile=$internal/date.txt:'
            "fontsize=48.0:fontcolor='0xffffff':borderw=1.0:bordercolor=0x000000:"
            'x=40:y=h-th-40:expansion=none, '
            'drawtext=textfile=$internal/location.txt:fontfile=$internal/magic.ttf:'
            "fontsize=48.0:fontcolor='0xffffff':borderw=1.0:bordercolor=0x000000:"
            'x=w-tw-40:y=h-th-40:expansion=none[out]',
      ),
      reason: 'large, written, 1080p portrait, with a place',
    );
    expect(
      StampFilter.videoFilter(
        format: const ClipFormat.legacy(VideoOrientation.landscape),
        style: const StampStyle(
          format: StampFormat.numeric,
          rgb: 0xE53935,
          outline: false,
          size: StampSize.small,
        ),
        fontPath: '$ios/font.ttf',
        dateTextPath: '$ios/date.txt',
        locationTextPath: null,
      ).value,
      '[in]scale=1920:1080:force_original_aspect_ratio=decrease,'
      'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black,'
      'drawtext=fontfile=$ios/font.ttf:textfile=$ios/date.txt:'
      "fontsize=32.0:fontcolor='0xe53935':borderw=0.0:bordercolor=0x1ac6ca:"
      'x=w-tw-40:y=40:expansion=none[out]',
      reason: 'small, numeric, 1080p landscape',
    );
    expect(
      StampFilter.videoFilter(
        format: formatOf(ResolutionTier.p2160, VideoOrientation.landscape),
        style: const StampStyle(
          format: StampFormat.numeric,
          rgb: 0xFFFFFF,
          outline: true,
          size: StampSize.large,
        ),
        fontPath: '$internal/magic.ttf',
        dateTextPath: '$internal/date.txt',
        locationTextPath: '$internal/location.txt',
      ).value,
      '[in]scale=3840:2160:force_original_aspect_ratio=decrease,'
      'pad=3840:2160:(ow-iw)/2:(oh-ih)/2:black,'
      'drawtext=fontfile=$internal/magic.ttf:textfile=$internal/date.txt:'
      "fontsize=96.0:fontcolor='0xffffff':borderw=2.0:bordercolor=0x000000:"
      'x=w-tw-80:y=80:expansion=none, '
      'drawtext=textfile=$internal/location.txt:fontfile=$internal/magic.ttf:'
      "fontsize=96.0:fontcolor='0xffffff':borderw=2.0:bordercolor=0x000000:"
      'x=w-tw-80:y=h-th-80:expansion=none[out]',
      reason:
          'large at 4K: 96 px of type, the 80 px margin and 2 px '
          'outline of a 4K stamp',
    );
    expect(
      StampFilter.videoFilter(
        format: formatOf(ResolutionTier.p2160, VideoOrientation.portrait),
        style: const StampStyle(
          format: StampFormat.written,
          rgb: 0x212121,
          outline: true,
          size: StampSize.small,
        ),
        fontPath: '$internal/magic.ttf',
        dateTextPath: '$internal/date.txt',
        locationTextPath: null,
      ).value,
      '[in]scale=2160:3840:force_original_aspect_ratio=increase,'
      'crop=2160:3840,'
      'drawtext=fontfile=$internal/magic.ttf:textfile=$internal/date.txt:'
      "fontsize=64.0:fontcolor='0x212121':borderw=2.0:bordercolor=0xdedede:"
      'x=80:y=h-th-80:expansion=none[out]',
      reason: 'small at 4K',
    );
  });

  // A frame takes the canvas's place before the stamps: a black fill stays a `-vf` chain;
  // a blur fill with bars is a `-filter_complex` graph from the source's `[1:v]`, the
  // stamps after the overlay and the output labelled `[v]`.
  test('a framed source: the stamps after the frame, as a chain or as the '
      'blur graph', () {
    const SourceFrame fit = SourceFrame(
      frame: ClipFrame(scale: 0.5625),
      sourceWidth: 1920,
      sourceHeight: 1080,
    );
    const String stamp =
        'drawtext=fontfile=$internal/magic.ttf:textfile=$internal/date.txt:'
        "fontsize=40.0:fontcolor='0xffffff':borderw=1.0:bordercolor=0x000000:"
        'x=w-tw-40:y=40:expansion=none';
    expect(
      StampFilter.videoFilter(
        format: const ClipFormat.legacy(VideoOrientation.portrait),
        frame: fit,
        style: whiteNumeric,
        fontPath: '$internal/magic.ttf',
        dateTextPath: '$internal/date.txt',
        locationTextPath: null,
      ),
      (
        complex: false,
        value: '[in]scale=1080:608,pad=1080:1920:0:656:black,$stamp[out]',
      ),
    );
    expect(
      StampFilter.videoFilter(
        format: const ClipFormat.legacy(VideoOrientation.portrait),
        frame: const SourceFrame(
          frame: ClipFrame(scale: 0.5625, fill: FrameFill.blur),
          sourceWidth: 1920,
          sourceHeight: 1080,
        ),
        style: whiteNumeric,
        fontPath: '$internal/magic.ttf',
        dateTextPath: '$internal/date.txt',
        locationTextPath: null,
      ),
      (
        complex: true,
        value:
            // REWRITTEN: the background blurs small (covering size ÷ 8,
            // sigma 2.5) and is scaled back up; see canvas_filter_test.
            '[1:v]split[bg][fg];'
            '[bg]scale=426:240,gblur=sigma=2.5,'
            'scale=3414:1920:flags=bilinear,crop=1080:1920:1168:0[b];'
            '[fg]scale=1080:608[f];'
            '[b][f]overlay=0:656,$stamp[v]',
      ),
    );
  });

  // The range conversion goes in front of the canvas, or, in the blur graph, on [1:v]
  // before the split, so the blur, the frame and the stamps work in the target's range.
  test('a source of another range is converted first: before the chain, '
      'or on [1:v] before the blur graph\'s split', () {
    const String hdrToSdr =
        'zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,'
        'tonemap=hable,zscale=t=bt709:m=bt709:r=tv,format=yuv420p';
    const String sdrToHlg =
        'zscale=pin=bt709:tin=bt709:min=bt709:t=linear:npl=100,'
        'format=gbrpf32le,exposure=exposure=-2.3,zscale=p=bt2020,'
        'zscale=t=arib-std-b67:m=bt2020nc:r=tv:npl=1000,format=yuv420p10le';
    const String stamp =
        'drawtext=fontfile=$internal/magic.ttf:textfile=$internal/date.txt:'
        "fontsize=40.0:fontcolor='0xffffff':borderw=1.0:bordercolor=0x000000:"
        'x=w-tw-40:y=40:expansion=none';
    expect(
      StampFilter.videoFilter(
        format: const ClipFormat.legacy(VideoOrientation.portrait),
        frame: const SourceFrame(
          frame: ClipFrame(scale: 0.5625),
          sourceWidth: 1920,
          sourceHeight: 1080,
        ),
        style: whiteNumeric,
        fontPath: '$internal/magic.ttf',
        dateTextPath: '$internal/date.txt',
        locationTextPath: null,
        sourceColorTransfer: 'arib-std-b67',
      ),
      (
        complex: false,
        value:
            '[in]$hdrToSdr,scale=1080:608,pad=1080:1920:0:656:black,'
            '$stamp[out]',
      ),
    );
    expect(
      StampFilter.videoFilter(
        format: const ClipFormat.legacy(VideoOrientation.portrait),
        frame: const SourceFrame(
          frame: ClipFrame(scale: 0.5625, fill: FrameFill.blur),
          sourceWidth: 1920,
          sourceHeight: 1080,
        ),
        style: whiteNumeric,
        fontPath: '$internal/magic.ttf',
        dateTextPath: '$internal/date.txt',
        locationTextPath: null,
        sourceColorTransfer: 'smpte2084',
      ),
      (
        complex: true,
        value:
            '[1:v]$hdrToSdr[c];'
            '[c]split[bg][fg];'
            '[bg]scale=426:240,gblur=sigma=2.5,'
            'scale=3414:1920:flags=bilinear,crop=1080:1920:1168:0[b];'
            '[fg]scale=1080:608[f];'
            '[b][f]overlay=0:656,$stamp[v]',
      ),
    );
    expect(
      StampFilter.videoFilter(
        format: const ClipFormat(
          tier: ResolutionTier.p1080,
          orientation: VideoOrientation.portrait,
          codec: VideoCodec.hevc,
          fps: FrameRate.f30,
          channels: AudioChannels.stereo,
          range: DynamicRange.hlg,
        ),
        style: whiteNumeric,
        fontPath: '$internal/magic.ttf',
        dateTextPath: '$internal/date.txt',
        locationTextPath: null,
        sourceColorTransfer: 'bt709',
      ),
      (
        complex: false,
        value:
            '[in]$sdrToHlg,'
            'scale=1080:1920:force_original_aspect_ratio=increase,'
            'crop=1080:1920,$stamp[out]',
      ),
    );
  });
}
