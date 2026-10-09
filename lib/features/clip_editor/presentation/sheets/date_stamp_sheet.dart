import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/core/media/types/clip_format.dart';
import 'package:one_second_diary/core/media/types/stamp_format.dart';
import 'package:one_second_diary/core/media/types/stamp_style.dart';
import 'package:one_second_diary/core/time/local_day.dart';
import 'package:one_second_diary/features/clip_editor/data/filmstrip_frames.dart';
import 'package:one_second_diary/features/clip_editor/presentation/cubit/edit_clip_cubit.dart';
import 'package:one_second_diary/features/clip_editor/presentation/sheets/custom_color_sheet.dart';
import 'package:one_second_diary/features/clip_editor/presentation/stamp_texts.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/clip_stamp_preview.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/color_swatch_button.dart';
import 'package:one_second_diary/shared/widgets/controls/custom_swatch.dart';
import 'package:one_second_diary/shared/widgets/controls/option_tile.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_switch.dart';
import 'package:one_second_diary/shared/widgets/controls/swatch_grid.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_card.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_list_row.dart';
import 'package:one_second_diary/shared/widgets/surfaces/section_label.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_radius.dart';

/// The date stamp sheet: a close-up of the corner of the clip the date is
/// burned in (`ClipStampPreview`), its two formats, the text size (the
/// date's and the place's, one choice), the preset colours and a custom
/// one, and the contrast outline.
///
/// Every change applies at once, to the preview behind the sheet too, and
/// is the next clip's style (no cancel; every way out keeps it). A colour
/// outside the presets is the custom swatch's.
class DateStampSheet extends StatefulWidget {
  const DateStampSheet({super.key, required this.format});

  /// The format of the profile the clip goes to: the preview tile shows
  /// the corner of its canvas the date is burned in.
  final ClipFormat format;

  static const Key bodyKey = Key('dateStampSheet.body');

  static const Key doneKey = Key('dateStampSheet.done');

  /// The text size tile of [size].
  static Key sizeKey(StampSize size) => Key('dateStampSheet.size.${size.name}');

  /// Opens the sheet over the clip editor of [context].
  static Future<void> show(BuildContext context, {required ClipFormat format}) {
    final EditClipCubit editor = context.read<EditClipCubit>();
    final FilmstripFrames frames = context.read<FilmstripFrames>();
    return showOsdSheet<void>(
      context,
      title: Strings.dateColorAndFormat,
      child: RepositoryProvider<FilmstripFrames>.value(
        value: frames,
        child: BlocProvider<EditClipCubit>.value(
          value: editor,
          child: DateStampSheet(format: format),
        ),
      ),
    );
  }

  @override
  State<DateStampSheet> createState() => _DateStampSheetState();
}

class _DateStampSheetState extends State<DateStampSheet> {
  /// The custom swatch's colour: the stamp's when it is none of the
  /// presets, kept while the sheet is open after another swatch is picked.
  Color? _custom;

  /// The format tiles share the row 1 : 1.4.
  static const int _numericFlex = 10;
  static const int _writtenFlex = 14;

  @override
  void initState() {
    super.initState();
    _custom = _customOf(context.read<EditClipCubit>().state.draft.stamp);
  }

  static Color? _customOf(StampStyle stamp) {
    final Color color = Color(0xFF000000 | stamp.rgb);
    return OsdMedia.stampSwatches.contains(color) ? null : color;
  }

  /// Applies a change to the style as it is now (two taps may come in one
  /// frame).
  void _change({
    StampFormat? format,
    Color? color,
    bool? outline,
    StampSize? size,
  }) {
    final EditClipCubit editor = context.read<EditClipCubit>();
    final StampStyle now = editor.state.draft.stamp;
    unawaited(
      editor.stampChanged(
        StampStyle(
          format: format ?? now.format,
          rgb: color == null ? now.rgb : color.toARGB32() & 0xFFFFFF,
          outline: outline ?? now.outline,
          size: size ?? now.size,
        ),
      ),
    );
  }

  static String _sizeLabel(StampSize size) => switch (size) {
    StampSize.small => Strings.stampSizeSmall,
    StampSize.medium => Strings.stampSizeMedium,
    StampSize.large => Strings.stampSizeLarge,
  };

  Future<void> _pickCustom() async {
    final int rgb = context.read<EditClipCubit>().state.draft.stamp.rgb;
    final Color? picked = await CustomColorSheet.show(
      context,
      initial: _custom ?? Color(0xFF000000 | rgb),
    );
    if (picked == null || !mounted) return;
    setState(() => _custom = picked);
    _change(color: picked);
  }

  static List<String> _names() => <String>[
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

  @override
  Widget build(BuildContext context) {
    final LocalDay day = context.select(
      (EditClipCubit editor) => editor.state.args.day,
    );
    final StampStyle stamp = context.select(
      (EditClipCubit editor) => editor.state.draft.stamp,
    );
    final Color color = Color(0xFF000000 | stamp.rgb);
    final String numeric = StampTexts.of(
      context,
      day: day,
      format: StampFormat.numeric,
    );
    final String written = StampTexts.of(
      context,
      day: day,
      format: StampFormat.written,
    );
    final List<String> names = _names();
    final int swatchCount = OsdMedia.stampSwatches.length;
    final Color? custom = _custom;
    return Column(
      key: DateStampSheet.bodyKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: <Widget>[
        ClipStampPreview(format: widget.format),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: <Widget>[
            SectionLabel.soft(label: Strings.dateStampFormatLabel),
            Row(
              spacing: 8,
              children: <Widget>[
                for (final (StampFormat format, String label, int flex)
                    in <(StampFormat, String, int)>[
                      (StampFormat.numeric, numeric, _numericFlex),
                      (StampFormat.written, written, _writtenFlex),
                    ])
                  Expanded(
                    flex: flex,
                    child: OptionTile(
                      label: label,
                      selected: stamp.format == format,
                      onTap: () => _change(format: format),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: <Widget>[
            SectionLabel.soft(label: Strings.stampSizeLabel),
            Row(
              spacing: 8,
              children: <Widget>[
                for (final StampSize size in StampSize.values)
                  Expanded(
                    child: OptionTile(
                      key: DateStampSheet.sizeKey(size),
                      label: _sizeLabel(size),
                      selected: stamp.size == size,
                      onTap: () => _change(size: size),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: <Widget>[
            SectionLabel.soft(label: Strings.selectColor),
            SwatchGrid(
              itemCount: swatchCount + 1,
              itemBuilder: (BuildContext context, int index, double diameter) {
                if (index == swatchCount) {
                  return CustomSwatch(
                    color: custom,
                    selected: custom != null && custom == color,
                    semanticsLabel: Strings.colorCustom,
                    diameter: diameter,
                    onTap: () => unawaited(_pickCustom()),
                  );
                }
                final Color swatch = OsdMedia.stampSwatches[index];
                return ColorSwatchButton(
                  color: swatch,
                  selected: swatch == color,
                  semanticsLabel: names[index],
                  diameter: diameter,
                  onTap: () => _change(color: swatch),
                );
              },
            ),
          ],
        ),
        OsdCard(
          tone: OsdCardTone.c2,
          radius: OsdRadius.r16,
          margin: EdgeInsets.zero,
          child: OsdListRow(
            title: Strings.textOutline,
            subtitle: Strings.textOutlineHint,
            trailing: OsdRowTrailing.custom(
              OsdSwitch(value: stamp.outline, interactive: false),
            ),
            toggled: stamp.outline,
            onTap: () => _change(
              outline: !context.read<EditClipCubit>().state.draft.stamp.outline,
            ),
          ),
        ),
        NeutralButton(
          key: DateStampSheet.doneKey,
          label: Strings.done,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
