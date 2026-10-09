import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// A count that ticks when it changes: the new text rises into place and fades
/// in while the old one rises away; under reduced motion it changes at once.
class CountTickText extends StatelessWidget {
  const CountTickText({
    super.key,
    required this.text,
    required this.style,
    this.textKey,
    this.textAlign,
  });

  final String text;

  final TextStyle style;

  /// The key of the [Text] shown now.
  final Key? textKey;

  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    // `countTickSlide` as a share of the line (the style's size at the
    // Rubik line height).
    final double slide =
        OsdMotion.countTickSlide / ((style.fontSize ?? 15) * _lineHeight);
    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: OsdMotion.reduced(context)
            ? Duration.zero
            : OsdMotion.countTick,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          // The new count rises in from below; the old one rises away.
          final bool incoming = child.key == ValueKey<String>(text);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, incoming ? slide : -slide),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
          alignment: textAlign == TextAlign.center
              ? Alignment.center
              : AlignmentDirectional.centerStart,
          children: <Widget>[...previous, ?current],
        ),
        child: KeyedSubtree(
          key: ValueKey<String>(text),
          child: Text(
            text,
            key: textKey,
            // A large text size wraps the count rather than cut it.
            textAlign: textAlign,
            style: style,
          ),
        ),
      ),
    );
  }

  /// Rubik's normal line height.
  static const double _lineHeight = 1.185;
}
