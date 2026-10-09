import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';
import 'package:one_second_diary/features/clips/domain/tags_draft.dart';
import 'package:one_second_diary/features/clips/presentation/tags/tags_help_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_field.dart';
import 'package:one_second_diary/shared/widgets/controls/tag_chip.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A save of the tags sheet that failed: the tags the user saved and what
/// went wrong. `TagsSheet.show` fails with it, so the caller can offer to
/// try again with the same tags.
final class TagsSaveFailed implements Exception {
  const TagsSaveFailed({
    required this.tags,
    required this.error,
    required this.stackTrace,
  });

  final List<String> tags;
  final Object error;
  final StackTrace stackTrace;

  @override
  String toString() => 'TagsSaveFailed: $error';
}

/// The tags sheet: an `OsdSheet` titled "Tags" (its "?" opens the help)
/// with the clip's tags as chips that a × removes (or "No tags yet"), a
/// field that adds one on Enter or a typed comma (a refused tag says why
/// under the field, `TagName.validate`), the suggestions (every tag of the
/// library the clip hasn't, a tap adds it) and Save, on only once
/// something changed.
///
/// Open it with [show]. The clip editor keeps the list in its draft; a
/// saved clip passes `onSave` (see `ClipTagsFlow`).
class TagsSheet extends StatefulWidget {
  const TagsSheet({
    super.key,
    required this.tags,
    required this.suggestions,
    this.onSave,
  });

  static const Key bodyKey = Key('tagsSheet.body');

  static const Key fieldKey = Key('tagsSheet.field');

  static const Key saveKey = Key('tagsSheet.save');

  static const Key noneKey = Key('tagsSheet.none');

  /// The chip of one of the clip's tags.
  static Key chipKey(String tag) =>
      ValueKey<String>('tagsSheet.chip.${TagName.fold(tag)}');

  /// The chip of one suggestion.
  static Key suggestionKey(String tag) =>
      ValueKey<String>('tagsSheet.suggestion.${TagName.fold(tag)}');

  /// The tags it opens with.
  final List<String> tags;

  /// The library's tags, most used first; those the clip has are left out.
  final List<String> suggestions;

  /// Saves the tags before the sheet closes (a saved clip); the sheet
  /// shows Save's spinner and can't be dismissed meanwhile.
  final Future<void> Function(List<String> tags)? onSave;

  /// Opens the sheet on [tags]. Completes with the tags saved, normalised
  /// (`TagName.normalize`; empty removes them all), or null when closed
  /// without saving (the edit is dropped).
  ///
  /// With [onSave], Save runs it first: the sheet completes with the tags
  /// once it is done, or closes and fails with [TagsSaveFailed].
  static Future<List<String>?> show(
    BuildContext context, {
    required List<String> tags,
    required List<String> suggestions,
    Future<void> Function(List<String> tags)? onSave,
  }) async {
    final Object? outcome = await showOsdSheet<Object>(
      context,
      title: Strings.tags,
      titleIcon: OsdIcons.sell,
      titleTrailing: const TagsHelpButton(),
      child: TagsSheet(tags: tags, suggestions: suggestions, onSave: onSave),
    );
    return switch (outcome) {
      TagsSaveFailed() => throw outcome,
      final List<String> saved => saved,
      _ => null,
    };
  }

  @override
  State<TagsSheet> createState() => _TagsSheetState();
}

class _TagsSheetState extends State<TagsSheet> {
  late TagsDraft _draft = TagsDraft.of(widget.tags);
  late final TextEditingController _text = TextEditingController()
    ..addListener(_textChanged);
  TagNameError? _error;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Save follows what is typed, and a refused tag is forgiven on the next
  /// keystroke.
  void _textChanged() {
    if (!mounted) return;
    setState(() => _error = null);
  }

  /// A typed comma adds what is before it, as Enter does; the field keeps
  /// what came after it.
  void _changed(String text) {
    final int comma = text.indexOf(',');
    if (comma < 0) return;
    final String before = text.substring(0, comma);
    final String after = text.substring(comma + 1);
    _text.value = TextEditingValue(
      text: after,
      selection: TextSelection.collapsed(offset: after.length),
    );
    if (before.trim().isEmpty) return;
    _add(before);
  }

  /// Adds [raw]; true when it was added (the field is cleared), else the
  /// field says why.
  bool _add(String raw) {
    final (TagsDraft next, TagNameError? error) = _draft.add(raw);
    setState(() {
      _error = error;
      _draft = next;
    });
    if (error != null) return false;
    unawaited(OsdHaptic.selection.play());
    if (_text.text.trim() == raw.trim()) _text.clear();
    return true;
  }

  void _remove(String tag) => setState(() => _draft = _draft.remove(tag));

  Future<void> _save() async {
    // What is still typed counts: nobody means to lose it.
    final String typed = _text.text;
    if (typed.trim().isNotEmpty && !_add(typed)) return;
    final List<String> tags = _draft.normalized;
    final Future<void> Function(List<String> tags)? onSave = widget.onSave;
    if (onSave == null) {
      Navigator.of(context).pop(tags);
      return;
    }
    setState(() => _saving = true);
    OsdSheetRoute.setBusy(context, busy: true);
    Object outcome = tags;
    try {
      await onSave(tags);
    } on Object catch (error, stackTrace) {
      outcome = TagsSaveFailed(
        tags: tags,
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (!mounted) return;
    OsdSheetRoute.setBusy(context, busy: false);
    Navigator.of(context).pop(outcome);
  }

  String _errorText(TagNameError error) => switch (error) {
    TagNameError.empty => Strings.tagErrorEmpty,
    TagNameError.tooLong => Strings.tagErrorTooLong(max: TagName.maxLength),
    TagNameError.comma => Strings.tagErrorComma,
    TagNameError.invalidCharacters => Strings.tagErrorInvalid,
    TagNameError.duplicate => Strings.tagErrorDuplicate,
    TagNameError.tooMany => Strings.tagErrorTooMany(max: TagName.maxPerClip),
  };

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final TagColors tagColors = context.read<TagColors>();
    final List<String> suggestions = <String>[
      for (final String tag in widget.suggestions)
        if (!_draft.has(tag)) tag,
    ];
    final bool typed = _text.text.trim().isNotEmpty;
    return Column(
      key: TagsSheet.bodyKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.s16,
      children: <Widget>[
        if (_draft.isEmpty)
          Text(
            Strings.tagsNoneYet,
            key: TagsSheet.noneKey,
            style: typography.body14.copyWith(color: colors.sub),
          )
        else
          Wrap(
            spacing: OsdSpace.s8,
            runSpacing: OsdSpace.s8,
            children: <Widget>[
              for (final String tag in _draft.tags)
                TagChip(
                  key: TagsSheet.chipKey(tag),
                  label: tag,
                  color: tagColors.colorOf(tag),
                  onRemove: _saving ? null : () => _remove(tag),
                  removeSemanticsLabel: Strings.tagRemoveNamed(tag: tag),
                ),
            ],
          ),
        OsdTextField(
          key: TagsSheet.fieldKey,
          controller: _text,
          hint: Strings.addTag,
          leadingIcon: OsdIcons.sell,
          autofocus: true,
          maxLength: TagName.maxLength,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.none,
          errorText: _error == null ? null : _errorText(_error!),
          enabled: !_saving,
          onChanged: _changed,
          onSubmitted: (String text) {
            if (text.trim().isEmpty) return;
            _add(text);
          },
        ),
        if (suggestions.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: OsdSpace.s8,
            children: <Widget>[
              Text(
                Strings.tagsSuggestions,
                style: typography.caption13.copyWith(color: colors.mu),
              ),
              Wrap(
                spacing: OsdSpace.s8,
                runSpacing: OsdSpace.s8,
                children: <Widget>[
                  for (final String tag in suggestions)
                    TagChip(
                      key: TagsSheet.suggestionKey(tag),
                      label: tag,
                      color: tagColors.colorOf(tag),
                      onTap: _saving ? null : () => _add(tag),
                    ),
                ],
              ),
            ],
          ),
        PrimaryButton(
          key: TagsSheet.saveKey,
          label: Strings.save,
          loading: _saving,
          onPressed: _saving || !(_draft.isDirty || typed) ? null : _save,
        ),
      ],
    );
  }
}
