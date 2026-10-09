import 'package:flutter/material.dart';
import 'package:one_second_diary/features/journey/presentation/widgets/counted_number.dart';
import 'package:one_second_diary/shared/widgets/surfaces/stat_value.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// A Journey stat value whose number counts: one line where the number in
/// [text] is big (displayStat, or displayHero when [hero]) in TX and the
/// rest of [text] (the localised unit, wherever the language puts it: "12
/// days", "12 дней") is displayUnit in MU, on a shared baseline.
///
/// The line scales down to fit its tile and clamps text scaling (display
/// role).
class JourneyStatValue extends StatelessWidget {
  const JourneyStatValue({
    super.key,
    required this.text,
    required this.value,
    required this.format,
    required this.progress,
    this.hero = false,
  });

  /// The final value, localised ("12 days").
  final String text;

  /// The number in it.
  final int value;

  /// Formats a number as [text] shows it.
  final String Function(int value) format;

  /// The count-up, 0 → 1.
  final Animation<double> progress;

  final bool hero;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final TextScaler scaler = OsdTextScale.scalerFor(
      context,
      OsdTextScaleRole.display,
    );
    final TextStyle small = typography.displayUnit.copyWith(color: colors.mu);
    final String number = format(value);
    final int at = numberAt(text, number);
    // A translation that writes the number another way shows as it is.
    if (at < 0) return StatValue(text: text, emphasis: text, hero: hero);
    final String prefix = text.substring(0, at);
    final String suffix = text.substring(at + number.length);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          if (prefix.isNotEmpty) _Unit(prefix, style: small, scaler: scaler),
          CountedNumber(
            value: value,
            format: format,
            progress: progress,
            textScaler: scaler,
            style: (hero ? typography.displayHero : typography.displayStat)
                .copyWith(color: colors.tx),
          ),
          if (suffix.trim().isNotEmpty)
            _Unit(suffix, style: small, scaler: scaler),
        ],
      ),
    );
  }

  /// Where [number] stands on its own in [text] (not inside a longer
  /// number: "8" in "28 中 8" is the second one); -1 when it doesn't.
  static int numberAt(String text, String number) {
    bool isDigit(int at) =>
        at >= 0 && at < text.length && '0123456789'.contains(text[at]);
    for (
      int at = text.indexOf(number);
      at >= 0;
      at = text.indexOf(number, at + 1)
    ) {
      if (!isDigit(at - 1) && !isDigit(at + number.length)) return at;
    }
    return -1;
  }
}

class _Unit extends StatelessWidget {
  const _Unit(this.text, {required this.style, required this.scaler});

  final String text;
  final TextStyle style;
  final TextScaler scaler;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    softWrap: false,
    textScaler: scaler,
    style: style,
  );
}
