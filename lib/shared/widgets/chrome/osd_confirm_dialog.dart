import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/destructive_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_dialog_action_row.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_error_scope.dart';

/// A Cancel / Confirm dialog: an [OsdDialog] whose actions are a Neutral
/// "Cancel" and a Primary confirm, or a Destructive (RED) confirm when
/// [destructive].
///
/// Destructive dialogs start with focus on Cancel. The confirm is guarded
/// against double taps. With [onConfirm] the dialog stays open while it runs:
/// a spinner fills the confirm, both buttons are disabled and nothing
/// dismisses it; on success it pops `true`, on failure it reports the error
/// to the [OsdErrorScope] (the app's log) and becomes idle again so the user
/// can retry or cancel.
class OsdConfirmDialog extends StatefulWidget {
  const OsdConfirmDialog({
    super.key,
    required this.title,
    required this.cancelLabel,
    required this.confirmLabel,
    this.body,
    this.content,
    this.destructive = false,
    this.badgeIcon,
    this.onConfirm,
  });

  static const Key cancelKey = Key('osdConfirmDialog.cancel');

  static const Key confirmKey = Key('osdConfirmDialog.confirm');

  /// Shows the dialog; completes with whether the user confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String cancelLabel,
    required String confirmLabel,
    String? body,
    Widget? content,
    bool destructive = false,
    IconData? badgeIcon,
    Future<void> Function()? onConfirm,
  }) async {
    final confirmed = await showOsdDialog<bool>(
      context,
      builder: (context) => OsdConfirmDialog(
        title: title,
        cancelLabel: cancelLabel,
        confirmLabel: confirmLabel,
        body: body,
        content: content,
        destructive: destructive,
        badgeIcon: badgeIcon,
        onConfirm: onConfirm,
      ),
    );
    return confirmed ?? false;
  }

  final String title;

  final String cancelLabel;

  final String confirmLabel;

  final String? body;

  /// Extra content (a static ProfileChip, a text field).
  final Widget? content;

  /// Whether the confirm destroys something.
  final bool destructive;

  final IconData? badgeIcon;

  /// Work to finish before the dialog closes.
  final Future<void> Function()? onConfirm;

  @override
  State<OsdConfirmDialog> createState() => _OsdConfirmDialogState();
}

class _OsdConfirmDialogState extends State<OsdConfirmDialog> {
  bool _busy = false;
  bool _done = false;

  void _setBusy(bool busy) {
    setState(() => _busy = busy);
    OsdDialogRoute.setBusy(context, busy: busy);
  }

  Future<void> _confirm() async {
    if (_busy || _done) return;
    final onConfirm = widget.onConfirm;
    if (onConfirm == null) {
      _done = true;
      Navigator.of(context).pop(true);
      return;
    }
    final OsdErrorReporter report = OsdErrorScope.of(context);
    _setBusy(true);
    try {
      await onConfirm();
      if (!mounted) return;
      _done = true;
      _setBusy(false);
      Navigator.of(context).pop(true);
    } on Object catch (error, stackTrace) {
      report(
        'The "${widget.confirmLabel}" confirmation failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) _setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirm = widget.destructive
        ? DestructiveButton(
            key: OsdConfirmDialog.confirmKey,
            label: widget.confirmLabel,
            loading: _busy,
            onPressed: () => unawaited(_confirm()),
          )
        : PrimaryButton(
            key: OsdConfirmDialog.confirmKey,
            label: widget.confirmLabel,
            size: OsdButtonSize.dense,
            loading: _busy,
            onPressed: () => unawaited(_confirm()),
          );
    return OsdDialog(
      title: widget.title,
      body: widget.body,
      content: widget.content,
      badgeIcon: widget.badgeIcon,
      actions: OsdDialogActionRow(
        cancel: NeutralButton(
          key: OsdConfirmDialog.cancelKey,
          label: widget.cancelLabel,
          size: OsdButtonSize.dense,
          autofocus: widget.destructive,
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
        ),
        confirm: confirm,
      ),
    );
  }
}
