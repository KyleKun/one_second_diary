import 'dart:io';

import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/policy/photo_zoom.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/frame_viewport.dart';
import 'package:one_second_diary/shared/widgets/surfaces/player_error_block.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The photo source in the editor's preview: the still the clip holds,
/// decoded at the preview's size, never at the photo's full size.
///
/// Once decoded it says its shape (width / height, as shown) through
/// [onDecoded], for the "fitted to" note. With [zoomDurationMs] it plays the
/// clip's slow zoom (`PhotoZoom`) on a loop, the whole canvas as the save
/// zooms it; under reduced motion it holds still.
class PhotoSourcePreview extends StatelessWidget {
  const PhotoSourcePreview({
    super.key,
    required this.path,
    required this.canvasAspectRatio,
    this.frame,
    this.aspectRatio,
    this.onDecoded,
    this.zoomDurationMs,
  });

  static const Key imageKey = Key('photoSourcePreview.image');

  final String path;

  /// The canvas's width / height: the photo is fitted into a landscape
  /// canvas (the export pads) and covers a portrait one (it crops).
  final double canvasAspectRatio;

  /// How the photo sits on the canvas instead, when the clip is framed; it
  /// needs the photo's [aspectRatio] (width / height).
  final ClipFrame? frame;
  final double? aspectRatio;

  /// Called with the photo's width / height once it is decoded.
  final ValueChanged<double>? onDecoded;

  /// The clip's length when the photo zooms; null holds it still.
  final int? zoomDurationMs;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double pixelRatio = MediaQuery.devicePixelRatioOf(context);
      final int height = (constraints.maxHeight * pixelRatio).round();
      // `contain` fits the still inside the canvas. `cover` fills the 9:16
      // portrait canvas, which any photo wider than 9:16 does by height:
      // fitted inside the box instead, a 4:3 photo would be decoded 3.2
      // times too small and shown blurred.
      final BoxFit fit = canvasAspectRatio >= 1 ? BoxFit.contain : BoxFit.cover;
      final ClipFrame? frame = this.frame;
      final double? aspectRatio = this.aspectRatio;
      final bool framed = frame != null && aspectRatio != null;
      // A frame may show a part of the photo larger than the box: it is
      // decoded at one size for every zoom.
      final ImageProvider image = framed
          ? FrameViewport.photo(path)
          : fit == BoxFit.cover
          ? ResizeImage(FileImage(File(path)), height: height)
          : ResizeImage(
              FileImage(File(path)),
              width: (constraints.maxWidth * pixelRatio).round(),
              height: height,
              policy: ResizeImagePolicy.fit,
            );
      final Widget photo = Image(
        key: imageKey,
        image: image,
        fit: framed ? BoxFit.fill : fit,
        width: framed ? null : constraints.maxWidth,
        height: framed ? null : constraints.maxHeight,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            Center(
              child: PlayerErrorBlock(
                title: Strings.playerErrorTitle,
                body: Strings.playerErrorBody,
              ),
            ),
      );
      final Widget canvas = framed
          ? FrameViewport(
              aspectRatio: aspectRatio,
              canvasAspectRatio: canvasAspectRatio,
              frame: frame,
              blurred: Image(
                image: image,
                fit: BoxFit.fill,
                gaplessPlayback: true,
                excludeFromSemantics: true,
              ),
              child: photo,
            )
          : photo;
      final int? zoomDurationMs = this.zoomDurationMs;
      return _DecodedShape(
        image: image,
        onDecoded: onDecoded,
        child: zoomDurationMs == null || OsdMotion.reduced(context)
            ? canvas
            : _ZoomLoop(durationMs: zoomDurationMs, child: canvas),
      );
    },
  );
}

/// [child] zooming from the whole canvas to [PhotoZoom.endScale] over
/// [durationMs], again and again.
class _ZoomLoop extends StatefulWidget {
  const _ZoomLoop({required this.durationMs, required this.child});

  final int durationMs;
  final Widget child;

  @override
  State<_ZoomLoop> createState() => _ZoomLoopState();
}

class _ZoomLoopState extends State<_ZoomLoop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.durationMs),
  )..repeat();

  @override
  void didUpdateWidget(_ZoomLoop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.durationMs == oldWidget.durationMs) return;
    _progress
      ..duration = Duration(milliseconds: widget.durationMs)
      ..repeat();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    builder: (BuildContext context, Widget? child) => Transform.scale(
      scale: PhotoZoom.scaleAt(_progress.value, durationMs: widget.durationMs),
      child: child,
    ),
    child: widget.child,
  );
}

/// Listens to [image]'s stream (the one [child] shows, so it is decoded
/// once) and reports the decoded shape. The fit policy keeps the photo's
/// proportions.
class _DecodedShape extends StatefulWidget {
  const _DecodedShape({
    required this.image,
    required this.onDecoded,
    required this.child,
  });

  final ImageProvider image;
  final ValueChanged<double>? onDecoded;
  final Widget child;

  @override
  State<_DecodedShape> createState() => _DecodedShapeState();
}

class _DecodedShapeState extends State<_DecodedShape> {
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(_decoded);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_DecodedShape oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.image != oldWidget.image) _resolve();
  }

  void _resolve() {
    if (widget.onDecoded == null) return;
    final ImageStream stream = widget.image.resolve(
      createLocalImageConfiguration(context),
    );
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _decoded(ImageInfo info, bool synchronousCall) {
    final int width = info.image.width;
    final int height = info.image.height;
    info.dispose();
    if (height == 0) return;
    void report() {
      if (mounted) widget.onDecoded?.call(width / height);
    }

    // A cached photo answers while this builds: report after the frame.
    if (synchronousCall) {
      WidgetsBinding.instance.addPostFrameCallback((_) => report());
    } else {
      report();
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
