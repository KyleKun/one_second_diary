import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/router/route_args.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_state.dart';
import 'package:one_second_diary/features/clip_editor/presentation/dialogs/discard_clip_dialog.dart';
import 'package:one_second_diary/features/clips/domain/clip_source.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_clip_flow.dart';
import 'package:one_second_diary/features/clips/presentation/add_clip/add_clip_source.dart';

/// What back does in the clip editor (system back and the app bar's arrow); the editor never pops by itself, so the iOS edge swipe is off.
/// While the clip saves, nothing. Otherwise `DiscardClipDialog` asks first, changes or not: the source is always a fresh recording
/// or import and the camera it came from is gone, so leaving unasked would drop the take.
/// "Discard" gives the source up (`EditClipCubit.discard`). "Record again" (recordings) opens the camera above the editor (`AddClipFlow`)
/// and, once the new clip is saved, gives the old recording up and leaves with that clip; leaving the camera without a clip returns to the editor as it was.
class EditClipBackGuard extends StatelessWidget {
  const EditClipBackGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (bool didPop, Object? result) {
      if (didPop) return;
      unawaited(_leave(context));
    },
    child: child,
  );

  static Future<void> _leave(BuildContext context) async {
    final EditClipCubit editor = context.read<EditClipCubit>();
    if (editor.state.saving) return;
    final NavigatorState navigator = Navigator.of(context);
    final EditClipArgs args = editor.state.args;
    final DiscardChoice? choice = await DiscardClipDialog.show(
      context,
      recordAgain: switch (args.source) {
        VideoSource(:final bool fromRecording) => fromRecording,
        PhotoSource() => false,
      },
      photo: args.source is PhotoSource,
    );
    if (!context.mounted) return;
    switch (choice) {
      case null:
        return;
      case DiscardChoice.discard:
        await editor.discard();
        navigator.pop();
      case DiscardChoice.recordAgain:
        final EditClipState state = editor.state;
        final SavedClip? saved = await AddClipFlow.start(
          context,
          source: AddClipSource.record,
          day: state.args.day,
          profile: state.draft.profile,
          mode: state.args.mode,
        );
        if (saved == null || !context.mounted) return;
        await editor.discard();
        navigator.pop(saved);
    }
  }
}
