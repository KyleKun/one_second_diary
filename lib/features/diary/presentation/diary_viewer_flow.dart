import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/data/shown_player.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/saved/deleted_clip_snackbar.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';

/// Opens the viewer from the Diary (the mini player's expand, a long press
/// on a day, a Memories card), and brings the Diary back to what the
/// viewer showed last.
abstract final class DiaryViewerFlow {
  /// Opens the viewer on [clip], flying from [origin], with the Diary's
  /// warm player of [clip] when it has one ready (the viewer then plays it
  /// at once) and its filter (the viewer steps through the kept clips);
  /// the Diary holds still under it. When it closes on another
  /// clip, that day is selected in its month, on that clip (a one-off), and
  /// [onReturned] hears it; the calendar switches before the video flies
  /// back, so the flight lands on it. When the viewer closed because its
  /// clips were deleted, "Video deleted" with the day shows here.
  static Future<void> open(
    BuildContext context, {
    required ClipRef clip,
    ViewerOrigin origin = ViewerOrigin.player,
    ValueChanged<ClipRef>? onReturned,
  }) async {
    final DiaryCubit cubit = context.read<DiaryCubit>()..viewerOpening(origin);
    final String date = DiaryFormats.of(context).fullDate(clip.day);
    final OsdSnackbarHostState? snackbars = OsdSnackbarHost.maybeOf(context);
    final ClipStore? store = context.read<ClipStore?>();
    // The Diary's warm player of the clip goes with it (the mini player's
    // own, playing or ready), so it plays as soon as the viewer shows.
    final ShownPlayer? warm = context.read<PlayerPool>().release(
      context.read<AppPaths>().absoluteFromVideos(clip.relPath),
    );
    final ClipRef? last = await ViewerArgs(
      clip: clip,
      warmPlayer: warm,
      filter: cubit.state.filter,
    ).push<ClipRef>(context);
    cubit.viewerClosed();
    if (last != null) {
      cubit.showDay(last.day, clip: last);
      onReturned?.call(last);
      return;
    }
    if (cubit.state.index?.stampOf(clip) == null) {
      // With Undo, while the viewer's delete can still be reverted.
      snackbars?.show(
        DeletedClipSnackbar.request(store, clip: clip, date: date),
      );
    }
  }
}
