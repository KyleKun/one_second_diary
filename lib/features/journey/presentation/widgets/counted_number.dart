import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// A Journey stat's number, counting.
///
/// [progress] runs 0 → 1 once per session (the page's count-up, with this
/// tile's stagger): the number shown is [value] × progress, formatted each
/// frame by [format]. Later changes of [value] (a new clip, a movie made)
/// tween from the old value over `countUpShort`. Under reduced motion the
/// number is final at once.
///
/// The box is as wide as the final number, so Yusei Magic's proportional
/// digits never move the layout: a wider number on the way overflows it.
class CountedNumber extends StatelessWidget {
  const CountedNumber({
    super.key,
    required this.value,
    required this.format,
    required this.progress,
    required this.style,
    required this.textScaler,
  });

  /// The number as it shows.
  static const Key textKey = Key('countedNumber.text');

  final int value;

  /// Formats a number for display ("1,234").
  final String Function(int value) format;

  /// The count-up, 0 → 1.
  final Animation<double> progress;

  final TextStyle style;

  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    final bool reduced = OsdMotion.reduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: value.toDouble()),
      duration: reduced ? Duration.zero : OsdMotion.countUpShort,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double target, Widget? finalText) =>
          Stack(
            children: <Widget>[
              ?finalText,
              Positioned.fill(
                child: OverflowBox(
                  maxWidth: double.infinity,
                  alignment: AlignmentDirectional.centerStart,
                  child: AnimatedBuilder(
                    animation: progress,
                    builder: (BuildContext context, _) => _text(
                      format((target * (reduced ? 1 : progress.value)).round()),
                      key: textKey,
                    ),
                  ),
                ),
              ),
            ],
          ),
      // Reserves the final number's width.
      child: Visibility(
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: _text(format(value)),
      ),
    );
  }

  Text _text(String data, {Key? key}) => Text(
    data,
    key: key,
    maxLines: 1,
    softWrap: false,
    textScaler: textScaler,
    style: style,
  );
}
