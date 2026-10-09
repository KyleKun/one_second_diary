import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_frame.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The colour role of an [OsdTextButton].
enum OsdTextButtonTone { link, secondary, muted, destructive }

/// A text-only button in its [tone]'s colour, no fill.
///
/// Heights follow the tone unless [height] is given. A hugging
/// [OsdTextButtonTone.link] is the compact app-bar link.
class OsdTextButton extends StatelessWidget {
  const OsdTextButton({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.onPressed,
    this.tone = OsdTextButtonTone.link,
    this.height,
    this.hug = false,
    this.autofocus = false,
  });

  static const Key surfaceKey = OsdButtonFrame.surfaceKey;

  final String label;

  final IconData? icon;

  /// A leading widget instead of [icon].
  final Widget? leading;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  final OsdTextButtonTone tone;

  /// The visual height; the tone's height by default.
  final double? height;

  final bool hug;

  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final compact = hug && tone == OsdTextButtonTone.link;
    return OsdButtonFrame(
      label: label,
      icon: icon,
      leading: leading,
      onPressed: onPressed,
      labelStyle: compact ? typography.label14 : typography.rowTitleStrong,
      foreground: switch (tone) {
        OsdTextButtonTone.link => colors.tx,
        OsdTextButtonTone.secondary => colors.d2,
        OsdTextButtonTone.muted => colors.mu,
        OsdTextButtonTone.destructive => colors.red,
      },
      minHeight:
          height ??
          switch (tone) {
            _ when compact => 0,
            OsdTextButtonTone.secondary => 48,
            OsdTextButtonTone.destructive => 40,
            _ => 44,
          },
      radius: OsdRadius.r12,
      hug: hug,
      horizontalPadding: compact ? 8 : null,
      verticalPadding: compact ? 4 : 0,
      autofocus: autofocus,
    );
  }
}
