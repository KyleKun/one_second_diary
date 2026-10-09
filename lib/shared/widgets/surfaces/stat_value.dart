import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A stat number with its unit: one line where the first occurrence of
/// [emphasis] is big (bigger when [hero]) in TX and the rest is small in MU.
///
/// Pass the localised string and the part to emphasise: "25 days" / "25",
/// "15 min 14 s" / "15 min". The line scales down to fit.
class StatValue extends StatelessWidget {
  const StatValue({
    super.key,
    required this.text,
    required this.emphasis,
    this.hero = false,
  });

  /// The whole value, formatted for the locale.
  final String text;

  /// The part drawn big.
  final String emphasis;

  final bool hero;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final big = (hero ? typography.displayHero : typography.displayStat)
        .copyWith(color: colors.tx);
    final small = typography.displayUnit.copyWith(color: colors.mu);
    final at = text.indexOf(emphasis);
    final spans = at < 0 || emphasis.isEmpty
        ? <TextSpan>[TextSpan(text: text, style: big)]
        : <TextSpan>[
            if (at > 0) TextSpan(text: text.substring(0, at), style: small),
            TextSpan(text: emphasis, style: big),
            if (at + emphasis.length < text.length)
              TextSpan(
                text: text.substring(at + emphasis.length),
                style: small,
              ),
          ];
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text.rich(
        TextSpan(children: spans),
        maxLines: 1,
        textScaler: OsdTextScale.scalerFor(context, OsdTextScaleRole.display),
      ),
    );
  }
}
