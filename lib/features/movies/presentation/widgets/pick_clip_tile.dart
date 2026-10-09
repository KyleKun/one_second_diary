import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/thumbnail_tier.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_thumbnail_view.dart';
import 'package:one_second_diary/features/movies/presentation/cubit/create_movie_cubit.dart';
import 'package:one_second_diary/features/movies/presentation/movie_labels.dart';
import 'package:one_second_diary/shared/widgets/controls/selection_badge.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/media/clip_date_label.dart';
import 'package:one_second_diary/shared/widgets/media/clip_scrim.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_tints.dart';

/// A clip in the picker grid, with its poster from the thumbnail cache
/// (`ClipThumbnailView`).
class PickClipTile extends StatelessWidget {
  const PickClipTile({
    super.key,
    required this.clip,
    required this.orientation,
  });

  static Key tileKey(ClipRef clip) =>
      ValueKey<(String, String)>(('pickClipTile', clip.relPath));

  /// How far the coral ring of a picked tile reaches outside it: the grid
  /// leaves that room above its first row, under the pinned month header.
  static const double ringWidth = 3;

  final ClipRef clip;

  /// The profile's orientation: the poster's frame.
  final VideoOrientation orientation;

  @override
  Widget build(BuildContext context) => _PickedFrame(
    clip: clip,
    thumbnail: ClipThumbnailView(
      clip: clip,
      slot: ClipThumbnailSlot.tile,
      // Two tiles a row: each is far wider than the cell thumbnail's 200 px,
      // which showed blurred.
      tier: ThumbnailTier.poster,
      orientation: orientation,
      radius: OsdRadius.r14,
      onBrokenChanged: (bool broken) => context
          .read<CreateMovieCubit>()
          .setUnavailable(clip, unavailable: broken),
    ),
  );
}

/// The tile around its poster: the only part that follows the selection.
class _PickedFrame extends StatelessWidget {
  const _PickedFrame({required this.clip, required this.thumbnail});

  final ClipRef clip;
  final Widget thumbnail;

  static final BorderRadius _radius = BorderRadius.circular(OsdRadius.r14);

  /// An unreadable clip.
  static const double _unavailableOpacity = .5;

  @override
  Widget build(BuildContext context) {
    final (bool picked, bool unavailable) = context.select(
      (CreateMovieCubit flow) => (
        flow.state.picks.contains(clip),
        flow.state.unavailable.contains(clip),
      ),
    );
    final OsdColors colors = context.colors;
    final Duration fast = OsdMotion.d(context, OsdMotion.fast);
    final Curve curve = OsdMotion.curve(context, OsdMotion.fastCurve);
    final String date = MovieLabels.fullDate(context, clip.day);
    return OsdPressable(
      onTap: unavailable
          ? null
          : () => context.read<CreateMovieCubit>().togglePick(clip),
      haptic: OsdHaptic.selection,
      pressScale: OsdPressScale.button.scale,
      overlay: OsdPressOverlay.none,
      borderRadius: _radius,
      selected: picked,
      semanticsLabel: unavailable
          ? Strings.clipUnavailableSemantics(date: date)
          : date,
      excludeChildSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: picked ? 1 : 0),
        duration: fast,
        curve: curve,
        builder: (BuildContext context, double t, Widget? child) =>
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: _radius,
                boxShadow: t == 0
                    ? null
                    : <BoxShadow>[
                        BoxShadow(
                          color: colors.co,
                          spreadRadius: PickClipTile.ringWidth * t,
                        ),
                      ],
              ),
              child: child,
            ),
        child: Opacity(
          opacity: unavailable ? _unavailableOpacity : 1,
          child: ClipRRect(
            borderRadius: _radius,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                thumbnail,
                const ClipScrim(),
                AnimatedOpacity(
                  opacity: picked ? 1 : 0,
                  duration: fast,
                  curve: curve,
                  child: const ColoredBox(color: OsdTints.coTint12),
                ),
                PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: SelectionBadge(selected: picked),
                ),
                PositionedDirectional(
                  start: 10,
                  end: 10,
                  bottom: 8,
                  child: Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: ClipDateLabel(
                      MovieLabels.shortDate(context, clip.day),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
