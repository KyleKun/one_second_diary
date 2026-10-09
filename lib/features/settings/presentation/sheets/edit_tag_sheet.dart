import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/common_labels.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clips/data/tag_colors.dart';
import 'package:one_second_diary/features/clips/domain/tag_count.dart';
import 'package:one_second_diary/features/clips/domain/tag_name.dart';
import 'package:one_second_diary/features/settings/presentation/cubit/tags_cubit.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_confirm_dialog.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/color_swatch_button.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_field.dart';
import 'package:one_second_diary/shared/widgets/controls/swatch_grid.dart';
import 'package:one_second_diary/shared/widgets/controls/tag_chip.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/surfaces/section_label.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The "Edit tag" sheet of Settings › Tags: the tag as a chip, its name
/// (Save renames it on every clip; a name another tag already has merges
/// into that tag, after asking), its colour (a swatch grid with
/// "Automatic"; a tap applies at once) and "Remove tag" (asks, then takes
/// it off every clip).
///
/// Open it with [show]. A rename or removal closes the sheet and starts a
/// batch on the page's `TagsCubit`, whose progress the page shows.
class EditTagSheet extends StatefulWidget {
  const EditTagSheet({super.key, required this.tag});

  static const Key bodyKey = Key('editTagSheet.body');

  static const Key fieldKey = Key('editTagSheet.field');

  static const Key saveKey = Key('editTagSheet.save');

  static const Key removeKey = Key('editTagSheet.remove');

  /// The "Automatic" colour swatch.
  static const Key autoColorKey = Key('editTagSheet.autoColor');

  /// The swatch of [index] (into `OsdMedia.stampSwatches`).
  static Key swatchKey(int index) =>
      ValueKey<String>('editTagSheet.swatch.$index');

  /// The tag edited, with how many clips carry it.
  final TagCount tag;

  /// Opens the sheet on [tag] over the page of [cubit]. Completes when the
  /// sheet closes.
  static Future<void> show(
    BuildContext context, {
    required TagsCubit cubit,
    required TagCount tag,
  }) => showOsdSheet<void>(
    context,
    title: Strings.editTag,
    titleIcon: OsdIcons.sell,
    child: BlocProvider<TagsCubit>.value(
      value: cubit,
      child: EditTagSheet(key: bodyKey, tag: tag),
    ),
  );

  @override
  State<EditTagSheet> createState() => _EditTagSheetState();
}

class _EditTagSheetState extends State<EditTagSheet> {
  late final TextEditingController _text = TextEditingController(
    text: widget.tag.name,
  )..addListener(_textChanged);
  TagNameError? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Save follows what is typed; a refused name is forgiven on the next
  /// keystroke.
  void _textChanged() {
    if (mounted) setState(() => _error = null);
  }

  /// Whether what is typed names the tag differently.
  bool get _changed => TagName.clean(_text.text) != widget.tag.name;

  /// Another tag of the library the typed name is the same as (a merge),
  /// or null.
  TagCount? _other(String cleaned) {
    final TagsCubit cubit = context.read<TagsCubit>();
    for (final TagCount tag in cubit.state.tags) {
      if (tag.name != widget.tag.name && TagName.same(tag.name, cleaned)) {
        return tag;
      }
    }
    return null;
  }

  Future<void> _save() async {
    final String raw = _text.text;
    final TagNameError? error = TagName.validate(raw);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final String cleaned = TagName.clean(raw);
    final TagsCubit cubit = context.read<TagsCubit>();
    final TagCount? other = _other(cleaned);
    String to = cleaned;
    if (other != null) {
      final bool confirmed = await OsdConfirmDialog.show(
        context,
        title: Strings.mergeTagTitle(tag: other.name),
        body: Strings.mergeTagBody(
          widget.tag.count,
          tag: other.name,
          format: LocaleFormats.of(context).numbers,
        ),
        cancelLabel: CommonLabels.of(context).cancel,
        confirmLabel: Strings.mergeTag,
      );
      if (!confirmed || !mounted) return;
      to = other.name;
    }
    unawaited(OsdHaptic.light.play());
    Navigator.of(context).pop();
    unawaited(cubit.rename(widget.tag.name, to));
  }

  Future<void> _remove() async {
    final TagsCubit cubit = context.read<TagsCubit>();
    final CommonLabels labels = CommonLabels.of(context);
    final bool confirmed = await OsdConfirmDialog.show(
      context,
      title: Strings.removeTagTitle(tag: widget.tag.name),
      body: Strings.removeTagBody(
        widget.tag.count,
        format: LocaleFormats.of(context).numbers,
      ),
      cancelLabel: labels.cancel,
      confirmLabel: labels.delete,
      destructive: true,
      badgeIcon: OsdIcons.delete,
    );
    if (!confirmed || !mounted) return;
    Navigator.of(context).pop();
    unawaited(cubit.remove(widget.tag.name));
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
    final String name = widget.tag.name;
    // Repaints the chip and the grid when the colour changes.
    context.select((TagsCubit cubit) => cubit.state.colorsVersion);
    final TagColors tagColors = context.read<TagColors>();
    final bool chosen = tagColors.isChosen(name);
    final int current = tagColors.indexOf(name);
    final List<String> names = _swatchNames();
    return Column(
      key: EditTagSheet.bodyKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: OsdSpace.sheetGap,
      children: <Widget>[
        Row(
          children: <Widget>[
            TagChip(label: name, color: tagColors.colorOf(name)),
            const SizedBox(width: OsdSpace.s12),
            Expanded(
              child: Text(
                Strings.tagVideoCount(
                  widget.tag.count,
                  format: LocaleFormats.of(context).numbers,
                ),
                style: typography.body14.copyWith(color: colors.sub),
              ),
            ),
          ],
        ),
        OsdTextField(
          key: EditTagSheet.fieldKey,
          controller: _text,
          hint: Strings.tagName,
          leadingIcon: OsdIcons.driveFileRenameOutline,
          maxLength: TagName.maxLength,
          textInputAction: TextInputAction.done,
          errorText: _error == null ? null : _errorText(_error!),
          onSubmitted: (_) => unawaited(_save()),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: OsdSpace.s8,
          children: <Widget>[
            SectionLabel.soft(label: Strings.tagColor),
            SwatchGrid(
              itemCount: TagColors.swatchIndexes.length + 1,
              itemBuilder: (BuildContext context, int index, double diameter) {
                if (index == 0) {
                  final Color automatic =
                      OsdMedia.stampSwatches[TagColors.automaticIndexOf(name)];
                  return ColorSwatchButton(
                    key: EditTagSheet.autoColorKey,
                    color: automatic,
                    selected: !chosen,
                    semanticsLabel: Strings.tagColorAuto,
                    diameter: diameter,
                    hairline: false,
                    glyph: OsdIcon(
                      OsdIcons.colorize,
                      size: 16,
                      color: OsdMedia.inkOn(automatic),
                    ),
                    onTap: () => _pick(null),
                  );
                }
                final int swatch = TagColors.swatchIndexes[index - 1];
                return ColorSwatchButton(
                  key: EditTagSheet.swatchKey(swatch),
                  color: OsdMedia.stampSwatches[swatch],
                  selected: chosen && current == swatch,
                  semanticsLabel: names[swatch],
                  diameter: diameter,
                  onTap: () => _pick(swatch),
                );
              },
            ),
            Text(
              chosen ? names[current] : Strings.tagColorAuto,
              style: typography.caption13.copyWith(color: colors.mu),
            ),
          ],
        ),
        PrimaryButton(
          key: EditTagSheet.saveKey,
          label: Strings.save,
          onPressed: _changed ? () => unawaited(_save()) : null,
        ),
        OsdTextButton(
          key: EditTagSheet.removeKey,
          label: Strings.removeTag,
          icon: OsdIcons.delete,
          tone: OsdTextButtonTone.destructive,
          onPressed: () => unawaited(_remove()),
        ),
      ],
    );
  }

  void _pick(int? swatch) {
    unawaited(OsdHaptic.selection.play());
    unawaited(context.read<TagsCubit>().setColor(widget.tag.name, swatch));
  }

  /// The swatches' names, in `OsdMedia.stampSwatches` order.
  static List<String> _swatchNames() => <String>[
    Strings.colorWhite,
    Strings.colorBlack,
    Strings.colorCoral,
    Strings.colorRed,
    Strings.colorOrange,
    Strings.colorGold,
    Strings.colorYellow,
    Strings.colorGreen,
    Strings.colorTeal,
    Strings.colorSkyBlue,
    Strings.colorIndigo,
    Strings.colorLavender,
    Strings.colorPink,
    Strings.colorBrown,
    Strings.colorGrey,
  ];
}
