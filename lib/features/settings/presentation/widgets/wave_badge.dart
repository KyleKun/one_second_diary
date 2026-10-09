import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:one_second_diary/theme/osd_tints.dart';

/// The badge over "Support the app": a waving hand emoji in a yellow
/// disc. [wave] (0 to 1) swings it from the wrist a few times, as it
/// enters.
class WaveBadge extends StatelessWidget {
  const WaveBadge({super.key, this.wave = 1});

  static const Key circleKey = Key('waveBadge.circle');

  static const double _size = 120;
  static const double _hand = 56;

  /// Full swings over a wave.
  static const int _swings = 2;
  static const double _swingRadians = .32;

  final double wave;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: _size,
      child: DecoratedBox(
        key: circleKey,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: OsdTints.yellowTint14,
        ),
        child: Center(
          child: Transform.rotate(
            angle:
                math.sin(wave * math.pi * _swings * 2) *
                _swingRadians *
                (1 - wave),
            alignment: Alignment.bottomRight,
            child: const Text(
              '👋',
              style: TextStyle(fontSize: _hand, height: 1),
            ),
          ),
        ),
      ),
    ),
  );
}
