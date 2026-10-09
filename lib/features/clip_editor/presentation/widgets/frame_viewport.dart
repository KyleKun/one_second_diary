import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/theme/osd_media.dart';

/// The source on a canvas, the way the export makes it (`frameFilter`):
/// [frame] places it (zoomed from fit, with bars, to a close crop, and
/// moved), the bars black or a blurred copy of the picture; without a
/// frame, today's default: the whole source fitted into a landscape canvas
/// (padded), the source covering a portrait one (cropped).
///
/// The box it is given is the canvas. [child] is the whole source and
/// takes any size; [blurred] is a second view of it for the blur fill (a
/// video's texture built again, a photo's image), built only when there
/// is a bar to fill. Everything is in fractions, so the real pixel sizes
/// are not needed: [aspectRatio] is the source's width / height,
/// [canvasAspectRatio] the canvas's.
class FrameViewport extends StatelessWidget {
  const FrameViewport({
    super.key,
    required this.aspectRatio,
    required this.canvasAspectRatio,
    required this.frame,
    required this.child,
    this.blurred,
  });

  /// The longest side a photo is decoded at for a frame, whatever the zoom:
  /// one decode serves the editor's preview and the framing sheet.
  static const int _photoDecodeSide = 2048;

  /// The blur of the fill behind a zoomed-out source, in px of the canvas
  /// at 1080p (`frameFilter`'s `gblur=sigma=20`), scaled to the box.
  static const double blurSigmaPer1080 = 20;

  /// The photo at [path] as a frame shows it.
  static ImageProvider photo(String path) => ResizeImage(
    FileImage(File(path)),
    width: _photoDecodeSide,
    height: _photoDecodeSide,
    policy: ResizeImagePolicy.fit,
  );

  /// The source's width / height.
  final double aspectRatio;

  /// The canvas's width / height.
  final double canvasAspectRatio;

  final ClipFrame? frame;

  final Widget child;

  /// The source again, for the blur fill; null paints black bars instead.
  final Widget? blurred;

  /// The geometry of a source of [aspectRatio] on a canvas of
  /// [canvasAspectRatio], in fractions: the short sides are 1000 px, so
  /// only the shapes matter (the pixel sizes decide lossless, not this).
  static ClipFrameGeometry geometryOf({
    required double aspectRatio,
    required double canvasAspectRatio,
  }) => ClipFrameGeometry(
    sourceWidth: (1000 * (aspectRatio >= 1 ? aspectRatio : 1)).round(),
    sourceHeight: (1000 * (aspectRatio >= 1 ? 1 : 1 / aspectRatio)).round(),
    canvasWidth: (1000 * (canvasAspectRatio >= 1 ? canvasAspectRatio : 1))
        .round(),
    canvasHeight: (1000 * (canvasAspectRatio >= 1 ? 1 : 1 / canvasAspectRatio))
        .round(),
  );

  @override
  Widget build(BuildContext context) {
    final ClipFrame? frame = this.frame;
    if (frame == null) {
      return ClipRect(
        child: FittedBox(
          fit: canvasAspectRatio >= 1 ? BoxFit.contain : BoxFit.cover,
          child: SizedBox(width: 100 * aspectRatio, height: 100, child: child),
        ),
      );
    }
    final ClipFrameGeometry geometry = geometryOf(
      aspectRatio: aspectRatio,
      canvasAspectRatio: canvasAspectRatio,
    );
    final ({double width, double height}) shown = geometry.shownAt(frame.scale);
    final bool bars = !geometry.fills(frame);
    final Widget? blurred = this.blurred;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double boxWidth = constraints.maxWidth;
        final double boxHeight = constraints.maxHeight;
        final double width = boxWidth * shown.width;
        final double height = boxHeight * shown.height;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            const Positioned.fill(child: ColoredBox(color: OsdMedia.letterbox)),
            if (bars && frame.fill == FrameFill.blur && blurred != null)
              Positioned.fill(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: blurSigmaPer1080 * boxHeight / 1080,
                    sigmaY: blurSigmaPer1080 * boxHeight / 1080,
                    tileMode: TileMode.clamp,
                  ),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: 100 * aspectRatio,
                      height: 100,
                      child: blurred,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: boxWidth * (.5 + frame.dx) - width / 2,
              top: boxHeight * (.5 + frame.dy) - height / 2,
              width: width,
              height: height,
              child: child,
            ),
          ],
        );
      },
    );
  }
}
