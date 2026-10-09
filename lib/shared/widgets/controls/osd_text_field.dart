import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:one_second_diary/shared/widgets/controls/osd_text_input.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The single-line text field.
///
/// The border is always drawn so nothing jumps: transparent, TX while
/// focused, RED with an [errorText]. The error line sits below; a new error
/// shakes the field (not under reduced motion). [maxLength] is enforced
/// without a counter.
///
/// Every visual comes from the container. The text field fills it, padding
/// and leading icon included, so a tap anywhere in the box focuses it and
/// screen readers get one field node the size of the box; the error is that
/// node's hint and a live region that is announced when it appears.
class OsdTextField extends StatefulWidget {
  const OsdTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.leadingIcon,
    this.leading,
    this.errorText,
    this.autofocus = false,
    this.maxLength,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.semanticsLabel,
  });

  static const Key boxKey = Key('osdTextField.box');

  static const Key leadingKey = Key('osdTextField.leading');

  final TextEditingController? controller;

  /// The focus node; the field makes its own when null.
  final FocusNode? focusNode;

  final String? hint;

  final IconData? leadingIcon;

  /// A leading widget instead of [leadingIcon].
  final Widget? leading;

  /// A validation message; turns the border RED.
  final String? errorText;

  final bool autofocus;

  final int? maxLength;

  final TextInputType? keyboardType;

  final TextCapitalization textCapitalization;

  final TextInputAction? textInputAction;

  final List<TextInputFormatter>? inputFormatters;

  final ValueChanged<String>? onChanged;

  final ValueChanged<String>? onSubmitted;

  final bool enabled;

  /// The screen-reader label (defaults to the hint).
  final String? semanticsLabel;

  @override
  State<OsdTextField> createState() => _OsdTextFieldState();
}

class _OsdTextFieldState extends State<OsdTextField>
    with SingleTickerProviderStateMixin {
  static const Duration _border = Duration(milliseconds: 120);
  static const double _borderWidth = 1.5;
  static const double _minHeight = 52;
  static const double _padding = 14;
  static const double _leadingGap = 12;

  /// The gap the decorator adds after its prefix-icon slot.
  static const double _prefixToText = 4;
  static const Duration _shakeDuration = Duration(milliseconds: 300);
  static const double _shakeDistance = 6;

  FocusNode? _ownFocusNode;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: _shakeDuration,
  );

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(OsdTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocus);
      _focusNode.addListener(_onFocus);
    }
    if (widget.errorText != null &&
        oldWidget.errorText == null &&
        !OsdMotion.reduced(context)) {
      unawaited(_shake.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    _ownFocusNode?.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final error = widget.errorText;
    final focused = _focusNode.hasFocus;
    final border = error != null
        ? colors.red
        : focused
        ? colors.tx
        : colors.tx.withValues(alpha: 0);
    final leading =
        widget.leading ??
        (widget.leadingIcon == null
            ? null
            : OsdIcon(widget.leadingIcon!, color: colors.mu));
    final box = AnimatedContainer(
      key: OsdTextField.boxKey,
      duration: OsdMotion.d(context, _border),
      curve: OsdMotion.curve(context, OsdMotion.fastCurve),
      constraints: const BoxConstraints(minHeight: _minHeight),
      decoration: BoxDecoration(
        color: colors.c2,
        border: Border.all(color: border, width: _borderWidth),
        borderRadius: BorderRadius.circular(OsdRadius.r16),
      ),
      child: OsdTextInput(
        controller: widget.controller,
        focusNode: _focusNode,
        style: typography.field,
        hint: widget.hint,
        semanticsLabel: widget.semanticsLabel,
        errorText: error,
        autofocus: widget.autofocus,
        maxLength: widget.maxLength,
        minLines: 1,
        maxLines: 1,
        cursorHeight: 20,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        textInputAction: widget.textInputAction,
        inputFormatters: widget.inputFormatters,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        enabled: widget.enabled,
        padding: const EdgeInsetsDirectional.only(end: _padding),
        minHeight: _minHeight - 2 * _borderWidth,
        textAlignVertical: TextAlignVertical.center,
        prefix: Padding(
          padding: EdgeInsetsDirectional.only(
            start: leading == null ? _padding - _prefixToText : _padding,
            end: leading == null ? 0 : _leadingGap - _prefixToText,
          ),
          child: leading == null
              ? null
              : Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: ExcludeSemantics(
                    child: KeyedSubtree(
                      key: OsdTextField.leadingKey,
                      child: leading,
                    ),
                  ),
                ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: <Widget>[
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(
              _shakeDistance *
                  math.sin(_shake.value * 3 * 2 * math.pi) *
                  (_shake.isAnimating ? 1 : 0),
              0,
            ),
            child: child,
          ),
          child: box,
        ),
        if (error != null)
          Semantics(
            container: true,
            liveRegion: true,
            child: Text(
              error,
              style: typography.rowSubtitle.copyWith(color: colors.red),
            ),
          ),
      ],
    );
  }
}
