import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/policy/canvas_filter.dart';
import 'package:one_second_diary/core/media/types/clip_crop.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

const ClipFormat _landscape = ClipFormat.legacy(VideoOrientation.landscape);
const ClipFormat _portrait = ClipFormat.legacy(VideoOrientation.portrait);
const ClipFormat _fourK = ClipFormat(
  tier: ResolutionTier.p2160,
  orientation: VideoOrientation.landscape,
  codec: VideoCodec.hevc,
  fps: FrameRate.f60,
  channels: AudioChannels.stereo,
  range: DynamicRange.sdr,
);

SourceFrame _landscapeSource(ClipFrame frame) =>
    SourceFrame(frame: frame, sourceWidth: 1920, sourceHeight: 1080);

SourceFrame _portraitSource(ClipFrame frame) =>
    SourceFrame(frame: frame, sourceWidth: 1080, sourceHeight: 1920);

/// 16:9 on 9:16: fit shows the source at 0.5625 of the short side, cover
/// at 1920/1080.
const double _crossFit = 0.5625;
const double _crossCover = 1920 / 1080;

void main() {
  // GOLDEN: the two legacy shapes at 1080p, and the same shapes with the sizes of each tier.
  test('scaleFilter: pad for landscape, cover-crop for portrait, sizes from '
      'the tier', () {
    expect(
      CanvasFilter.scaleFilter(_landscape),
      'scale=1920:1080:force_original_aspect_ratio=decrease,'
      'pad=1920:1080:(ow-iw)/2:(oh-ih)/2:black',
    );
    expect(
      CanvasFilter.scaleFilter(_portrait),
      'scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920',
    );
    expect(
      CanvasFilter.scaleFilter(_fourK),
      'scale=3840:2160:force_original_aspect_ratio=decrease,'
      'pad=3840:2160:(ow-iw)/2:(oh-ih)/2:black',
    );
    expect(
      CanvasFilter.scaleFilter(
        _fourK.withOrientation(VideoOrientation.portrait),
      ),
      'scale=2160:3840:force_original_aspect_ratio=increase,crop=2160:3840',
    );
    expect(
      CanvasFilter.scaleFilter(
        const ClipFormat(
          tier: ResolutionTier.p720,
          orientation: VideoOrientation.landscape,
          codec: VideoCodec.h264,
          fps: FrameRate.f30,
          channels: AudioChannels.mono,
          range: DynamicRange.sdr,
        ),
      ),
      'scale=1280:720:force_original_aspect_ratio=decrease,'
      'pad=1280:720:(ow-iw)/2:(oh-ih)/2:black',
    );
    // The editor's crop: the part cut in fractions, then covering.
    expect(
      CanvasFilter.scaleFilter(
        _landscape,
        crop: const ClipCrop(left: 0.25, top: 0.1, width: 0.5, height: 0.5),
      ),
      'crop=iw*0.500000:ih*0.500000:iw*0.250000:ih*0.100000,'
      'scale=1920:1080:force_original_aspect_ratio=increase,crop=1920:1080',
    );
  });

  // GOLDEN: whole, even pixels computed in Dart: the source at the frame's scale, the
  // overflow cut, the bars padded.
  test('frameFilter: fit, cover, 2×, between, on both canvases and at 4K', () {
    final List<(String, ClipFormat, SourceFrame, String)> cases =
        <(String, ClipFormat, SourceFrame, String)>[
          (
            'same shape at fit (= cover): the canvas, nothing cut or padded',
            _landscape,
            _landscapeSource(const ClipFrame(scale: 1)),
            'scale=1920:1080',
          ),
          (
            '2×, centred: the middle quarter',
            _landscape,
            _landscapeSource(const ClipFrame(scale: 2)),
            'scale=3840:2160,crop=1920:1080:960:540',
          ),
          (
            '2×, moved right and up: the bottom-left quarter shown',
            _landscape,
            _landscapeSource(const ClipFrame(scale: 2, dx: 0.5, dy: -0.5)),
            'scale=3840:2160,crop=1920:1080:0:1080',
          ),
          (
            'landscape on portrait at fit: bars above and below',
            _portrait,
            _landscapeSource(const ClipFrame(scale: _crossFit)),
            'scale=1080:608,pad=1080:1920:0:656:black',
          ),
          (
            'landscape on portrait at cover: the sides cut',
            _portrait,
            _landscapeSource(const ClipFrame(scale: _crossCover)),
            'scale=3414:1920,crop=1080:1920:1168:0',
          ),
          (
            'between fit and cover: the sides cut and bars above and below',
            _portrait,
            _landscapeSource(const ClipFrame(scale: 1)),
            'scale=1920:1080,crop=1080:1080:420:0,pad=1080:1920:0:420:black',
          ),
          (
            'a 1080p source on the 4K canvas at fit: enlarged 2×',
            _fourK,
            _landscapeSource(const ClipFrame(scale: 1)),
            'scale=3840:2160',
          ),
          (
            'a portrait source on the 4K canvas at fit: bars left and right',
            _fourK,
            _portraitSource(const ClipFrame(scale: _crossFit)),
            'scale=1216:2160,pad=3840:2160:1312:0:black',
          ),
          (
            'a frame past the clamp is clamped first (0.1 → fit)',
            _landscape,
            _landscapeSource(const ClipFrame(scale: 0.1, dx: 3)),
            'scale=1920:1080',
          ),
        ];
    for (final (String name, ClipFormat format, SourceFrame frame, String chain)
        in cases) {
      expect(CanvasFilter.frameFilter(format, frame), chain, reason: name);
    }
  });

  // GOLDEN: the blur fill is a graph: the source split, one copy scaled
  // to cover the canvas, blurred and centre-cropped, the other placed as
  // the chain places it, overlaid. Only with bars to fill.
  // REWRITTEN: the blur runs small. A `gblur=sigma=20` over the full
  // covering copy took most of a 4K60 save's filter time (a 5 s clip took
  // 127 s on a Galaxy Z Flip6), so the copy is scaled to the covering size
  // ÷ 8 (even pixels), blurred with sigma 20 ÷ 8 = 2.5 and scaled back up
  // (bilinear) before the crop: the same blur, over 1/64 of the pixels.
  // The black fill and every other chain are untouched.
  test('blurGraph: the split/gblur/overlay graph for a blur fill with bars; '
      'none when the frame leaves no bar or the fill is black', () {
    expect(
      CanvasFilter.blurGraph(
        _portrait,
        _landscapeSource(
          const ClipFrame(scale: _crossFit, fill: FrameFill.blur),
        ),
        input: '1:v',
      ),
      '[1:v]split[bg][fg];'
      '[bg]scale=426:240,gblur=sigma=2.5,'
      'scale=3414:1920:flags=bilinear,crop=1080:1920:1168:0[b];'
      '[fg]scale=1080:608[f];'
      '[b][f]overlay=0:656',
      reason: 'at fit, centred',
    );
    expect(
      CanvasFilter.blurGraph(
        _portrait,
        _landscapeSource(
          const ClipFrame(scale: _crossFit, dy: 0.1, fill: FrameFill.blur),
        ),
        input: '1:v',
      ),
      '[1:v]split[bg][fg];'
      '[bg]scale=426:240,gblur=sigma=2.5,'
      'scale=3414:1920:flags=bilinear,crop=1080:1920:1168:0[b];'
      '[fg]scale=1080:608[f];'
      '[b][f]overlay=0:848',
    );
    expect(
      CanvasFilter.blurGraph(
        _fourK,
        _portraitSource(
          const ClipFrame(scale: _crossFit, fill: FrameFill.blur),
        ),
        input: '1:v',
      ),
      '[1:v]split[bg][fg];'
      '[bg]scale=480:854,gblur=sigma=2.5,'
      'scale=3840:6828:flags=bilinear,crop=3840:2160:0:2334[b];'
      '[fg]scale=1216:2160[f];'
      '[b][f]overlay=1312:0',
      reason: 'a portrait source on the 4K canvas',
    );
    final SourceFrame covering = _landscapeSource(
      const ClipFrame(scale: 2, fill: FrameFill.blur),
    );
    expect(CanvasFilter.blurGraph(_landscape, covering, input: '1:v'), isNull);
    expect(CanvasFilter.needsBlurGraph(_landscape, covering), isFalse);
    expect(
      CanvasFilter.frameFilter(_landscape, covering),
      'scale=3840:2160,crop=1920:1080:960:540',
      reason: 'the chain, as for a black fill',
    );
    final SourceFrame black = _landscapeSource(
      const ClipFrame(scale: _crossFit),
    );
    expect(CanvasFilter.blurGraph(_portrait, black, input: '1:v'), isNull);
    expect(CanvasFilter.needsBlurGraph(_portrait, black), isFalse);
    expect(
      CanvasFilter.needsBlurGraph(
        _portrait,
        _landscapeSource(
          const ClipFrame(scale: _crossFit, fill: FrameFill.blur),
        ),
      ),
      isTrue,
    );
  });
}
