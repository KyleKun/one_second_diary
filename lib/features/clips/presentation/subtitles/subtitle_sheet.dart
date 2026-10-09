import 'dart:async';

import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_area.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';

/// A save of the subtitles sheet that failed: the text the user saved and
/// what went wrong. `SubtitleSheet.show` fails with it, so the caller can
/// offer to try again with the same text.
final class SubtitleSaveFailed implements Exception {
  const SubtitleSaveFailed({
    required this.text,
    required this.error,
    required this.stackTrace,
  });

  final String text;
  final Object error;
  final StackTrace stackTrace;

  @override
  String toString() => 'SubtitleSaveFailed: $error';
}

/// The subtitles sheet: an `OsdSheet` titled "Subtitles" with the text area
/// (of any length, line breaks allowed, the keyboard up at once) and Reset /
/// Save below it; stacked, Save first, at large text scales.
///
/// Open it with [show]. The clip editor's Subtitles tab keeps the text in
/// its draft; a saved clip passes `onSave` (see `SubtitleEditFlow`).
class SubtitleSheet extends StatefulWidget {
  const SubtitleSheet({super.key, required this.text, this.onSave});

  static const Key bodyKey = Key('subtitleSheet.body');

  static const Key resetKey = Key('subtitleSheet.reset');

  static const Key saveKey = Key('subtitleSheet.save');

  /// The text it opens with, one paragraph.
  final String text;

  /// Saves the text before the sheet closes (a saved clip); the sheet
  /// shows Save's spinner and can't be dismissed meanwhile.
  final Future<void> Function(String text)? onSave;

  /// Opens the sheet on [text] (line breaks and runs of spaces become one
  /// space: the saved text carries the line breaks its 45-character wrap
  /// added). Completes with the text saved, trimmed (`''` removes the
  /// subtitle), or null when closed without saving.
  ///
  /// With [onSave], Save runs it first: the sheet completes with the text
  /// once it is done, or closes and fails with [SubtitleSaveFailed].
  static Future<String?> show(
    BuildContext context, {
    required String text,
    Future<void> Function(String text)? onSave,
  }) async {
    final Object? outcome = await showOsdSheet<Object>(
      context,
      title: Strings.subtitles,
      titleIcon: OsdIcons.subtitles,
      titleIconColor: context.colors.yellow,
      child: SubtitleSheet(
        text: text.trim().replaceAll(RegExp(r'\s+'), ' '),
        onSave: onSave,
      ),
    );
    return switch (outcome) {
      SubtitleSaveFailed() => throw outcome,
      final String saved => saved,
      _ => null,
    };
  }

  @override
  State<SubtitleSheet> createState() => _SubtitleSheetState();
}

class _SubtitleSheetState extends State<SubtitleSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.text,
  )..addListener(_textChanged);
  bool _empty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _empty = _text.text.isEmpty;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _textChanged() {
    final bool empty = _text.text.isEmpty;
    if (empty != _empty) setState(() => _empty = empty);
  }

  void _reset() {
    unawaited(OsdHaptic.selection.play());
    _text.clear();
  }

  Future<void> _save() async {
    final String text = _text.text.trim();
    final Future<void> Function(String text)? onSave = widget.onSave;
    if (onSave == null) {
      Navigator.of(context).pop(text);
      return;
    }
    setState(() => _saving = true);
    OsdSheetRoute.setBusy(context, busy: true);
    Object outcome = text;
    try {
      await onSave(text);
    } on Object catch (error, stackTrace) {
      outcome = SubtitleSaveFailed(
        text: text,
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    OsdSheetRoute.setBusy(context, busy: false);
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final Widget reset = NeutralButton(
      key: SubtitleSheet.resetKey,
      label: Strings.reset,
      onPressed: _empty || _saving ? null : _reset,
    );
    final Widget save = PrimaryButton(
      key: SubtitleSheet.saveKey,
      label: Strings.save,
      loading: _saving,
      onPressed: _save,
    );
    final bool stacked =
        OsdTextScale.factorOf(context) > OsdTextScale.stackButtonRowsAbove;
    return Column(
      key: SubtitleSheet.bodyKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: <Widget>[
        OsdTextArea(
          controller: _text,
          autofocus: true,
          hint: Strings.subtitlesHint,
          maxLength: null,
          textInputAction: TextInputAction.newline,
        ),
        if (stacked)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: <Widget>[save, reset],
          )
        else
          Row(
            spacing: 12,
            children: <Widget>[
              Expanded(child: reset),
              Expanded(flex: 2, child: save),
            ],
          ),
      ],
    );
  }
}
