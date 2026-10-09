import 'package:flutter/material.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/movie_grid_item.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_skeleton_block.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';

/// My movies while `Movies/` is being read: six items at their final
/// geometry, shimmering (still under reduced motion). Decorative.
class MyMoviesSkeleton extends StatelessWidget {
  const MyMoviesSkeleton({super.key});

  static const int _items = 6;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(
        OsdSpace.pageGutter,
        OsdSpace.s32,
        OsdSpace.pageGutter,
        0,
      ),
      itemCount: _items,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: OsdSpace.gridGapMoviesH,
        mainAxisSpacing: OsdSpace.gridGapMoviesV,
        childAspectRatio: 173 / 137,
      ),
      itemBuilder: (BuildContext context, int index) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            OsdSkeletonBlock(
              width: constraints.maxWidth,
              height: constraints.maxWidth * 9 / 16,
              radius: OsdRadius.r14,
            ),
            const SizedBox(height: MovieGridItem.posterGap),
            const OsdSkeletonBlock.text(),
            const SizedBox(height: MovieGridItem.countGap + 2),
            const OsdSkeletonBlock.text(width: 50, height: 10),
          ],
        ),
      ),
    ),
  );
}
