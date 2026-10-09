import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/storage/app_paths.dart';
import 'package:one_second_diary/features/clips/data/player_pool.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/saved/deleted_clip_snackbar.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/diary_state.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/viewer_cubit.dart';
import 'package:one_second_diary/features/diary/presentation/cubit/viewer_state.dart';
import 'package:one_second_diary/features/diary/presentation/diary_formats.dart';
import 'package:one_second_diary/features/diary/presentation/shown_clip_playback.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/viewer_actions.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/viewer_caption.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/viewer_layout.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/viewer_progress.dart';
import 'package:one_second_diary/features/diary/presentation/widgets/viewer_video.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/shared/widgets/chrome/viewer_top_bar.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';

/// The full-screen viewer, always dark: the day and its place over the
/// video ([ViewerVideo]) and its progress ([ViewerProgress]), then the
/// bottom row: the subtitle, tags and badges ([ViewerCaption]) beside
/// Share and More ([ViewerActions]), whose sheet holds the other actions.
///
/// [ViewerLayout] places and moves them: upright, or a phone turned
/// sideways with the chrome over the video; the chrome rises in; a drag
/// down closes the viewer; a swipe sideways steps through a day's clips,
/// then to the neighbouring days.
///
/// It closes with the clip it shows last, so the Diary selects that day
/// before the video flies back to it. Once it moved to another clip, back
/// (the button, the gesture) closes it that way too; it closes on its own
/// when a delete leaves no clip. Deletes and subtitle edits say how they
/// went in its own snackbar host.
class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key});

  /// The black page.
  static const Key backgroundKey = ViewerLayout.backgroundKey;

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  /// The clip shown's player, for the bar and the Share tile.
  late final ShownClipPlayback _playback;

  @override
  void initState() {
    super.initState();
    _playback = ShownClipPlayback(
      pool: context.read<PlayerPool>(),
      paths: context.read<AppPaths>(),
      clip: context.read<ViewerCubit>().state.clip,
    );
  }

  @override
  void dispose() {
    _playback.dispose();
    super.dispose();
  }

  void _close(BuildContext context) =>
      context.pop<ClipRef>(context.read<ViewerCubit>().state.clip);

  /// A swipe sideways: steps, with the chevrons' tick.
  void _step(BuildContext context, {required bool next}) {
    final ViewerCubit cubit = context.read<ViewerCubit>();
    unawaited(OsdHaptic.selection.play());
    next ? cubit.showNext() : cubit.showPrevious();
  }

  /// "Video deleted" with the day, or "Couldn't delete this video"; a
  /// delete that left no clip closes the viewer, and the Diary says it.
  void _deletionChanged(BuildContext context, ViewerState state) {
    final ClipRef? clip = state.deletedClip;
    if (clip == null || state.closed) return;
    switch (state.deletion) {
      case ClipDeletion.deleted:
        DeletedClipSnackbar.show(
          context,
          clip: clip,
          date: DiaryFormats.of(context).fullDate(clip.day),
        );
      case ClipDeletion.failed:
        OsdSnackbar.show(
          context,
          kind: OsdSnackKind.error,
          title: Strings.deleteVideoFailed,
        );
      case ClipDeletion.idle || ClipDeletion.deleting:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bool moved, bool hasPrevious, bool hasNext) = context.select(
      (ViewerCubit cubit) => (
        cubit.state.moved,
        cubit.state.previous != null,
        cubit.state.next != null,
      ),
    );
    return OsdSnackbarHost(
      child: MultiBlocListener(
        listeners: <BlocListener<ViewerCubit, ViewerState>>[
          BlocListener<ViewerCubit, ViewerState>(
            listenWhen: (ViewerState before, ViewerState after) =>
                before.clip != after.clip,
            listener: (_, ViewerState state) => _playback.follow(state.clip),
          ),
          // Nothing left to show (deleted here or elsewhere): it closes. A
          // dialog over it (whose delete this was) closes first, and the
          // Delete tile then closes the viewer.
          BlocListener<ViewerCubit, ViewerState>(
            listenWhen: (ViewerState before, ViewerState after) =>
                !before.closed && after.closed,
            listener: (BuildContext context, _) {
              if (ModalRoute.isCurrentOf(context) ?? true) context.pop();
            },
          ),
          BlocListener<ViewerCubit, ViewerState>(
            listenWhen: (ViewerState before, ViewerState after) =>
                before.deletion != after.deletion,
            listener: _deletionChanged,
          ),
        ],
        child: PopScope<Object?>(
          canPop: !moved,
          onPopInvokedWithResult: (bool didPop, _) {
            if (!didPop) _close(context);
          },
          // Transparent: the page below shows through a drag down.
          child: Material(
            type: MaterialType.transparency,
            child: ViewerLayout(
              onDismiss: () => _close(context),
              onPrevious: hasPrevious
                  ? () => _step(context, next: false)
                  : null,
              onNext: hasNext ? () => _step(context, next: true) : null,
              bar: _ViewerBar(onClose: () => _close(context)),
              video: (Animation<double> chrome) =>
                  ViewerVideo(chrome: chrome, playback: _playback),
              progress: ViewerProgress(playback: _playback),
              caption: const ViewerCaption(),
              actions: ViewerActions(playback: _playback),
              sidewaysCaption: const ViewerCaption(compact: true),
              sidewaysActions: ViewerActions(
                playback: _playback,
                compact: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The top bar: close, the day ("Wednesday, September 16") over its place
/// (and "2 of 3" on a day of several clips), and the sound toggle.
class _ViewerBar extends StatelessWidget {
  const _ViewerBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final (
      ClipRef clip,
      String? place,
      DayPosition position,
      bool muted,
    ) = context.select(
      (ViewerCubit cubit) => (
        cubit.state.clip,
        cubit.state.caption.location,
        cubit.state.dayPosition,
        cubit.state.muted,
      ),
    );
    final DiaryFormats formats = DiaryFormats.of(context);
    final String? clipPosition = position.count > 1
        ? Strings.viewerClipPosition(
            index: position.position,
            count: position.count,
          )
        : null;
    final ViewerCubit cubit = context.read<ViewerCubit>();
    return ViewerTopBar(
      onClose: onClose,
      closeTooltip: Strings.viewerExitFullScreen,
      title: formats.fullDate(clip.day),
      subtitle: switch ((place, clipPosition)) {
        (final String place, final String position) =>
          Strings.viewerPlaceAndPosition(place: place, position: position),
        (final String place, null) => place,
        (null, final String position) => position,
        (null, null) => null,
      },
      muted: muted,
      onToggleMute: () => unawaited(cubit.toggleSound()),
      muteTooltip: Strings.playerMute,
      unmuteTooltip: Strings.playerUnmute,
    );
  }
}
