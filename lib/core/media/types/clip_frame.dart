import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:one_second_diary/core/media/types/clip_crop.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';

/// What fills the canvas around a source that does not cover it.
enum FrameFill {
  /// Black bars.
  black,

  /// A blurred, canvas-covering copy of the picture.
  blur,
}

/// How a source sits on the profile's canvas:
/// zoomed from "fit" (the whole picture, with bars) through "cover" (no
/// bars) to a close crop, and moved.
///
/// - [scale]: the source's short side shown as a fraction of the canvas's
///   short side; see [ClipFrameGeometry] for the fit, cover, lossless and
///   maximum values of a source on a canvas.
/// - [dx], [dy]: the source's centre offset from the canvas's centre, in
///   fractions of the canvas's width and height. On an axis the picture
///   fills, no bar may appear; on one it does not, the picture stays inside
///   the canvas ([ClipFrameGeometry.clamp]).
///
/// Pure values: the editor's sheet and the engine's
/// `CanvasFilter.frameFilter` both read it, nothing here touches ffmpeg or
/// Flutter. Lives beside `ClipCrop` in the media core, which the engine
/// may import (the feature layers import the core, never the reverse).
final class ClipFrame extends Equatable {
  const ClipFrame({
    required this.scale,
    this.dx = 0,
    this.dy = 0,
    this.fill = FrameFill.black,
  });

  /// The whole source visible, centred, with bars where its shape differs
  /// from the canvas's.
  ClipFrame.fit(ClipFrameGeometry geometry, {FrameFill fill = FrameFill.black})
    : this(scale: geometry.fitScale, fill: fill);

  /// The source covering the canvas, centred, no bars.
  ClipFrame.cover(
    ClipFrameGeometry geometry, {
    FrameFill fill = FrameFill.black,
  }) : this(scale: geometry.coverScale, fill: fill);

  /// The frame that shows exactly what [crop] (a part of the source in the
  /// canvas's shape, filling it) shows: every stored draft and fixture
  /// still means the same picture. Always at or past cover.
  factory ClipFrame.fromCrop(
    ClipCrop crop, {
    required ClipFrameGeometry geometry,
    FrameFill fill = FrameFill.black,
  }) {
    // The part fills the canvas: the magnification that covers it.
    final double magnification = math.max(
      geometry.canvasWidth / (crop.width * geometry.sourceWidth),
      geometry.canvasHeight / (crop.height * geometry.sourceHeight),
    );
    final double scale =
        magnification * geometry.sourceShort / geometry.canvasShort;
    // The part's centre sits at the canvas's centre, so the source's centre
    // is offset by the distance between the two, in canvas fractions.
    final double centreX = crop.left + crop.width / 2;
    final double centreY = crop.top + crop.height / 2;
    return geometry.clamp(
      ClipFrame(
        scale: scale,
        dx:
            (.5 - centreX) *
            geometry.sourceWidth *
            magnification /
            geometry.canvasWidth,
        dy:
            (.5 - centreY) *
            geometry.sourceHeight *
            magnification /
            geometry.canvasHeight,
        fill: fill,
      ),
    );
  }

  final double scale;
  final double dx;
  final double dy;
  final FrameFill fill;

  ClipFrame copyWith({
    double? scale,
    double? dx,
    double? dy,
    FrameFill? fill,
  }) => ClipFrame(
    scale: scale ?? this.scale,
    dx: dx ?? this.dx,
    dy: dy ?? this.dy,
    fill: fill ?? this.fill,
  );

  @override
  List<Object?> get props => <Object?>[scale, dx, dy, fill];
}

/// The maths of one source on one canvas, in whole pixels of each: the
/// scales that matter and the clamps that keep a [ClipFrame] sensible.
final class ClipFrameGeometry extends Equatable {
  const ClipFrameGeometry({
    required this.sourceWidth,
    required this.sourceHeight,
    required this.canvasWidth,
    required this.canvasHeight,
  }) : assert(sourceWidth > 0 && sourceHeight > 0, 'a source has pixels'),
       assert(canvasWidth > 0 && canvasHeight > 0, 'a canvas has pixels');

  /// The source's size, upright (after the phone's rotation).
  final int sourceWidth;
  final int sourceHeight;

  /// The profile's canvas (`ClipFormat.width`, `height`).
  final int canvasWidth;
  final int canvasHeight;

  /// Past cover, the close crop a 1080p source still allows (a quarter of
  /// its pixels each way).
  static const double closeCrop = 4;

  /// Past lossless, how far a sharper source may be enlarged for free.
  static const double losslessRoom = 2;

  int get sourceShort => math.min(sourceWidth, sourceHeight);
  int get canvasShort => math.min(canvasWidth, canvasHeight);

  /// The whole source visible: the smaller magnification that fits it.
  double get fitScale => _scaleOf(math.min(_widthRatio, _heightRatio));

  /// No bars: the larger magnification that covers the canvas.
  double get coverScale => _scaleOf(math.max(_widthRatio, _heightRatio));

  /// One source pixel per canvas pixel: up to here the clip loses no
  /// detail; past it the picture is enlarged. Below 1 the source is
  /// smaller than the canvas and is enlarged even at fit.
  double get losslessScale => sourceShort / canvasShort;

  /// The closest zoom: [closeCrop] × cover, or [losslessRoom] × lossless,
  /// whichever is larger.
  double get maxZoom =>
      math.max(coverScale * closeCrop, losslessScale * losslessRoom);

  /// Whether a frame at [scale] enlarges no pixel.
  bool isLossless(double scale) => scale <= losslessScale + _epsilon;

  /// Whether [frame] leaves no bar: the picture covers the canvas on both
  /// axes.
  bool fills(ClipFrame frame) {
    final ({double width, double height}) shown = shownAt(frame.scale);
    return shown.width >= 1 - _epsilon && shown.height >= 1 - _epsilon;
  }

  /// The framing of a clip saved without a frame:
  /// the whole source fitted into a landscape
  /// canvas (the export pads with black), the source covering a portrait
  /// one (it crops). Centred, black bars.
  ClipFrame get defaultFrame =>
      canvasWidth >= canvasHeight ? ClipFrame.fit(this) : ClipFrame.cover(this);

  /// Whether [frame] shows what [defaultFrame] shows: the same scale and
  /// position, and either black bars or none at all (a blur fill with no
  /// bar to blur changes nothing). The editor stores such a frame as
  /// none, so the argv stays what it was.
  bool isDefault(ClipFrame frame) {
    final ClipFrame normal = defaultFrame;
    return (frame.scale - normal.scale).abs() <= _sameScale &&
        frame.dx.abs() <= _sameOffset &&
        frame.dy.abs() <= _sameOffset &&
        (frame.fill == FrameFill.black || fills(frame));
  }

  /// How close two scales or offsets must be to count as the same.
  static const double _sameScale = 1e-6;
  static const double _sameOffset = 1e-6;

  /// Canvas pixels per source pixel at [scale].
  double magnificationAt(double scale) => scale * canvasShort / sourceShort;

  /// The source's shown size at [scale], as fractions of the canvas's
  /// width and height (1 = exactly the canvas's side).
  ({double width, double height}) shownAt(double scale) {
    final double magnification = magnificationAt(scale);
    return (
      width: magnification * sourceWidth / canvasWidth,
      height: magnification * sourceHeight / canvasHeight,
    );
  }

  /// [scale] kept between [fitScale] and [maxZoom].
  double clampScale(double scale) => scale.clamp(fitScale, maxZoom);

  /// [frame] with its scale within [fitScale]..[maxZoom] and its offsets
  /// within what that scale allows: on an axis the picture fills, it may
  /// move until its edge meets the canvas's (no bar appears); on an axis it
  /// does not, it may move until it touches the canvas's edge (it never
  /// leaves the canvas).
  ClipFrame clamp(ClipFrame frame) {
    final double scale = clampScale(frame.scale);
    final ({double width, double height}) shown = shownAt(scale);
    return ClipFrame(
      scale: scale,
      dx: _clampOffset(frame.dx, shown.width),
      dy: _clampOffset(frame.dy, shown.height),
      fill: frame.fill,
    );
  }

  /// Either way the bound is half the difference between the picture's
  /// side and the canvas's: the overflow when it fills, the room when it
  /// does not.
  static double _clampOffset(double offset, double shownFraction) {
    final double bound = (shownFraction - 1).abs() / 2;
    return offset.clamp(-bound, bound);
  }

  double get _widthRatio => canvasWidth / sourceWidth;
  double get _heightRatio => canvasHeight / sourceHeight;

  /// The [scale] of a magnification (canvas pixels per source pixel).
  double _scaleOf(double magnification) =>
      magnification * sourceShort / canvasShort;

  static const double _epsilon = 1e-9;

  @override
  List<Object?> get props => <Object?>[
    sourceWidth,
    sourceHeight,
    canvasWidth,
    canvasHeight,
  ];
}

/// A [ClipFrame] of a source whose size is known, as a save request
/// carries it: the engine computes the filter's pixels from the two
/// (`CanvasFilter.frameFilter`), so the argv holds whole numbers and never
/// `iw`/`ih` expressions.
final class SourceFrame extends Equatable {
  const SourceFrame({
    required this.frame,
    required this.sourceWidth,
    required this.sourceHeight,
  }) : assert(sourceWidth > 0 && sourceHeight > 0, 'a source has pixels');

  final ClipFrame frame;

  /// The source's size, upright (after the phone's rotation), as the
  /// editor's player reports it.
  final int sourceWidth;
  final int sourceHeight;

  /// The geometry of this source on [format]'s canvas.
  ClipFrameGeometry geometryOn(ClipFormat format) => ClipFrameGeometry(
    sourceWidth: sourceWidth,
    sourceHeight: sourceHeight,
    canvasWidth: format.width,
    canvasHeight: format.height,
  );

  @override
  List<Object?> get props => <Object?>[frame, sourceWidth, sourceHeight];
}
