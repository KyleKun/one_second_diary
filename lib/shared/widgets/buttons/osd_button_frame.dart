import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/dashed_border.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_loading_delay.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_spinner.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// The body every labelled button shares: a filled, outlined or dashed rounded
/// surface with an optional icon and a one-line label that scales down to
/// fit. Use the named buttons (`PrimaryButton`, `NeutralButton`, …); this is
/// their building block.
///
/// - The height is a minimum: large text grows it.
/// - *disabled* (`onPressed == null`): fades when [fadeWhenDisabled],
///   otherwise the caller passes a disabled [foreground].
/// - *loading*: after a short delay a spinner replaces the icon (or the label
///   when there is no icon), [loadingLabel] crossfades in, the width is kept
///   and taps are ignored.
class OsdButtonFrame extends StatelessWidget {
  const OsdButtonFrame({
    super.key,
    required this.label,
    required this.labelStyle,
    required this.foreground,
    required this.minHeight,
    required this.radius,
    this.icon,
    this.leading,
    this.fill,
    this.border,
    this.dashColor,
    this.onPressed,
    this.hug = false,
    this.horizontalPadding,
    this.verticalPadding = 0,
    this.maxLines = 1,
    this.loading = false,
    this.loadingLabel,
    this.spinnerSize = 20,
    this.spinnerColor,
    this.overlay = OsdPressOverlay.sel,
    this.pressScale = .97,
    this.fadeWhenDisabled = true,
    this.haptic,
    this.iconSize = 20,
    this.iconFill = 0,
    this.gap = 8,
    this.autofocus = false,
    this.semanticsLabel,
  });

  /// The painted surface (fill, border or dashes).
  static const Key surfaceKey = Key('osdButton.surface');

  static const Key labelKey = Key('osdButton.label');

  static const Key spinnerKey = Key('osdButton.spinner');

  final String label;

  /// The label style, without colour.
  final TextStyle labelStyle;

  /// The label and icon colour.
  final Color foreground;

  final double minHeight;

  /// The corner radius (use a large value for a stadium).
  final double radius;

  final IconData? icon;

  /// A leading widget instead of [icon].
  final Widget? leading;

  /// The fill; transparent when null.
  final Color? fill;

  final BorderSide? border;

  /// A dashed border in this colour.
  final Color? dashColor;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  /// Whether the button hugs its content instead of filling its slot.
  final bool hug;

  /// Horizontal padding; 24 when [hug], 16 otherwise.
  final double? horizontalPadding;

  final double verticalPadding;

  /// 1 scales the label down to fit; more lets it wrap.
  final int maxLines;

  final bool loading;

  final String? loadingLabel;

  final double spinnerSize;

  /// [foreground] by default.
  final Color? spinnerColor;

  final OsdPressOverlay overlay;

  final double pressScale;

  final bool fadeWhenDisabled;

  /// Played on tap.
  final OsdHaptic? haptic;

  final double iconSize;

  final double iconFill;

  /// The icon → label gap.
  final double gap;

  final bool autofocus;

  /// A semantics label, when the visible label is not enough.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final enabled = onPressed != null && !loading;
    final padding = horizontalPadding ?? (hug ? 24 : 16);

    Widget content = OsdLoadingDelay(
      loading: loading,
      builder: (context, showLoading) =>
          _Content(frame: this, showLoading: showLoading),
    );

    content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: padding,
          vertical: verticalPadding,
        ),
        child: hug ? content : Align(heightFactor: 1, child: content),
      ),
    );

    final dashColor = this.dashColor;
    content = dashColor != null
        ? DashedBorder(
            key: surfaceKey,
            color: dashColor,
            borderRadius: borderRadius,
            child: content,
          )
        : DecoratedBox(
            key: surfaceKey,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: borderRadius,
              border: border == null ? null : Border.fromBorderSide(border!),
            ),
            child: content,
          );

    final Widget result = OsdPressable(
      opacity: OsdPressable.opacityFor(
        enabled: !(onPressed == null && !loading && fadeWhenDisabled),
      ),
      onTap: enabled ? onPressed : null,
      pressScale: pressScale,
      overlay: overlay,
      borderRadius: borderRadius,
      haptic: haptic,
      autofocus: autofocus,
      semanticsLabel: semanticsLabel,
      child: content,
    );
    return result;
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.frame, required this.showLoading});

  final OsdButtonFrame frame;
  final bool showLoading;

  @override
  Widget build(BuildContext context) {
    final style = frame.labelStyle.copyWith(color: frame.foreground);
    final spinner = OsdSpinner(
      key: OsdButtonFrame.spinnerKey,
      size: frame.spinnerSize,
      color: frame.spinnerColor ?? frame.foreground,
    );
    final text = showLoading && frame.loadingLabel != null
        ? frame.loadingLabel!
        : frame.label;
    Widget label = Text(
      text,
      key: OsdButtonFrame.labelKey,
      style: style,
      maxLines: frame.maxLines,
      textAlign: TextAlign.center,
      overflow: frame.maxLines == 1 ? null : TextOverflow.ellipsis,
    );
    if (frame.maxLines == 1) {
      label = FittedBox(fit: BoxFit.scaleDown, child: label);
    }
    label = AnimatedSwitcher(
      duration: OsdMotion.d(context, OsdMotion.fast),
      child: KeyedSubtree(key: ValueKey<String>(text), child: label),
    );

    final hasLeading = frame.icon != null || frame.leading != null;
    if (!hasLeading) {
      // The spinner takes the label's place; the label keeps the width.
      return Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Visibility.maintain(visible: !showLoading, child: label),
          if (showLoading) spinner,
        ],
      );
    }

    final leading = showLoading
        ? SizedBox.square(
            dimension: frame.iconSize,
            child: Center(child: spinner),
          )
        : frame.leading ??
              OsdIcon(
                frame.icon!,
                size: frame.iconSize,
                fill: frame.iconFill,
                color: frame.foreground,
              );
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: frame.gap,
      children: <Widget>[
        leading,
        Flexible(child: label),
      ],
    );
  }
}
