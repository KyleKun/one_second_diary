import 'dart:math' as math;

import 'package:one_second_diary/core/media/types/clip_crop.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';

/// Fits a clip of any size into a profile's canvas (`ClipFormat.width` ×
/// `height`).
///
/// The one place that decides the canvas fit, shared by the video save, the
/// photo save, the clip normalisation for movies and the profile
/// conversion, so all agree. The canvas comes from the PROFILE's format,
/// never from the clip: movies are stream-copy joins, so every clip of a
/// profile must share it.
///
/// No `-noautorotate` goes with it: ffmpeg's default autorotate applies the
/// phone's rotation metadata before this filter, and the output carries none.
abstract final class CanvasFilter {
  /// The `-vf` fragment that fits a clip into [format]'s canvas:
  ///
  /// - landscape fits inside the canvas with centred black bars;
  /// - portrait fills the canvas and centre-crops, so a portrait profile
  ///   never shows letterboxing.
  ///
  /// With a [crop] (the clip editor's, in the canvas's shape), only that
  /// part of the source is kept and it fills the canvas, either way: the
  /// part is cut first, in fractions of the upright source, then scaled to
  /// cover the canvas and trimmed to it (ffmpeg rounds the cut to whole
  /// pixels, so the part is a hair off the canvas's shape; covering never
  /// leaves a bar).
  ///
  /// ffmpeg resolves the source size at run time (`iw`, `ih`), and the output
  /// is always exactly the canvas, so encoders never see odd dimensions.
  /// At 1080p the two shapes are byte for byte what earlier versions wrote.
  static String scaleFilter(ClipFormat format, {ClipCrop? crop}) {
    final int width = format.width;
    final int height = format.height;
    if (crop != null) {
      return 'crop=iw*${_fraction(crop.width)}:ih*${_fraction(crop.height)}:'
          'iw*${_fraction(crop.left)}:ih*${_fraction(crop.top)},'
          'scale=$width:$height:force_original_aspect_ratio=increase,'
          'crop=$width:$height';
    }
    return switch (format.orientation) {
      VideoOrientation.landscape =>
        'scale=$width:$height:force_original_aspect_ratio=decrease,'
            'pad=$width:$height:(ow-iw)/2:(oh-ih)/2:black',
      VideoOrientation.portrait =>
        'scale=$width:$height:force_original_aspect_ratio=increase,'
            'crop=$width:$height',
    };
  }

  /// The blur's strength behind a framed source, as a `gblur=sigma=` on
  /// the full-size picture: the look the editor's preview matches
  /// (`FrameViewport.blurSigmaPer1080`).
  static const int blurSigma = 20;

  /// The background is blurred at a fraction of its size and scaled back
  /// up (see [blurGraph]): the covering copy's sides divided by this, in
  /// even pixels, with the sigma divided by it too (`20 ÷ 8 = 2.5`), so
  /// the blur spans the same part of the picture.
  static const int blurScaleDown = 8;

  /// The smallest side of the blur's working picture.
  static const int blurMinSide = 2;

  /// Whether [frame] on [format]'s canvas is rendered through the
  /// `-filter_complex` graph of [blurGraph]: a blur fill with bars to fill.
  /// A frame that leaves no bar takes the plain chain of [frameFilter]
  /// whatever its fill, and so does a black fill.
  static bool needsBlurGraph(ClipFormat format, SourceFrame frame) =>
      frame.frame.fill == FrameFill.blur && _placementOf(format, frame).hasBars;

  /// The `-vf` fragment that places [frame]'s source on [format]'s canvas
  /// with black bars: `scale=<w>:<h>` (the
  /// source at the frame's scale), `crop=<visible>` when it overflows the
  /// canvas on a side, `pad=<canvas>:<x>:<y>:black` when it leaves a bar.
  /// Every number is a whole, even pixel count computed here (so no filter
  /// rounds it again for the 4:2:0 chroma), never an `iw`/`ih` expression,
  /// and the output is exactly the canvas. The frame is clamped first
  /// (`ClipFrameGeometry.clamp`), as the editor clamps it.
  static String frameFilter(ClipFormat format, SourceFrame frame) =>
      _placementOf(format, frame).chain;

  /// The `-filter_complex` graph that places [frame]'s source on a blurred,
  /// canvas-covering copy of itself (the blur fill): [input] (`1:v`, the
  /// save's source) is split, one copy scaled to cover the canvas, blurred
  /// and centre-cropped, the other scaled (and cut) as [frameFilter] does,
  /// then overlaid at the frame's position. The graph ends at the overlay
  /// with no output label: the stamps follow it, then the label. Null when
  /// the frame leaves no bar ([needsBlurGraph]).
  ///
  /// The blur runs small: the copy is scaled down to the covering size ÷
  /// [blurScaleDown] (even pixels, at least [blurMinSide]), blurred with
  /// the sigma divided the same way, then scaled back up to the covering
  /// size (bilinear: nothing sharper than the blur is left to keep) and
  /// cropped to the canvas. A Gaussian over a full 4K frame, sixty times a
  /// second, was most of a save's filter time; over 1/64 of the pixels it
  /// is nothing, and the picture is the same blur.
  static String? blurGraph(
    ClipFormat format,
    SourceFrame frame, {
    required String input,
  }) {
    final _Placement placement = _placementOf(format, frame);
    if (frame.frame.fill != FrameFill.blur || !placement.hasBars) return null;
    final ClipFrameGeometry geometry = frame.geometryOn(format);
    // The covering copy: at least the canvas on both sides.
    final double cover = geometry.magnificationAt(geometry.coverScale);
    final int coverWidth = math.max(
      format.width,
      _evenCeil(frame.sourceWidth * cover),
    );
    final int coverHeight = math.max(
      format.height,
      _evenCeil(frame.sourceHeight * cover),
    );
    final int coverX = _even((coverWidth - format.width) / 2);
    final int coverY = _even((coverHeight - format.height) / 2);
    final int smallWidth = math.max(
      blurMinSide,
      _even(coverWidth / blurScaleDown),
    );
    final int smallHeight = math.max(
      blurMinSide,
      _even(coverHeight / blurScaleDown),
    );
    const double sigma = blurSigma / blurScaleDown;
    return '[$input]split[bg][fg];'
        '[bg]scale=$smallWidth:$smallHeight,gblur=sigma=$sigma,'
        'scale=$coverWidth:$coverHeight:flags=bilinear,'
        'crop=${format.width}:${format.height}:$coverX:$coverY[b];'
        '[fg]${placement.scaleAndCut}[f];'
        '[b][f]overlay=${placement.x}:${placement.y}';
  }

  /// Where [frame]'s source lands on [format]'s canvas, in whole pixels.
  static _Placement _placementOf(ClipFormat format, SourceFrame frame) {
    final ClipFrameGeometry geometry = frame.geometryOn(format);
    final ClipFrame clamped = geometry.clamp(frame.frame);
    final double magnification = geometry.magnificationAt(clamped.scale);
    final int width = _even(frame.sourceWidth * magnification);
    final int height = _even(frame.sourceHeight * magnification);
    // The source's top-left corner on the canvas (negative: overflow).
    final int left = _even(
      (format.width - width) / 2 + clamped.dx * format.width,
    );
    final int top = _even(
      (format.height - height) / 2 + clamped.dy * format.height,
    );
    final int cutX = math.max(0, -left);
    final int cutY = math.max(0, -top);
    final int x = math.max(0, left);
    final int y = math.max(0, top);
    return _Placement(
      canvasWidth: format.width,
      canvasHeight: format.height,
      width: width,
      height: height,
      cutX: cutX,
      cutY: cutY,
      visibleWidth: math.min(width - cutX, format.width - x),
      visibleHeight: math.min(height - cutY, format.height - y),
      x: x,
      y: y,
    );
  }

  /// A fraction of the source for a filter expression: within 0..1, six
  /// decimals, never in exponent form.
  static String _fraction(double value) =>
      value.clamp(0.0, 1.0).toStringAsFixed(6);

  /// [value] rounded to the nearest even whole number.
  static int _even(double value) => (value / 2).round() * 2;

  /// [value] rounded up to an even whole number (a hair under a whole
  /// number, from the floating-point maths, counts as that number).
  static int _evenCeil(double value) => ((value - 1e-6) / 2).ceil() * 2;
}

/// A scaled source on the canvas: its size, the part of it inside the
/// canvas (cut from [cutX], [cutY]) and where that part sits ([x], [y]).
final class _Placement {
  const _Placement({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.width,
    required this.height,
    required this.cutX,
    required this.cutY,
    required this.visibleWidth,
    required this.visibleHeight,
    required this.x,
    required this.y,
  });

  final int canvasWidth;
  final int canvasHeight;
  final int width;
  final int height;
  final int cutX;
  final int cutY;
  final int visibleWidth;
  final int visibleHeight;
  final int x;
  final int y;

  /// Whether a part of the source lies outside the canvas.
  bool get overflows => visibleWidth < width || visibleHeight < height;

  /// Whether the source leaves a bar on a side.
  bool get hasBars =>
      visibleWidth < canvasWidth || visibleHeight < canvasHeight;

  /// `scale=<w>:<h>[,crop=<visible>:<cut>]`.
  String get scaleAndCut =>
      'scale=$width:$height'
      '${overflows ? ',crop=$visibleWidth:$visibleHeight:$cutX:$cutY' : ''}';

  /// [scaleAndCut] then the black pad to the canvas when a bar remains.
  String get chain =>
      '$scaleAndCut'
      '${hasBars ? ',pad=$canvasWidth:$canvasHeight:$x:$y:black' : ''}';
}
