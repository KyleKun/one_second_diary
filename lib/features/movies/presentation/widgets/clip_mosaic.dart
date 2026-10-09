import 'package:flutter/material.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_thumbnail_view.dart';
import 'package:one_second_diary/features/movies/domain/movie_draft.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_radius.dart';

/// The confirmation's mosaic of the movie's clips: 4 × 4 cells, the gaps
/// showing the page.
class ClipMosaic extends StatelessWidget {
  const ClipMosaic({super.key, required this.clips, required this.orientation});

  /// The mosaic's clipped box.
  static const Key mosaicKey = Key('clipMosaic.mosaic');

  /// Cell [index] (0–15, in reading order).
  static Key cellKey(int index) =>
      ValueKey<(String, int)>(('clipMosaic.cell', index));

  static const int _columns = 4;
  static const double _gap = 4;

  /// A cell's height over its width.
  static const double _cellShape = 52 / 86.5;

  /// The 16 cells' clips (`MovieDraft.mosaic`), or none.
  final List<ClipRef> clips;

  /// The profile's orientation: the posters asked for.
  final VideoOrientation orientation;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      final double width =
          (constraints.maxWidth - (_columns - 1) * _gap) / _columns;
      final Size cell = Size(width, width * _cellShape);
      const int rows = MovieDraft.mosaicCells ~/ _columns;
      return RepaintBoundary(
        child: ClipRRect(
          key: mosaicKey,
          borderRadius: BorderRadius.circular(OsdRadius.r24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: _gap,
            children: <Widget>[
              for (int row = 0; row < rows; row++)
                Row(
                  spacing: _gap,
                  children: <Widget>[
                    for (int column = 0; column < _columns; column++)
                      SizedBox.fromSize(
                        key: cellKey(row * _columns + column),
                        size: cell,
                        child: _Cell(
                          clip: clips.isEmpty
                              ? null
                              : clips[row * _columns + column],
                          orientation: orientation,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.clip, required this.orientation});

  final ClipRef? clip;
  final VideoOrientation orientation;

  @override
  Widget build(BuildContext context) {
    final ClipRef? clip = this.clip;
    return clip == null
        ? ColoredBox(color: context.colors.c2)
        : ClipThumbnailView(
            clip: clip,
            slot: ClipThumbnailSlot.tile,
            orientation: orientation,
          );
  }
}
