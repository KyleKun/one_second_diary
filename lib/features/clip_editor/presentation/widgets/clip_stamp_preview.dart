import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/media/policy/stamp_filter.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/features/clip_editor/data/filmstrip_frames.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/edit_clip_stamps.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/frame_viewport.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';

/// The date stamp sheet's preview tile: a close-up of the corner of the clip where the date is burned in, as the export makes it.
///
/// A window onto the clip's canvas (source as framed, under the burned stamps of `EditClipStamps`) at half the export's size on a 1080p canvas,
/// scaled by the same factor at every tier. The window ignores the chosen text size, so a small or large stamp shows smaller or larger in it.
/// A numeric date shows the top right corner, a written one the bottom left; another format slides the window there. A place burned in the same row shows too.
///
/// A video's frame is made at the trim window's start (`FilmstripFrames.frameAt`, off the UI thread); black until it is there or when it can't be made.
class ClipStampPreview extends StatelessWidget {
  const ClipStampPreview({super.key, required this.format});

  /// The frame behind the date.
  static const Key backdropKey = Key('clipStampPreview.backdrop');

  static const double height = 64;

  /// The tile's px per px of a 1080p canvas: half, which centres the
  /// stamp's line (48 px of the canvas, between two margins) in the tile's
  /// height.
  static const double _closeUp =
      height / (2 * StampFilter.marginPx + StampFilter.fontSizePx * 1.2);

  /// The short side the stamp's px are given for.
  static const int _stampShortSide = 1080;

  /// The longest side a video's frame is made at.
  static const int _frameSide = 1920;

  /// The format of the profile the clip goes to: its canvas.
  final ClipFormat format;

  @override
  Widget build(BuildContext context) {
    final ClipSource source = context.select(
      (EditClipCubit editor) => editor.state.args.source,
    );
    final int? startMs = context.select(
      (EditClipCubit editor) => editor.state.trim?.startMs,
    );
    final double? aspectRatio = context.select(
      (EditClipCubit editor) => editor.state.sourceAspectRatio,
    );
    final ClipFrame? frame = context.select(
      (EditClipCubit editor) => editor.state.draft.frameFor(format.orientation),
    );
    final bool written = context.select(
      (EditClipCubit editor) =>
          editor.state.draft.stamp.format == StampFormat.written,
    );
    final int canvasWidth = format.width;
    final int canvasHeight = format.height;
    // The stamp's px per 1080p px on this canvas.
    final double k = format.shortSide / _stampShortSide;

    Widget picture(ImageProvider? image) => image == null || aspectRatio == null
        ? const SizedBox.expand()
        : FrameViewport(
            aspectRatio: aspectRatio,
            canvasAspectRatio: canvasWidth / canvasHeight,
            frame: frame,
            blurred: Image(
              image: image,
              fit: BoxFit.fill,
              gaplessPlayback: true,
              excludeFromSemantics: true,
            ),
            child: Image(
              key: backdropKey,
              image: image,
              fit: BoxFit.fill,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              frameBuilder: (context, child, frame, synchronous) =>
                  AnimatedOpacity(
                    opacity: synchronous || frame != null ? 1 : 0,
                    duration: OsdMotion.d(context, OsdMotion.selection),
                    curve: OsdMotion.selectionCurve,
                    child: child,
                  ),
            ),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(OsdRadius.r16),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            // Never narrower than the tile.
            final double scale = math.max(_closeUp / k, width / canvasWidth);
            final Size canvas = Size(canvasWidth * scale, canvasHeight * scale);
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: <Widget>[
                const Positioned.fill(
                  child: ColoredBox(color: OsdMedia.letterbox),
                ),
                AnimatedPositioned(
                  duration: OsdMotion.d(context, OsdMotion.standard),
                  curve: OsdMotion.curve(context, OsdMotion.standardCurve),
                  // Top right for a numeric date, bottom left for a
                  // written one.
                  left: written ? 0 : width - canvas.width,
                  top: written ? height - canvas.height : 0,
                  width: canvas.width,
                  height: canvas.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      switch (source) {
                        PhotoSource(:final String path) => picture(
                          FrameViewport.photo(path),
                        ),
                        VideoSource(:final String path)
                            when startMs != null && aspectRatio != null =>
                          _VideoFrame(
                            key: ValueKey<(String, int)>((path, startMs)),
                            path: path,
                            timeMs: startMs,
                            width: aspectRatio >= 1
                                ? _frameSide
                                : (_frameSide * aspectRatio).round(),
                            height: aspectRatio >= 1
                                ? (_frameSide / aspectRatio).round()
                                : _frameSide,
                            builder: picture,
                          ),
                        VideoSource() => const SizedBox.expand(),
                      },
                      EditClipStamps(format: format),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Asks for one frame of the video once, and shows it when it comes.
class _VideoFrame extends StatefulWidget {
  const _VideoFrame({
    super.key,
    required this.path,
    required this.timeMs,
    required this.width,
    required this.height,
    required this.builder,
  });

  final String path;
  final int timeMs;
  final int width;
  final int height;
  final Widget Function(ImageProvider? frame) builder;

  @override
  State<_VideoFrame> createState() => _VideoFrameState();
}

class _VideoFrameState extends State<_VideoFrame> {
  ImageProvider? _frame;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final String? frame = await context.read<FilmstripFrames>().frameAt(
      widget.path,
      timeMs: widget.timeMs,
      width: widget.width,
      height: widget.height,
    );
    if (frame == null || !mounted) return;
    setState(() => _frame = FileImage(File(frame)));
  }

  @override
  Widget build(BuildContext context) => widget.builder(_frame);
}
