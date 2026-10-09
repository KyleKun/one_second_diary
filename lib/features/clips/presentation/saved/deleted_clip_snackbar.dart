import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/errors/app_exception.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/data/clip_store.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/domain/clip_write.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';

/// The snackbar after a delete: "Video deleted" with the day and Undo. The
/// file waits in the app's trash while it shows; Undo restores it through
/// `ClipStore.undo`, and leaving any other way makes the delete final
/// (`ClipStore.dismiss`). Without Undo to offer it only says "Video deleted".
abstract final class DeletedClipSnackbar {
  /// Shows it for [clip], deleted a moment ago, with [date] as the day.
  static void show(
    BuildContext context, {
    required ClipRef clip,
    required String date,
  }) => OsdSnackbarHost.of(
    context,
  ).show(request(context.read<ClipStore?>(), clip: clip, date: date));

  /// The snackbar itself, for a host kept from before a page was opened
  /// (the viewer's opener, which shows it once the viewer has closed).
  static OsdSnackbarRequest request(
    ClipStore? store, {
    required ClipRef clip,
    required String date,
  }) {
    final ClipWrite? write = store?.deletionOf(clip);
    if (store == null || write == null) {
      return OsdSnackbarRequest(
        kind: OsdSnackKind.delete,
        title: Strings.videoDeleted,
        subtitle: date,
      );
    }
    return OsdSnackbarRequest(
      kind: OsdSnackKind.delete,
      title: Strings.videoDeleted,
      subtitle: date,
      actionLabel: Strings.commonUndo,
      actionErrorTitle: Strings.todaySnackbarUndoFailed,
      onAction: () async {
        unawaited(OsdHaptic.light.play());
        if (!await store.undo(write)) {
          throw MediaStoreException(
            'Could not undo the delete of ${clip.relPath}',
          );
        }
      },
      onDismissed: () => unawaited(store.dismiss(write)),
    );
  }
}
