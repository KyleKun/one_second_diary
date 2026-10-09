import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_motion.dart';

/// A number that counts to its [value].
///
/// The integer is tweened over [duration] and formatted every frame by
/// [format], which owns the locale and the words ("25 of 28 days"). The box
/// is as wide as the wider of the start and final strings; wider strings on
/// the way (Yusei Magic has proportional digits) overflow it instead of
/// shifting the layout.
///
/// It counts up from 0 on first show when [countUpOnAppear] (pages turn it
/// off after the first time in a session) and tweens from the old value on
/// every change. Under reduced motion numbers render final. Screen readers
/// hear only the final value.
class AnimatedCount extends StatefulWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.duration = OsdMotion.countUp,
    this.countUpOnAppear = true,
    this.textAlign,
    this.textScaler,
  });

  /// The visible, counting text.
  static const Key valueKey = Key('animatedCount.value');

  final int value;

  final String Function(int value) format;

  final TextStyle? style;

  /// How long a count takes.
  final Duration duration;

  /// Whether the first show counts up from 0.
  final bool countUpOnAppear;

  /// How the text aligns inside the reserved width.
  final TextAlign? textAlign;

  final TextScaler? textScaler;

  @override
  State<AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<AnimatedCount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late int _from = widget.value;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.countUpOnAppear && !OsdMotion.reduced(context)) {
      _from = 0;
      unawaited(_controller.forward(from: 0));
    }
  }

  @override
  void didUpdateWidget(AnimatedCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    _from = _valueTowards(oldWidget.value);
    _controller.duration = widget.duration;
    if (OsdMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      unawaited(_controller.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _current => _valueTowards(widget.value);

  int _valueTowards(int target) => lerpDouble(
    _from,
    target,
    Curves.easeOutCubic.transform(_controller.value),
  )!.round();

  Text _text(String data, {Key? key}) => Text(
    data,
    key: key,
    maxLines: 1,
    softWrap: false,
    textAlign: widget.textAlign,
    textScaler: widget.textScaler,
    style: widget.style,
  );

  @override
  Widget build(BuildContext context) {
    final alignment = switch (widget.textAlign) {
      TextAlign.center => Alignment.center,
      TextAlign.end || TextAlign.right => AlignmentDirectional.centerEnd,
      _ => AlignmentDirectional.centerStart,
    };
    return Semantics(
      label: widget.format(widget.value),
      child: ExcludeSemantics(
        child: Stack(
          alignment: alignment,
          children: <Widget>[
            // Reserve the widest string the count passes through.
            Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: _text(widget.format(widget.value)),
            ),
            Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: _text(widget.format(_from)),
            ),
            // Intermediate strings may be wider (proportional digits): they
            // overflow the reserved box instead of moving the layout.
            Positioned.fill(
              child: OverflowBox(
                maxWidth: double.infinity,
                alignment: alignment,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => _text(
                    widget.format(_current),
                    key: AnimatedCount.valueKey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
