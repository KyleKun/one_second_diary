import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_dialog_action_row.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_field.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';

/// Rename movie: the dialog with the name in an `OsdTextField` (focused;
/// [maxLength] characters at most), and Cancel / Save.
class RenameMovieDialog extends StatefulWidget {
  const RenameMovieDialog({
    super.key,
    required this.title,
    required this.onSave,
  });

  static const Key fieldKey = Key('renameMovieDialog.field');

  static const Key cancelKey = Key('renameMovieDialog.cancel');

  static const Key saveKey = Key('renameMovieDialog.save');

  /// The longest name.
  static const int maxLength = 80;

  /// Shows the dialog for a movie titled [title]; completes with whether
  /// it was renamed.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required Future<bool> Function(String title) onSave,
  }) async =>
      await showOsdDialog<bool>(
        context,
        builder: (BuildContext context) =>
            RenameMovieDialog(title: title, onSave: onSave),
      ) ??
      false;

  /// The movie's base title (without a profile's name).
  final String title;

  /// Saves the new title; false when it could not.
  final Future<bool> Function(String title) onSave;

  @override
  State<RenameMovieDialog> createState() => _RenameMovieDialogState();
}

class _RenameMovieDialogState extends State<RenameMovieDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.title,
  );
  bool _saving = false;
  bool _failed = false;

  bool get _blank => _name.text.trim().isEmpty;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_blank || _saving) return;
    unawaited(OsdHaptic.light.play());
    _setSaving(true);
    final bool saved = await widget.onSave(_name.text.trim());
    if (!mounted) return;
    _setSaving(false);
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _failed = true);
    }
  }

  void _setSaving(bool saving) {
    setState(() => _saving = saving);
    OsdDialogRoute.setBusy(context, busy: saving);
  }

  @override
  Widget build(BuildContext context) => OsdDialog(
    title: Strings.renameMovieTitle,
    content: OsdTextField(
      key: RenameMovieDialog.fieldKey,
      controller: _name,
      autofocus: true,
      enabled: !_saving,
      hint: Strings.movieNameHint,
      maxLength: RenameMovieDialog.maxLength,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      errorText: _blank
          ? Strings.movieNameEmptyError
          : _failed
          ? Strings.movieRenameFailed
          : null,
      onChanged: (_) => setState(() => _failed = false),
      onSubmitted: (_) => unawaited(_save()),
    ),
    actions: OsdDialogActionRow(
      topGap: 6,
      cancel: NeutralButton(
        key: RenameMovieDialog.cancelKey,
        label: CommonLabels.of(context).cancel,
        size: OsdButtonSize.dense,
        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
      ),
      confirm: PrimaryButton(
        key: RenameMovieDialog.saveKey,
        label: Strings.save,
        size: OsdButtonSize.dense,
        loading: _saving,
        onPressed: _blank || _saving ? null : () => unawaited(_save()),
      ),
    ),
  );
}
