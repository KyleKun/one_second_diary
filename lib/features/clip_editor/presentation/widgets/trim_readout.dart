import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/clip_editor/domain/clip_length_format.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The readout above the filmstrip: the length the clip will be saved at,
/// as "01.50".
///
/// A new length rolls from the old one, in tabular figures so the width
/// holds still; a drag retargets it every frame.
class TrimReadout extends StatelessWidget {
  const TrimReadout({super.key, required this.lengthMs});

  static const Key textKey = Key('trimReadout.text');

  static const double _maxTextScale = 1.5;

  /// The saved length.
  final int lengthMs;

  @override
  Widget build(BuildContext context) {
    final ClipLengthFormat format = ClipLengthFormat.of(
      Localizations.localeOf(context).toString(),
    );
    final TextStyle style = context.typography.label14.copyWith(
      color: context.colors.tx,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    return Semantics(
      label: Strings.saveVideoClipLengthSemantics(
        lengthMs / 1000,
        format: format.secondsFormat,
      ),
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: lengthMs.toDouble()),
        duration: OsdMotion.d(context, OsdMotion.digitRoll),
        curve: OsdMotion.curve(context, OsdMotion.standardCurve),
        builder: (BuildContext context, double value, _) => Text(
          format.readout(value.round()),
          key: textKey,
          textAlign: TextAlign.center,
          maxLines: 1,
          textScaler: MediaQuery.textScalerOf(
            context,
          ).clamp(maxScaleFactor: _maxTextScale),
          style: style,
        ),
      ),
    );
  }
}
