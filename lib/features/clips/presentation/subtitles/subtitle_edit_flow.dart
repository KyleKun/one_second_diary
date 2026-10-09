import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/data/clip_subtitles.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/features/clips/presentation/subtitles/subtitle_sheet.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';

/// Edits the subtitle of a saved clip: opens the [SubtitleSheet] and, on Save,
/// rewrites the clip with `ClipSubtitles.rewrite`. A subtitle that cannot be
/// read is reported without the sheet: saving an empty sheet would erase it.
abstract final class SubtitleEditFlow {
  /// Runs the flow for [clip]; true when its subtitle was rewritten.
  static Future<bool> edit(
    BuildContext context, {
    required ClipRef clip,
  }) async {
    final ClipSubtitles subtitles = context.read<ClipSubtitles>();
    final OsdSnackbarHostState host = OsdSnackbarHost.of(context);
    final String current;
    try {
      current = await subtitles.textOf(clip);
    } on Object {
      // Logged by ClipSubtitles.
      _failed(host);
      return false;
    }
    if (!context.mounted) return false;
    try {
      final String? saved = await SubtitleSheet.show(
        context,
        text: current,
        onSave: (String text) => subtitles.rewrite(clip, text),
      );
      if (saved == null) return false;
      _saved(host);
      return true;
    } on SubtitleSaveFailed catch (failure) {
      _failed(
        host,
        retry: () async {
          await subtitles.rewrite(clip, failure.text);
          _saved(host);
        },
      );
      return false;
    }
  }

  static void _saved(OsdSnackbarHostState host) {
    if (!host.mounted) return;
    host.show(
      OsdSnackbarRequest(
        kind: OsdSnackKind.success,
        title: Strings.subtitlesSaved,
      ),
    );
  }

  static void _failed(
    OsdSnackbarHostState host, {
    Future<void> Function()? retry,
  }) {
    if (!host.mounted) return;
    host.show(
      OsdSnackbarRequest(
        kind: OsdSnackKind.error,
        title: Strings.subtitlesSaveError,
        actionLabel: retry == null ? null : Strings.commonTryAgain,
        onAction: retry,
        actionErrorTitle: Strings.subtitlesSaveError,
      ),
    );
  }
}
