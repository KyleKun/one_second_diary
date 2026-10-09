import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/shared/widgets/surfaces/osd_callout.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_tints.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The orientation step's tip card: a lightbulb on a yellow tint, then the
/// two tips, each with its bold run ("TV, laptop or tablet → choose
/// Landscape.").
///
/// The tips name the options with the same words as the tiles
/// (`Strings.landscape`, `Strings.portrait`), and translators mark the
/// bold run with `<b>…</b>` (the only markup the copy uses).
class OrientationTipCard extends StatelessWidget {
  const OrientationTipCard({super.key});

  @override
  Widget build(BuildContext context) {
    final TextStyle bold = TextStyle(
      fontWeight: context.typography.label14Strong.fontWeight,
    );
    return OsdCallout.accent(
      icon: OsdIcons.lightbulb,
      accent: context.colors.yellow,
      tint: OsdTints.yellowTint12,
      lines: <InlineSpan>[
        boldRuns(
          Strings.onboardingOrientationTipLandscape(
            landscape: Strings.landscape,
          ),
          bold,
        ),
        boldRuns(
          Strings.onboardingOrientationTipPortrait(portrait: Strings.portrait),
          bold,
        ),
      ],
    );
  }

  /// [text] as spans, the parts between `<b>` and `</b>` in [bold]. An
  /// unclosed `<b>` makes the rest bold; tags never show.
  static TextSpan boldRuns(String text, TextStyle bold) {
    const String open = '<b>';
    const String close = '</b>';
    final List<InlineSpan> runs = <InlineSpan>[];
    int at = 0;
    while (at < text.length) {
      final int start = text.indexOf(open, at);
      if (start < 0) {
        runs.add(TextSpan(text: text.substring(at)));
        break;
      }
      if (start > at) runs.add(TextSpan(text: text.substring(at, start)));
      final int end = text.indexOf(close, start + open.length);
      final int stop = end < 0 ? text.length : end;
      runs.add(
        TextSpan(text: text.substring(start + open.length, stop), style: bold),
      );
      at = end < 0 ? text.length : end + close.length;
    }
    return TextSpan(children: runs);
  }
}
