import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/fade_rise.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_sizes.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The end of an [OsdListRow].
sealed class OsdRowTrailing {
  const OsdRowTrailing();

  const factory OsdRowTrailing.none() = _NoTrailing;

  /// A chevron: the row opens a page.
  const factory OsdRowTrailing.chevron() = _Chevron;

  /// An `open_in_new` glyph: the row opens the browser.
  const factory OsdRowTrailing.external() = _External;

  /// A check: the selected option.
  const factory OsdRowTrailing.check() = _Check;

  const factory OsdRowTrailing.radio({required bool selected}) = _Radio;

  /// Any widget, e.g. a visual-only `OsdSwitch` (the row owns the gesture).
  const factory OsdRowTrailing.custom(Widget child) = _Custom;
}

class _NoTrailing extends OsdRowTrailing {
  const _NoTrailing();
}

class _Chevron extends OsdRowTrailing {
  const _Chevron();
}

class _External extends OsdRowTrailing {
  const _External();
}

class _Check extends OsdRowTrailing {
  const _Check();
}

class _Radio extends OsdRowTrailing {
  const _Radio({required this.selected});

  final bool selected;
}

class _Custom extends OsdRowTrailing {
  const _Custom(this.child);

  final Widget child;
}

/// A grouped list row: leading, text and trailing.
///
/// - **Title:** stronger with a [subtitle] (or [titleStyle]); up to 2 lines
///   (any number at large text scales).
/// - **Subtitle:** below the title, any number of lines.
/// - **Value:** at most 45 % of the row, [valueMaxLines] lines; at large
///   text scales it moves under the title. A changed value crossfades: the
///   new one fades in and rises, the old one fades out (a fade in place
///   under reduced motion).
/// - **Pressed:** an overlay without scaling (the card clips it).
///   **Disabled** ([enabled] false): the whole row fades.
/// - **Semantics:** one node, "title, value" (then the subtitle); switch rows
///   set [toggled].
class OsdListRow extends StatelessWidget {
  const OsdListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.value,
    this.valueMaxLines = 1,
    this.valueLeading,
    this.icon,
    this.iconColor,
    this.iconFill = 0,
    this.leading,
    this.trailing = const OsdRowTrailing.none(),
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.titleStyle,
    this.minHeight = OsdSizes.listRowHeight,
    this.gap = OsdSpace.rowGap,
    this.haptic,
    this.toggled,
    this.checked,
    this.inMutuallyExclusiveGroup,
    this.semanticsHint,
  });

  /// The trailing glyph (chevron, check, radio).
  static const Key trailingKey = Key('osdListRow.trailing');

  static const Key valueKey = Key('osdListRow.value');

  final String title;

  final String? subtitle;

  /// The value at the end ("English", "20:00").
  final String? value;

  /// The lines the value takes before its ellipsis.
  final int valueMaxLines;

  /// A widget before the value (a flag).
  final Widget? valueLeading;

  /// A leading icon (MU by default).
  final IconData? icon;

  final Color? iconColor;

  /// The icon's FILL value.
  final double iconFill;

  /// A leading widget instead of [icon].
  final Widget? leading;

  final OsdRowTrailing trailing;

  final VoidCallback? onTap;

  final VoidCallback? onLongPress;

  /// False fades the whole row and ignores taps.
  final bool enabled;

  /// Replaces the title role, a typography style (`titleSmall` on a
  /// selected radio row), so Bold Text still applies.
  final TextStyle? titleStyle;

  final double minHeight;

  /// The gap between leading, text and trailing.
  final double gap;

  /// Played on tap.
  final OsdHaptic? haptic;

  /// Semantics `toggled` (switch rows: the whole row toggles).
  final bool? toggled;

  /// Semantics `checked` (radio rows).
  final bool? checked;

  /// Semantics `inMutuallyExclusiveGroup` (radio rows).
  final bool? inMutuallyExclusiveGroup;

  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final valueUnderTitle =
        OsdTextScale.factorOf(context) >= OsdTextScale.valuesUnderTitleFrom;
    final subtitle = this.subtitle;
    final value = this.value;
    final valueStyle = typography.body14.copyWith(color: colors.mu);

    final leading =
        this.leading ??
        (icon == null
            ? null
            : OsdIcon(icon!, fill: iconFill, color: iconColor ?? colors.mu));

    final bool wrapTitle =
        OsdTextScale.factorOf(context) >= OsdTextScale.valuesUnderTitleFrom;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          // Up to 2 lines; once the value moves under it, any number, so a
          // long translation is never cut. (An ellipsis without maxLines
          // would cut it to one line.)
          maxLines: wrapTitle ? null : 2,
          overflow: wrapTitle ? null : TextOverflow.ellipsis,
          style:
              (titleStyle ??
                      (subtitle == null
                          ? typography.rowTitle
                          : typography.rowTitleStrong))
                  .copyWith(color: colors.tx),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: typography.rowSubtitle.copyWith(color: colors.mu),
          ),
        ],
        if (value != null && valueUnderTitle)
          _Value(
            value: value,
            leading: valueLeading,
            style: valueStyle,
            maxLines: valueMaxLines,
            alignment: AlignmentDirectional.centerStart,
          ),
      ],
    );

    final trailingWidget = _trailing(context);
    Widget row = LayoutBuilder(
      builder: (context, constraints) => Row(
        spacing: gap,
        children: <Widget>[
          ?leading,
          Expanded(child: text),
          if (value != null && !valueUnderTitle)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * .45),
              child: _Value(
                value: value,
                leading: valueLeading,
                style: valueStyle,
                maxLines: valueMaxLines,
                alignment: AlignmentDirectional.centerEnd,
              ),
            ),
          ?trailingWidget,
        ],
      ),
    );

    row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OsdSpace.rowPadH,
          vertical: OsdSpace.rowPadV,
        ),
        child: row,
      ),
    );

    final interactive = enabled && (onTap != null || onLongPress != null);
    row = OsdPressable(
      opacity: OsdPressable.opacityFor(enabled: enabled),
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      pressScale: null,
      focusStyle: OsdFocusStyle.inner,
      haptic: haptic,
      isButton: interactive && checked == null,
      toggled: toggled,
      checked: checked,
      inMutuallyExclusiveGroup: inMutuallyExclusiveGroup,
      semanticsLabel: <String>[title, ?value, ?subtitle].join(', '),
      semanticsHint: semanticsHint,
      excludeChildSemantics: true,
      child: row,
    );
    return row;
  }

  Widget? _trailing(BuildContext context) {
    final colors = context.colors;
    return switch (trailing) {
      _NoTrailing() => null,
      _Chevron() => OsdIcon(
        OsdIcons.chevronRight,
        key: trailingKey,
        color: colors.fa,
      ),
      _External() => OsdIcon(
        OsdIcons.openInNew,
        key: trailingKey,
        color: colors.fa,
      ),
      _Check() => OsdIcon(OsdIcons.check, key: trailingKey, color: colors.tx),
      _Radio(:final selected) => AnimatedSwitcher(
        key: trailingKey,
        duration: OsdMotion.d(context, OsdMotion.fast),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: .8, end: 1).animate(animation),
            child: child,
          ),
        ),
        child: selected
            ? OsdIcon(
                OsdIcons.radioButtonChecked,
                key: const ValueKey<bool>(true),
                fill: 1,
                color: colors.tx,
              )
            : OsdIcon(
                OsdIcons.radioButtonUnchecked,
                key: const ValueKey<bool>(false),
                color: colors.fa,
              ),
      ),
      _Custom(:final child) => KeyedSubtree(key: trailingKey, child: child),
    };
  }
}

class _Value extends StatelessWidget {
  const _Value({
    required this.value,
    required this.leading,
    required this.style,
    required this.maxLines,
    required this.alignment,
  });

  static const Duration _change = Duration(milliseconds: 200);
  static const double _rise = 4;

  final String value;
  final Widget? leading;
  final TextStyle style;
  final int maxLines;

  /// Where the old and the new value line up while they crossfade.
  final AlignmentDirectional alignment;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 8,
    children: <Widget>[
      ?leading,
      Flexible(
        child: AnimatedSwitcher(
          duration: OsdMotion.d(context, _change),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeOut,
          layoutBuilder: (current, previous) => Stack(
            alignment: alignment,
            children: <Widget>[...previous, ?current],
          ),
          transitionBuilder: (child, animation) => FadeRise(
            animation: animation,
            // Only the incoming value rises; the outgoing one fades in place.
            rise:
                child.key == ValueKey<String>(value) &&
                    !OsdMotion.reduced(context)
                ? _rise
                : 0,
            child: child,
          ),
          child: KeyedSubtree(
            key: ValueKey<String>(value),
            child: Text(
              value,
              key: OsdListRow.valueKey,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ),
      ),
    ],
  );
}
