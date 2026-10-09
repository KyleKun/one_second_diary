import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/hue_slider.dart';
import 'package:one_second_diary/features/clip_editor/presentation/widgets/saturation_value_area.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_sheet.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_field.dart';
import 'package:one_second_diary/theme/osd_media.dart';

/// The custom stamp colour picker, opened from the date stamp sheet's
/// custom swatch and stacked over it.
///
/// Done gives the colour back; any other way out gives nothing (the stamp
/// keeps its colour). The stamp has no alpha, so neither has the picker.
class CustomColorSheet extends StatefulWidget {
  const CustomColorSheet({super.key, required this.initial});

  /// The saturation and brightness square.
  static const Key areaKey = Key('customColorSheet.area');

  static const Key hueKey = Key('customColorSheet.hue');

  /// The live swatch in the hex field.
  static const Key swatchKey = Key('customColorSheet.swatch');

  static const Key doneKey = Key('customColorSheet.done');

  final Color initial;

  /// Opens the picker on [initial] over the sheet of [context]; completes
  /// with the colour on Done, or null.
  static Future<Color?> show(BuildContext context, {required Color initial}) =>
      showOsdSheet<Color>(
        context,
        title: Strings.colorCustom,
        child: CustomColorSheet(initial: initial),
      );

  @override
  State<CustomColorSheet> createState() => _CustomColorSheetState();
}

class _CustomColorSheetState extends State<CustomColorSheet> {
  late HSVColor _color = HSVColor.fromColor(widget.initial.withAlpha(0xFF));
  late final TextEditingController _hex = TextEditingController(
    text: _hexOf(widget.initial),
  );

  static const double _swatch = 34;
  static final RegExp _hexDigits = RegExp(r'^#?([0-9a-fA-F]{6})$');

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  static String _hexOf(Color color) => (color.toARGB32() & 0xFFFFFF)
      .toRadixString(16)
      .padLeft(6, '0')
      .toUpperCase();

  /// The square or the slider moved: the field follows.
  void _picked(HSVColor color) {
    setState(() => _color = color);
    _hex.text = _hexOf(color.toColor());
  }

  /// The field changed: a full hex is the colour; anything else waits.
  void _typed(String text) {
    final RegExpMatch? match = _hexDigits.firstMatch(text.trim());
    if (match == null) return;
    final int rgb = int.parse(match.group(1)!, radix: 16);
    setState(() => _color = HSVColor.fromColor(Color(0xFF000000 | rgb)));
  }

  @override
  Widget build(BuildContext context) {
    final Color color = _color.toColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: <Widget>[
        SaturationValueArea(
          key: CustomColorSheet.areaKey,
          color: _color,
          onChanged: _picked,
        ),
        HueSlider(
          key: CustomColorSheet.hueKey,
          hue: _color.hue,
          onChanged: (double hue) => _picked(_color.withHue(hue)),
        ),
        OsdTextField(
          controller: _hex,
          leading: DecoratedBox(
            key: CustomColorSheet.swatchKey,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: const Border.fromBorderSide(
                BorderSide(color: OsdMedia.swatchHairline),
              ),
            ),
            child: const SizedBox.square(dimension: _swatch),
          ),
          hint: Strings.customColorHexLabel,
          semanticsLabel: Strings.customColorHexLabel,
          maxLength: 7,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp('[#0-9a-fA-F]')),
          ],
          onChanged: _typed,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
        ),
        NeutralButton(
          key: CustomColorSheet.doneKey,
          label: Strings.done,
          // The colour now, not the one built: a tap may come in the frame
          // right after a change.
          onPressed: () => Navigator.of(context).pop(_color.toColor()),
        ),
      ],
    );
  }
}
