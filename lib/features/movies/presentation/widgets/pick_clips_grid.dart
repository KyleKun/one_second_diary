import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/movies/domain/clip_months.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/pick_clip_tile.dart';
import 'package:one_second_diary/features/movies/presentation/widgets/pick_month_header.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';

/// The picker grid: one group per month, newest first, each a pinned
/// [PickMonthHeader] above a lazy grid of [PickClipTile]s.
class PickClipsGrid extends StatelessWidget {
  const PickClipsGrid({
    super.key,
    required this.months,
    required this.orientation,
    this.profileName,
    this.controller,
  });

  static const Key scrollKey = Key('pickClipsGrid.scroll');

  final List<ClipMonth> months;
  final VideoOrientation orientation;

  /// The profile's name for the month headers, when the user has several.
  final String? profileName;

  final ScrollController? controller;

  static const double _gap = 10;
  static const double _side = 16;

  /// A month header's height at text scale 1, with the room for a picked tile's
  /// ring under it: 4 + the 13 px label's line + 10 (only a month not built yet
  /// uses it).
  static const double _headerHeight = 4 + 13 * 1.185 + 10;

  @override
  Widget build(BuildContext context) {
    final bool landscape = orientation == VideoOrientation.landscape;
    final double width = MediaQuery.sizeOf(context).width;
    final int columns =
        ((width - 2 * _side + _gap) ~/ ((landscape ? 170 : 150) + _gap)).clamp(
          2,
          landscape ? 6 : 8,
        );
    final double aspect = ClipThumbnailSlot.tile.aspectRatio(orientation)!;
    final SliverGridDelegate grid = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: _gap,
      crossAxisSpacing: _gap,
      childAspectRatio: aspect,
    );
    final double row =
        (width - 2 * _side - (columns - 1) * _gap) / columns / aspect + _gap;
    final double header = MediaQuery.textScalerOf(context).scale(_headerHeight);
    return CustomScrollView(
      key: scrollKey,
      controller: controller,
      slivers: <Widget>[
        for (final ClipMonth month in months)
          _LazyMonth(
            key: ValueKey<(int, int)>((month.year, month.month)),
            height: header + (month.clips.length / columns).ceil() * row,
            month: SliverMainAxisGroup(
              slivers: <Widget>[
                PinnedHeaderSliver(
                  child: PickMonthHeader(
                    month: month,
                    profileName: profileName,
                    // The rest of its 10 is the room above the first row.
                    bottomPadding: 10 - PickClipTile.ringWidth,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    _side,
                    PickClipTile.ringWidth,
                    _side,
                    _gap,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: grid,
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) => PickClipTile(
                        key: PickClipTile.tileKey(month.clips[index]),
                        clip: month.clips[index],
                        orientation: orientation,
                      ),
                      childCount: month.clips.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A month group, built once it first reaches the viewport's cache region;
/// until then an empty box of about its [height].
class _LazyMonth extends StatefulWidget {
  const _LazyMonth({super.key, required this.height, required this.month});

  final double height;

  /// The month's sliver, the same instance for every layout, so a scroll
  /// never rebuilds its tiles.
  final Widget month;

  @override
  State<_LazyMonth> createState() => _LazyMonthState();
}

class _LazyMonthState extends State<_LazyMonth> {
  bool _built = false;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (BuildContext context, SliverConstraints constraints) {
      if (!_built && constraints.remainingCacheExtent <= 0) {
        return SliverToBoxAdapter(child: SizedBox(height: widget.height));
      }
      _built = true;
      return widget.month;
    },
  );
}
