import 'package:flutter/widgets.dart';
import 'package:one_second_diary/shared/widgets/foundation/fade_rise.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// Swaps its [child] one after the other, never both at once: the old one
/// lifts [rise] px as it fades out, then the new one fades in rising into
/// place. Under reduced motion the old one fades out, then the new one
/// fades in. Children are aligned top-start while both are there; give
/// each a distinct key.
///
/// For one line of text, `OsdTextSwap` changes it letter by letter.
class RiseSwitcher extends StatelessWidget {
  const RiseSwitcher({super.key, required this.rise, required this.child});

  /// The whole swap.
  static const Duration duration = Duration(milliseconds: 280);

  /// The share of [duration] the old child takes to leave.
  static const double _out = .36;

  /// How far a child travels, in logical px.
  final double rise;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool reduced = OsdMotion.reduced(context);
    final Key? current = child.key;
    return AnimatedSwitcher(
      duration: OsdMotion.d(context, duration),
      layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: <Widget>[...previous, ?current],
      ),
      // A new closure each build: the old child's transition is rebuilt as
      // the one leaving.
      transitionBuilder: (Widget child, Animation<double> animation) {
        // A leaving child's animation runs back from 1 to 0.
        final bool leaving = child.key != current;
        return FadeRise(
          animation: animation.drive(
            CurveTween(
              curve: leaving
                  ? const Interval(1 - _out, 1, curve: Curves.easeIn)
                  : const Interval(_out, 1, curve: Curves.easeOutCubic),
            ),
          ),
          rise: reduced
              ? 0
              : leaving
              ? -rise
              : rise,
          child: child,
        );
      },
      child: child,
    );
  }
}
