import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

enum _Variant { icon, soft, caps, overline }

/// Section labels. Every variant is a semantics header of its own (only the
/// label is the heading) and wraps to at most 2 lines.
class SectionLabel extends StatelessWidget {
  /// A label with a leading accent icon.
  const SectionLabel.icon({
    super.key,
    required this.label,
    required IconData this.icon,
    required Color this.iconColor,
    this.padding = const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 8),
  }) : _variant = _Variant.icon,
       sub = false;

  /// A sentence-case label; [sub] uses the SUB grey (on BG or SH only).
  const SectionLabel.soft({
    super.key,
    required this.label,
    this.sub = false,
    this.padding = EdgeInsets.zero,
  }) : _variant = _Variant.soft,
       icon = null,
       iconColor = null;

  /// An uppercase header on a BG fill (month headers, pinned by the caller).
  const SectionLabel.caps({
    super.key,
    required this.label,
    this.padding = const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 10),
  }) : _variant = _Variant.caps,
       sub = true,
       icon = null,
       iconColor = null;

  /// The uppercase overline of the Today header.
  const SectionLabel.overline({
    super.key,
    required this.label,
    this.padding = EdgeInsets.zero,
  }) : _variant = _Variant.overline,
       sub = false,
       icon = null,
       iconColor = null;

  final String label;

  final IconData? icon;

  final Color? iconColor;

  /// Whether the text is SUB instead of MU.
  final bool sub;

  final EdgeInsetsGeometry padding;

  final _Variant _variant;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final color = sub ? colors.sub : colors.mu;
    final style = switch (_variant) {
      _Variant.icon => typography.sectionLabel,
      _Variant.soft => typography.sectionLabelSoft,
      _Variant.caps => typography.sectionCaps,
      _Variant.overline => typography.overline,
    }.copyWith(color: color);
    final uppercase =
        _variant == _Variant.caps || _variant == _Variant.overline;
    Widget text = Text(
      uppercase ? label.toUpperCase() : label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    final icon = this.icon;
    if (icon != null) {
      text = Row(
        spacing: 6,
        children: <Widget>[
          OsdIcon(icon, size: 18, color: iconColor),
          Flexible(child: text),
        ],
      );
    }
    // Its own node: only the label is the heading, never what follows it
    // in the same group.
    Widget result = Semantics(
      container: true,
      header: true,
      child: Padding(padding: padding, child: text),
    );
    if (_variant == _Variant.caps) {
      result = ColoredBox(color: colors.bg, child: result);
    }
    return result;
  }
}
