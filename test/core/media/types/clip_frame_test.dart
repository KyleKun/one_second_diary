import 'package:flutter_test/flutter_test.dart';
import 'package:one_second_diary/core/media/types/clip_crop.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';

const ClipFrameGeometry _landscapeOnLandscape = ClipFrameGeometry(
  sourceWidth: 1920,
  sourceHeight: 1080,
  canvasWidth: 1920,
  canvasHeight: 1080,
);
const ClipFrameGeometry _landscapeOnPortrait = ClipFrameGeometry(
  sourceWidth: 1920,
  sourceHeight: 1080,
  canvasWidth: 1080,
  canvasHeight: 1920,
);
const ClipFrameGeometry _portraitOnLandscape = ClipFrameGeometry(
  sourceWidth: 1080,
  sourceHeight: 1920,
  canvasWidth: 1920,
  canvasHeight: 1080,
);
const ClipFrameGeometry _portraitOnPortrait = ClipFrameGeometry(
  sourceWidth: 1080,
  sourceHeight: 1920,
  canvasWidth: 1080,
  canvasHeight: 1920,
);

/// 16:9 on 9:16 (either way round): the fit shows the source at
/// 1080/1920 = 0.5625 of the canvas's short side; the cover at 1920/1080.
const double _crossFit = 0.5625;
const double _crossCover = 1920 / 1080;

void main() {
  group('the scales of a source on a canvas', () {
    test('a source in the canvas\'s shape: fit = cover = 1, lossless 1 at '
        'the same size, maxZoom the close crop (4×)', () {
      for (final ClipFrameGeometry same in <ClipFrameGeometry>[
        _landscapeOnLandscape,
        _portraitOnPortrait,
      ]) {
        expect(same.fitScale, 1, reason: '$same');
        expect(same.coverScale, 1);
        expect(same.losslessScale, 1);
        expect(same.maxZoom, 4);
        expect(same.isLossless(1), isTrue);
        expect(same.isLossless(1.01), isFalse);
      }
    });

    test('a source across the canvas\'s shape: fit shows the whole picture '
        'with bars, cover fills it; each way round the same numbers', () {
      for (final ClipFrameGeometry cross in <ClipFrameGeometry>[
        _landscapeOnPortrait,
        _portraitOnLandscape,
      ]) {
        expect(cross.fitScale, closeTo(_crossFit, 1e-9), reason: '$cross');
        expect(cross.coverScale, closeTo(_crossCover, 1e-9));
        expect(cross.losslessScale, 1);
        expect(cross.maxZoom, closeTo(_crossCover * 4, 1e-9));
      }
      // At fit the long side is the canvas's short side, the short side
      // leaves bars; at cover the short side is the canvas's long side.
      final ({double width, double height}) fit = _landscapeOnPortrait.shownAt(
        _crossFit,
      );
      expect(fit.width, closeTo(1, 1e-9));
      expect(fit.height, closeTo(_crossFit * _crossFit, 1e-9));
      final ({double width, double height}) cover = _landscapeOnPortrait
          .shownAt(_crossCover);
      expect(cover.height, closeTo(1, 1e-9));
      expect(cover.width, closeTo(_crossCover * _crossCover, 1e-9));
    });

    test('a sharper source has room to zoom in for free: a 4K source on a '
        '1080p canvas is lossless up to 2×, and maxZoom grows with it', () {
      const ClipFrameGeometry fourK = ClipFrameGeometry(
        sourceWidth: 3840,
        sourceHeight: 2160,
        canvasWidth: 1920,
        canvasHeight: 1080,
      );
      expect(fourK.fitScale, 1);
      expect(fourK.coverScale, 1);
      expect(fourK.losslessScale, 2);
      expect(fourK.isLossless(2), isTrue);
      expect(fourK.maxZoom, 4);

      // An 8K source: lossless × 2 beats cover × 4.
      const ClipFrameGeometry eightK = ClipFrameGeometry(
        sourceWidth: 7680,
        sourceHeight: 4320,
        canvasWidth: 1920,
        canvasHeight: 1080,
      );
      expect(eightK.losslessScale, 4);
      expect(eightK.maxZoom, 8);

      // A small source on a 4K canvas is enlarged even at fit.
      const ClipFrameGeometry small = ClipFrameGeometry(
        sourceWidth: 1280,
        sourceHeight: 720,
        canvasWidth: 3840,
        canvasHeight: 2160,
      );
      expect(small.losslessScale, closeTo(1 / 3, 1e-9));
      expect(small.isLossless(small.fitScale), isFalse);
    });
  });

  group('clamping', () {
    test('the scale stays between fit and maxZoom', () {
      const ClipFrameGeometry g = _landscapeOnPortrait;
      expect(g.clamp(const ClipFrame(scale: 0.1)).scale, g.fitScale);
      expect(g.clamp(const ClipFrame(scale: 99)).scale, g.maxZoom);
      expect(g.clamp(const ClipFrame(scale: 1)).scale, 1);
    });

    test('at cover and past it the picture may move until its edge meets '
        'the canvas\'s: no bar ever appears', () {
      // 2× on the same-shape canvas: the picture is two canvases wide and
      // high, so it may move half a canvas each way before an edge shows.
      final ClipFrame moved = _landscapeOnLandscape.clamp(
        const ClipFrame(scale: 2, dx: 1, dy: -1),
      );
      expect(moved, const ClipFrame(scale: 2, dx: 0.5, dy: -0.5));
      expect(
        _landscapeOnLandscape.clamp(const ClipFrame(scale: 2, dx: 0.1)),
        const ClipFrame(scale: 2, dx: 0.1),
      );
      // Exactly cover: nothing may move.
      expect(
        _landscapeOnLandscape.clamp(const ClipFrame(scale: 1, dx: 0.3)),
        const ClipFrame(scale: 1),
      );
      // A landscape source covering a portrait canvas overflows sideways
      // only: it may slide left and right, never up or down.
      final ClipFrame cover = _landscapeOnPortrait.clamp(
        const ClipFrame(scale: _crossCover, dx: 5, dy: 5),
      );
      expect(cover.dx, closeTo((_crossCover * _crossCover - 1) / 2, 1e-9));
      expect(cover.dy, closeTo(0, 1e-9));
    });

    test('below cover the picture stays inside the canvas: it may move '
        'within its bars, never out of the canvas', () {
      // At fit a landscape source on a portrait canvas spans the width and
      // leaves bars above and below: it may slide up and down within them.
      final ClipFrame fit = _landscapeOnPortrait.clamp(
        const ClipFrame(scale: _crossFit, dx: 1, dy: 1),
      );
      expect(fit.dx, closeTo(0, 1e-9));
      expect(fit.dy, closeTo((1 - _crossFit * _crossFit) / 2, 1e-9));
      // Between fit and cover: sideways it overflows (no bar), vertically
      // it has bars (stays inside).
      final ClipFrame between = _landscapeOnPortrait.clamp(
        const ClipFrame(scale: 1, dx: -1, dy: -1),
      );
      final ({double width, double height}) shown = _landscapeOnPortrait
          .shownAt(1);
      expect(between.dx, closeTo(-(shown.width - 1) / 2, 1e-9));
      expect(between.dy, closeTo(-(1 - shown.height) / 2, 1e-9));
    });

    test('the fill survives a clamp', () {
      expect(
        _portraitOnPortrait
            .clamp(const ClipFrame(scale: 9, fill: FrameFill.blur))
            .fill,
        FrameFill.blur,
      );
    });
  });

  group('fromCrop', () {
    // Today's `ClipFraming.whole` for a 16:9 source on a 9:16 canvas.
    const ClipCrop wholeOnPortrait = ClipCrop(
      left: (1 - 0.31640625) / 2,
      top: 0,
      width: 0.31640625,
      height: 1,
    );

    test('the whole crop (today\'s default) is cover, centred', () {
      final ClipFrame frame = ClipFrame.fromCrop(
        wholeOnPortrait,
        geometry: _landscapeOnPortrait,
      );
      expect(frame.scale, closeTo(_crossCover, 1e-9));
      expect(frame.dx, closeTo(0, 1e-9));
      expect(frame.dy, closeTo(0, 1e-9));
      expect(frame.fill, FrameFill.black);

      final ClipFrame same = ClipFrame.fromCrop(
        const ClipCrop(left: 0, top: 0, width: 1, height: 1),
        geometry: _portraitOnPortrait,
        fill: FrameFill.blur,
      );
      expect(same, const ClipFrame(scale: 1, fill: FrameFill.blur));
    });

    test('a zoomed, panned crop becomes the matching scale and offset: the '
        'part\'s centre lands on the canvas\'s centre', () {
      // Half the source each way, from its top-left corner: 2× cover.
      final ClipFrame corner = ClipFrame.fromCrop(
        const ClipCrop(left: 0, top: 0, width: 0.5, height: 0.5),
        geometry: _landscapeOnLandscape,
      );
      expect(corner.scale, closeTo(2, 1e-9));
      // The source's centre is a quarter of the source (half a canvas, at
      // 2×) to the right of and below the part's centre: exactly as far as
      // the clamp allows, the corner.
      expect(corner.dx, closeTo(0.5, 1e-9));
      expect(corner.dy, closeTo(0.5, 1e-9));

      // The portrait case: a part at the right end of a landscape source.
      final ClipFrame right = ClipFrame.fromCrop(
        const ClipCrop(
          left: 1 - 0.31640625,
          top: 0,
          width: 0.31640625,
          height: 1,
        ),
        geometry: _landscapeOnPortrait,
      );
      expect(right.scale, closeTo(_crossCover, 1e-9));
      expect(right.dx, lessThan(0));
      expect(right.dx, closeTo(-(_crossCover * _crossCover - 1) / 2, 1e-9));
      expect(right.dy, closeTo(0, 1e-9));
    });

    // Today's argv without a frame: fitted into a landscape canvas, covering
    // a portrait one. Such a frame is stored as none.
    test('the default frame is fit on a landscape canvas and cover on a '
        'portrait one; a frame is the default when it shows the same, with '
        'black bars or none; fills says whether a bar is left', () {
      expect(_landscapeOnLandscape.defaultFrame, const ClipFrame(scale: 1));
      expect(_portraitOnLandscape.defaultFrame.scale, closeTo(_crossFit, 1e-9));
      expect(
        _landscapeOnPortrait.defaultFrame.scale,
        closeTo(_crossCover, 1e-9),
      );

      expect(
        _landscapeOnLandscape.isDefault(const ClipFrame(scale: 1)),
        isTrue,
      );
      expect(
        _landscapeOnLandscape.isDefault(
          const ClipFrame(scale: 1, fill: FrameFill.blur),
        ),
        isTrue,
      );
      expect(
        _landscapeOnLandscape.isDefault(const ClipFrame(scale: 1.01)),
        isFalse,
      );
      expect(
        _portraitOnLandscape.isDefault(const ClipFrame(scale: _crossFit)),
        isTrue,
      );
      expect(
        _portraitOnLandscape.isDefault(
          const ClipFrame(scale: _crossFit, fill: FrameFill.blur),
        ),
        isFalse,
      );
      expect(
        _portraitOnLandscape.isDefault(
          const ClipFrame(scale: _crossFit, dx: 0.1),
        ),
        isFalse,
      );

      expect(
        _portraitOnLandscape.fills(const ClipFrame(scale: _crossFit)),
        isFalse,
      );
      expect(
        _portraitOnLandscape.fills(const ClipFrame(scale: _crossCover)),
        isTrue,
      );
      expect(_landscapeOnLandscape.fills(const ClipFrame(scale: 1)), isTrue);
    });

    test('fit and cover constructors and copyWith', () {
      expect(
        ClipFrame.fit(_landscapeOnPortrait).scale,
        closeTo(_crossFit, 1e-9),
      );
      expect(
        ClipFrame.cover(_landscapeOnPortrait, fill: FrameFill.blur),
        const ClipFrame(scale: _crossCover, fill: FrameFill.blur),
      );
      expect(
        const ClipFrame(scale: 1).copyWith(dx: 0.1, fill: FrameFill.blur),
        const ClipFrame(scale: 1, dx: 0.1, fill: FrameFill.blur),
      );
    });
  });
}
