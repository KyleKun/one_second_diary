import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/media/types/video_orientation.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/media/clip_thumbnail_view.dart';
import 'package:one_second_diary/features/profiles/presentation/cubit/profiles_cubit.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';

/// A clip's poster as Places draws it: a tile of the active profile's
/// orientation, without the imported pill (the small slots have no room).
class PlacePoster extends StatelessWidget {
  const PlacePoster({
    super.key,
    required this.clip,
    this.radius = 0,
    this.tagBadge = false,
    this.overlay,
    this.semanticsLabel,
  });

  final ClipRef clip;
  final double radius;
  final bool tagBadge;

  /// Covers the poster once it is ready.
  final Widget? overlay;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final VideoOrientation orientation = context
        .select<ProfilesCubit, VideoOrientation>(
          (ProfilesCubit cubit) => cubit.state.active.orientation,
        );
    return ClipThumbnailView(
      clip: clip,
      slot: ClipThumbnailSlot.tile,
      orientation: orientation,
      radius: radius,
      showTagBadge: tagBadge,
      showImportedBadge: false,
      overlay: overlay,
      semanticsLabel: semanticsLabel,
    );
  }
}
