import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/data/clip_privacy.dart';
import 'package:one_second_diary/features/clips/data/clip_repository.dart';
import 'package:one_second_diary/features/clips/domain/clip_ref.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';

/// Marks a saved clip private or public. The library shows the change at once
/// while `ClipPrivacy` rewrites the file; the snackbar offers Undo, or Try
/// again if the rewrite fails.
abstract final class ClipPrivacyFlow {
  /// Whether [clip] is private now (what the action's label says).
  static bool isPrivate(BuildContext context, ClipRef clip) =>
      context
          .read<ClipRepository>()
          .snapshotOf(clip.profile)
          ?.isPrivate(clip) ??
      false;

  /// Makes [clip] private when it is public, and public when it is
  /// private; true when its file was rewritten.
  static Future<bool> toggle(BuildContext context, {required ClipRef clip}) {
    final ClipPrivacy privacy = context.read<ClipPrivacy>();
    final OsdSnackbarHostState host = OsdSnackbarHost.of(context);
    return _set(privacy, host, clip, private: !privacy.isPrivate(clip));
  }

  static Future<bool> _set(
    ClipPrivacy privacy,
    OsdSnackbarHostState host,
    ClipRef clip, {
    required bool private,
  }) async {
    final Future<void> written = privacy.setPrivate(clip, private: private);
    // The library has changed already: say so while the file is rewritten.
    _done(privacy, host, clip, private: private);
    try {
      await written;
      return true;
    } on Object {
      // Logged by ClipPrivacy.
      _failed(privacy, host, clip, private: private);
      return false;
    }
  }

  static void _done(
    ClipPrivacy privacy,
    OsdSnackbarHostState host,
    ClipRef clip, {
    required bool private,
  }) {
    if (!host.mounted) return;
    host.show(
      OsdSnackbarRequest(
        kind: OsdSnackKind.info,
        title: private ? Strings.privateMarked : Strings.privateUnmarked,
        subtitle: private ? Strings.privateMarkedHint : null,
        actionLabel: Strings.commonUndo,
        actionErrorTitle: Strings.privateSaveError,
        onAction: () {
          unawaited(OsdHaptic.light.play());
          return privacy.setPrivate(clip, private: !private);
        },
      ),
    );
  }

  static void _failed(
    ClipPrivacy privacy,
    OsdSnackbarHostState host,
    ClipRef clip, {
    required bool private,
  }) {
    if (!host.mounted) return;
    host.show(
      OsdSnackbarRequest(
        kind: OsdSnackKind.error,
        title: Strings.privateSaveError,
        actionLabel: Strings.commonTryAgain,
        actionErrorTitle: Strings.privateSaveError,
        onAction: () async {
          await privacy.setPrivate(clip, private: private);
          _done(privacy, host, clip, private: private);
        },
      ),
    );
  }
}
