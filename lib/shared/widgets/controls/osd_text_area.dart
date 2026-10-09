import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:one_second_diary/core/l10n/locale_formats.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_input.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The multi-line text area. Its minimum height includes padding and border;
/// it grows to five lines and then scrolls inside.
///
/// From [counterFrom] characters a counter "n/max" appears below; at
/// [maxLength] it turns RED and plays one heavy impact. Format the counter
/// with [counterText] when a language needs it. Without a [maxLength] the
/// text is of any length and there is no counter.
///
/// With [TextInputAction.newline] the keyboard's Enter adds a line.
///
/// The text area fills its box, padding included, so a tap anywhere in the
/// box focuses it and screen readers get one node the size of the box.
class OsdTextArea extends StatefulWidget {
  const OsdTextArea({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.autofocus = false,
    this.maxLength = 120,
    this.counterFrom = 100,
    this.counterText,
    this.textCapitalization = TextCapitalization.sentences,
    this.textInputAction = TextInputAction.done,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.semanticsLabel,
  });

  static const Key boxKey = Key('osdTextArea.box');

  static const Key counterKey = Key('osdTextArea.counter');

  static const int _maxLines = 5;
  static const double _minHeight = 100;
  static const double _border = 1.5;
  static const double _padH = 16;
  static const double _padV = 14;

  final TextEditingController? controller;

  /// The focus node; the area makes its own when null.
  final FocusNode? focusNode;

  final String? hint;

  final bool autofocus;

  /// The longest text, in characters; null for no limit.
  final int? maxLength;

  /// The length from which the counter shows.
  final int counterFrom;

  /// Formats the counter; "n/max" with locale digits by default.
  final String Function(int length, int maxLength)? counterText;

  final TextCapitalization textCapitalization;

  final TextInputAction? textInputAction;

  final List<TextInputFormatter>? inputFormatters;

  final ValueChanged<String>? onChanged;

  final ValueChanged<String>? onSubmitted;

  /// The screen-reader label (defaults to the hint).
  final String? semanticsLabel;

  @override
  State<OsdTextArea> createState() => _OsdTextAreaState();
}

class _OsdTextAreaState extends State<OsdTextArea> {
  TextEditingController? _ownController;
  FocusNode? _ownFocusNode;
  int _length = 0;

  TextEditingController get _controller =>
      widget.controller ?? (_ownController ??= TextEditingController());

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _length = _controller.text.characters.length;
    _controller.addListener(_onText);
    _focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(OsdTextArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownController)?.removeListener(_onText);
      _controller.addListener(_onText);
      _length = _controller.text.characters.length;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocus);
      _focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    _focusNode.removeListener(_onFocus);
    _ownController?.dispose();
    _ownFocusNode?.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  void _onText() {
    final length = _controller.text.characters.length;
    if (length == _length) return;
    final max = widget.maxLength;
    if (max != null && length >= max && _length < max) {
      unawaited(OsdHaptic.heavy.play());
    }
    setState(() => _length = length);
  }

  String _counter(int length, int max) {
    final format = widget.counterText;
    if (format != null) return format(length, max);
    final numbers = LocaleFormats.of(context).numbers;
    return '${numbers.format(length)}/${numbers.format(max)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final focused = _focusNode.hasFocus;
    final max = widget.maxLength;
    final atLimit = max != null && _length >= max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: <Widget>[
        AnimatedContainer(
          key: OsdTextArea.boxKey,
          duration: OsdMotion.d(context, const Duration(milliseconds: 120)),
          curve: OsdMotion.curve(context, OsdMotion.fastCurve),
          constraints: const BoxConstraints(minHeight: OsdTextArea._minHeight),
          decoration: BoxDecoration(
            color: colors.c2,
            border: Border.all(
              color: focused ? colors.tx : colors.tx.withValues(alpha: 0),
              width: OsdTextArea._border,
            ),
            borderRadius: BorderRadius.circular(OsdRadius.r16),
          ),
          child: OsdTextInput(
            controller: _controller,
            focusNode: _focusNode,
            style: typography.body16Loose,
            hint: widget.hint,
            semanticsLabel: widget.semanticsLabel,
            autofocus: widget.autofocus,
            maxLength: widget.maxLength,
            minLines: 1,
            maxLines: OsdTextArea._maxLines,
            cursorHeight: 18,
            keyboardType: widget.textInputAction == TextInputAction.newline
                ? TextInputType.multiline
                : TextInputType.text,
            textCapitalization: widget.textCapitalization,
            textInputAction: widget.textInputAction,
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            enabled: true,
            errorText: null,
            padding: const EdgeInsets.symmetric(
              horizontal: OsdTextArea._padH,
              vertical: OsdTextArea._padV,
            ),
            // The box's minimum less its border: padding and border are
            // inside the min-height.
            minHeight: OsdTextArea._minHeight - 2 * OsdTextArea._border,
            textAlignVertical: TextAlignVertical.top,
          ),
        ),
        if (max != null && _length >= widget.counterFrom)
          Text(
            _counter(_length, max),
            key: OsdTextArea.counterKey,
            textAlign: TextAlign.end,
            style: typography.caption.copyWith(
              color: atLimit ? colors.red : colors.mu,
            ),
          ),
      ],
    );
  }
}
