import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:one_second_diary/theme/osd_colors.dart';

/// The bare `TextField` inside `OsdTextField` and `OsdTextArea`. Use the two
/// fields, not this building block.
///
/// The field fills its box: the box's [padding] and the [prefix] (a leading
/// icon) are inside it, so a tap anywhere in the box focuses the field and
/// its one semantics node is the size of the box. The box draws the fill and
/// the border, so nothing of the theme's input decoration shows. [errorText]
/// is the node's hint.
///
/// The node is named [semanticsLabel], or the [hint] without one, whether
/// or not the field holds text: the hint text is read only while it shows,
/// so without a label a filled field would say just its value.
///
/// A one-line input's hint stays on one line and scales down to fit rather
/// than lose its end; an area's hint wraps.
class OsdTextInput extends StatefulWidget {
  const OsdTextInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.hint,
    required this.semanticsLabel,
    required this.autofocus,
    required this.maxLength,
    required this.minLines,
    required this.maxLines,
    required this.cursorHeight,
    required this.keyboardType,
    required this.textCapitalization,
    required this.textInputAction,
    required this.inputFormatters,
    required this.onChanged,
    required this.onSubmitted,
    required this.enabled,
    required this.padding,
    required this.minHeight,
    required this.textAlignVertical,
    required this.errorText,
    this.prefix,
  });

  /// The text; the input keeps its own when null.
  final TextEditingController? controller;

  /// The focus node (the fields watch it for their border).
  final FocusNode focusNode;

  /// The text style, without colour.
  final TextStyle style;

  final String? hint;

  /// The screen-reader label; the [hint] when null.
  final String? semanticsLabel;

  final bool autofocus;

  final int? maxLength;

  final int minLines;

  /// The most lines before it scrolls.
  final int maxLines;

  final double cursorHeight;

  final TextInputType? keyboardType;

  final TextCapitalization textCapitalization;

  final TextInputAction? textInputAction;

  final List<TextInputFormatter>? inputFormatters;

  final ValueChanged<String>? onChanged;

  final ValueChanged<String>? onSubmitted;

  final bool enabled;

  /// The box's padding around the text (inside the field, so it takes taps).
  final EdgeInsetsGeometry padding;

  /// The box's inner height, at least.
  final double minHeight;

  /// Where the text sits in [minHeight]: centred in a field, at the top in an
  /// area.
  final TextAlignVertical textAlignVertical;

  /// The validation message the box shows, read with the field.
  final String? errorText;

  /// What comes before the text, [minHeight] tall so a single line centres
  /// (the field's start padding and leading icon). It sits in the
  /// decorator's prefix-icon slot, which adds 4 before the text.
  final Widget? prefix;

  @override
  State<OsdTextInput> createState() => _OsdTextInputState();
}

class _OsdTextInputState extends State<OsdTextInput> {
  TextEditingController? _ownController;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  @override
  void dispose() {
    _ownController?.dispose();
    super.dispose();
  }

  /// The node's name for [value]. While the field is empty the hint text
  /// shows and names it, so a label equal to the hint is left out then
  /// (else it would be read twice).
  String? _labelFor(TextEditingValue value) {
    final String? hint = widget.hint;
    final String? name = widget.semanticsLabel ?? hint;
    return value.text.isEmpty && name == hint ? null : name;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final String? hint = widget.hint;
    final TextStyle hintStyle = widget.style.copyWith(color: colors.mu);
    final bool oneLine = widget.maxLines == 1;
    return TextSelectionTheme(
      data: TextSelectionThemeData(
        cursorColor: colors.co,
        selectionColor: colors.co.withValues(alpha: .25),
        selectionHandleColor: colors.co,
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder:
            (BuildContext context, TextEditingValue value, Widget? field) =>
                Semantics(
                  label: _labelFor(value),
                  hint: widget.errorText,
                  child: field,
                ),
        child: TextField(
          controller: _controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          style: widget.style.copyWith(color: colors.tx),
          decoration: InputDecoration(
            isCollapsed: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            hintText: oneLine ? null : hint,
            hint: oneLine && hint != null
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(hint, maxLines: 1, style: hintStyle),
                  )
                : null,
            hintStyle: hintStyle,
            contentPadding: widget.padding,
            prefixIcon: widget.prefix,
            prefixIconConstraints: widget.prefix == null
                ? null
                : BoxConstraints(minHeight: widget.minHeight),
            constraints: BoxConstraints(minHeight: widget.minHeight),
          ),
          textAlignVertical: widget.textAlignVertical,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          buildCounter:
              (
                context, {
                required currentLength,
                required isFocused,
                required maxLength,
              }) => null,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          textInputAction: widget.textInputAction,
          inputFormatters: widget.inputFormatters,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          cursorColor: colors.co,
          cursorWidth: 2,
          cursorHeight: widget.cursorHeight,
          cursorRadius: const Radius.circular(1),
          keyboardAppearance: Theme.of(context).brightness,
          scrollPadding: const EdgeInsets.all(32),
        ),
      ),
    );
  }
}
