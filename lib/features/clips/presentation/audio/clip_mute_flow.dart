import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/data/clip_audio.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/theme/osd_icons.dart';

/// Mutes a saved clip after asking first (the sound is removed for good), then
/// reports through the page's `OsdSnackbarHost`. No Undo.
abstract final class ClipMuteFlow {
  /// Whether [clip] is muted now (what the action's label says).
  static bool isMuted(BuildContext context, ClipRef clip) =>
      context.read<ClipAudio>().isMuted(clip);

  /// Asks, then mutes [clip]; true when its file was rewritten (false
  /// when the user said no, or it failed).
  static Future<bool> mute(
    BuildContext context, {
    required ClipRef clip,
  }) async {
    final ClipAudio audio = context.read<ClipAudio>();
    final OsdSnackbarHostState host = OsdSnackbarHost.of(context);
    final bool confirmed = await OsdConfirmDialog.show(
      context,
      title: Strings.clipMuteConfirmTitle,
      body: Strings.clipMuteConfirmBody,
      cancelLabel: CommonLabels.of(context).cancel,
      confirmLabel: Strings.clipMuteConfirm,
      badgeIcon: OsdIcons.volumeOff,
    );
    if (!confirmed) return false;
    return _mute(audio, host, clip);
  }

  static Future<bool> _mute(
    ClipAudio audio,
    OsdSnackbarHostState host,
    ClipRef clip,
  ) async {
    try {
      await audio.mute(clip);
    } on Object {
      // Logged by ClipAudio.
      _failed(audio, host, clip);
      return false;
    }
    _done(host);
    return true;
  }

  static void _done(OsdSnackbarHostState host) {
    if (!host.mounted) return;
    host.show(
      OsdSnackbarRequest(kind: OsdSnackKind.info, title: Strings.clipMutedDone),
    );
  }

  static void _failed(
    ClipAudio audio,
    OsdSnackbarHostState host,
    ClipRef clip,
  ) {
    if (!host.mounted) return;
    host.show(
      OsdSnackbarRequest(
        kind: OsdSnackKind.error,
        title: Strings.clipMuteError,
        actionLabel: Strings.commonTryAgain,
        actionErrorTitle: Strings.clipMuteError,
        onAction: () async {
          await audio.mute(clip);
          _done(host);
        },
      ),
    );
  }
}
