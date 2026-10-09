import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/display_text.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/journey/presentation/journey_formats.dart';
import 'package:one_second_diary/shared/widgets/surfaces/stat_value.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// "Your life so far": the summed length of every clip, its largest unit
/// big and the next one small ("15 min" + " 14 s"), counting in seconds
/// with the page's count-up and formatted every frame.
///
/// While the duration backfill runs the value is an [estimate]: "About 15
/// min 14 s" (`approximateValue`; a word, since Yusei Magic has no "≈").
/// The box is as big as the final value, so the layout never moves.
class LifeSoFarValue extends StatelessWidget {
  const LifeSoFarValue({
    super.key,
    required this.seconds,
    required this.estimate,
    required this.progress,
  });

  final int seconds;
  final bool estimate;

  /// The count-up, 0 → 1.
  final Animation<double> progress;

  /// The value as the Journey shows it once counted.
  static String textOf({required int seconds, required bool estimate}) {
    final ({String primary, String? secondary}) parts = JourneyFormats.duration(
      seconds,
    );
    final String value = <String>[parts.primary, ?parts.secondary].join(' ');
    return DisplayText.safe(
      estimate ? Strings.approximateValue(value: value) : value,
    );
  }

  /// The value as screen readers hear it: the units in words ("About 15
  /// minutes 14 seconds"), never the drawn "min" and "s".
  static String spokenOf({required int seconds, required bool estimate}) {
    final String value = JourneyFormats.durationSpoken(seconds);
    return estimate ? Strings.approximateValue(value: value) : value;
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = OsdMotion.reduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: seconds.toDouble()),
      duration: reduced ? Duration.zero : OsdMotion.countUpShort,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double target, Widget? finalValue) =>
          Stack(
            children: <Widget>[
              ?finalValue,
              Positioned.fill(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AnimatedBuilder(
                    animation: progress,
                    builder: (BuildContext context, _) => _value(
                      (target * (reduced ? 1 : progress.value)).round(),
                    ),
                  ),
                ),
              ),
            ],
          ),
      child: Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: _value(seconds),
      ),
    );
  }

  StatValue _value(int seconds) => StatValue(
    text: textOf(seconds: seconds, estimate: estimate),
    emphasis: JourneyFormats.duration(seconds).primary,
  );
}
