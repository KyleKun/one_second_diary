import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/saved_clip.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/user_name_cubit.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar.dart';

/// The snackbar after a save: "Video saved", in the nearest `OsdSnackbarHost`.
/// It replaces any snackbar showing.
///
/// - The sub-line (for a clip of [today] only): "That's {n} today" for the
///   day's second clip on, else "See you tomorrow, {name}" (no name: "See you
///   tomorrow"). A clip for a past day has none.
/// - No Undo: a save is final at once and `ClipStore.dismiss` drops the backup
///   of a replaced clip as it shows. A mistaken save is deleted instead, and
///   that delete offers Undo (`DeletedClipSnackbar`).
abstract final class SavedClipSnackbar {
  /// Shows the snackbar for [saved], whose day is compared with [today].
  static void show(
    BuildContext context, {
    required SavedClip saved,
    required LocalDay today,
  }) {
    final ClipStore store = context.read<ClipStore>();
    final ClipRef clip = saved.ref;
    final int clipsThatDay =
        context
            .read<ClipRepository>()
            .snapshotOf(clip.profile)
            ?.clipsOn(clip.day)
            .length ??
        1;
    final String name = context.read<UserNameCubit>().state.name;
    OsdSnackbar.show(
      context,
      kind: OsdSnackKind.success,
      title: Strings.videoSavedTitle,
      subtitle: switch (clip.day == today) {
        false => null,
        true when clipsThatDay > 1 && !saved.replaced =>
          Strings.todaySnackbarSavedBodyCount(count: clipsThatDay),
        true when name.isEmpty => Strings.todaySnackbarSavedBodyNoName,
        true => Strings.todaySnackbarSavedBody(name: name),
      },
    );
    // A save is final at once (Undo is the delete snackbar's): the backup
    // of a replaced clip goes.
    unawaited(store.dismiss(saved.write));
  }
}
