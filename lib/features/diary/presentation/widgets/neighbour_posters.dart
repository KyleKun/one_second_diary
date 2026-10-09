import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/thumbnail_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/file_stamp.dart';
import 'package:one_second_diary/features/clips/domain/thumbnail_tier.dart';
import 'package:one_second_diary/shared/widgets/media/clip_thumbnail.dart';

/// Decodes the posters of [clips] (the clips the player keeps warm) as
/// `ClipThumbnail` will show them, so the one tapped or stepped to next
/// paints in that same frame.
///
/// `ClipThumbnail` decodes a poster once, whatever its box
/// ([ClipThumbnail.maxDecodeSide], fit), and a calendar cell shows another
/// file (the cell tier), so without this a day's first frames show C2
/// while its poster decodes. Only posters the thumbnail cache has are
/// decoded, after the frame; the image cache keeps them. One that can't be
/// read loads (or shows broken) as usual once it is shown.
class NeighbourPosters extends StatefulWidget {
  const NeighbourPosters({super.key, required this.clips, required this.child});

  final List<ClipRef> clips;

  /// The player, which fills the box this gets.
  final Widget child;

  @override
  State<NeighbourPosters> createState() => _NeighbourPostersState();
}

class _NeighbourPostersState extends State<NeighbourPosters> {
  late final ClipRepository _clips = context.read<ClipRepository>();
  late final ThumbnailRepository _thumbnails = context
      .read<ThumbnailRepository>();

  /// The clips decoded last.
  List<ClipRef>? _decoded;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(NeighbourPosters oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  /// Decodes [widget.clips] after this frame, unless done.
  void _schedule() {
    final List<ClipRef> clips = widget.clips;
    if (listEquals(_decoded, clips)) return;
    _decoded = clips;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _decode(clips);
    });
  }

  void _decode(List<ClipRef> clips) {
    for (final ClipRef clip in clips) {
      final FileStamp? stamp = _clips.snapshotOf(clip.profile)?.stampOf(clip);
      final String? file = stamp == null
          ? null
          : _thumbnails.cachedFile(
              clip,
              stamp: stamp,
              tier: ThumbnailTier.poster,
            );
      if (file == null) continue;
      unawaited(
        precacheImage(
          // The key ClipThumbnail decodes under.
          ResizeImage(
            FileImage(File(file)),
            width: ClipThumbnail.maxDecodeSide,
            height: ClipThumbnail.maxDecodeSide,
            policy: ResizeImagePolicy.fit,
          ),
          context,
          // It loads as usual once shown, or shows broken there.
          onError: (Object error, StackTrace? stackTrace) {},
        ),
      );
    }
  }
}
