import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/clip_frame.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length.dart';
import 'package:one_second_diary/features/clip_editor/domain/edit_clip_draft.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/edit_clip_stamps.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/photo_source_preview.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/video_source_preview.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/theme/osd_media.dart';

/// The editor's preview: the source shown in the canvas of the profile the
/// clip goes to, the way the export makes it:
/// - a landscape profile: 16:9 across the width, the source fitted inside
///   (the export pads);
/// - a portrait profile: a 9:16 canvas in the middle, the source filling
///   it (the export crops), black beside it;
/// - a clip framed for that canvas: the frame, bars black or blurred.
///
/// The stamps sit on the canvas where the export burns them, scaled with
/// the canvas (the same part of the picture at every tier).
class EditClipPreview extends StatelessWidget {
  const EditClipPreview({super.key, required this.format});

  /// The canvas the clip is made in.
  static const Key canvasKey = Key('editClipPreview.canvas');

  /// A portrait profile's preview height.
  static const double portraitHeight = 300;

  /// The format of the profile the clip goes to: its canvas.
  final ClipFormat format;

  @override
  Widget build(BuildContext context) {
    final ClipSource source = context.select(
      (EditClipCubit editor) => editor.state.args.source,
    );
    final ClipFrame? frame = context.select(
      (EditClipCubit editor) => editor.state.draft.frameFor(format.orientation),
    );
    final double? aspectRatio = context.select(
      (EditClipCubit editor) => editor.state.sourceAspectRatio,
    );
    final int? zoomDurationMs = context.select(
      (EditClipCubit editor) => switch (editor.state.draft) {
        EditClipDraft(zoom: true, length: HeldPhoto(:final int durationMs)) =>
          durationMs,
        _ => null,
      },
    );
    final bool landscape = format.width >= format.height;
    final double canvasAspectRatio = format.width / format.height;
    final Widget canvas = AspectRatio(
      key: canvasKey,
      aspectRatio: canvasAspectRatio,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            switch (source) {
              VideoSource(:final String path) => VideoSourcePreview(
                path: path,
                canvasAspectRatio: canvasAspectRatio,
                frame: frame,
              ),
              PhotoSource(:final String path) => PhotoSourcePreview(
                path: path,
                canvasAspectRatio: canvasAspectRatio,
                frame: frame,
                aspectRatio: aspectRatio,
                onDecoded: (double aspectRatio) => context
                    .read<EditClipCubit>()
                    .photoDecoded(aspectRatio: aspectRatio),
                zoomDurationMs: zoomDurationMs,
              ),
            },
            IgnorePointer(child: EditClipStamps(format: format)),
          ],
        ),
      ),
    );
    // One tree for both canvases, so a profile of the other orientation
    // reshapes the preview without building its player again.
    return RepaintBoundary(
      child: ColoredBox(
        color: OsdMedia.letterbox,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) =>
              SizedBox(
                height: landscape
                    ? constraints.maxWidth * 9 / 16
                    : portraitHeight,
                child: Center(child: canvas),
              ),
        ),
      ),
    );
  }
}
