import 'package:flutter/material.dart';
import 'package:one_second_diary/theme/osd_colors.dart';

/// A fixed-size circular spinner.
///
/// It is always visible when built: wrap it in `OsdLoadingDelay` so it only
/// appears after a short delay. Spinners keep spinning under reduced motion;
/// they carry information.
class OsdSpinner extends StatelessWidget {
  const OsdSpinner({super.key, this.size = 20, this.color});

  /// The diameter.
  final double size;

  /// The colour; TX by default.
  final Color? color;

  /// The stroke for a spinner of [size].
  static double strokeFor(double size) => size <= 18 ? 2 : 2.5;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CircularProgressIndicator(
      strokeWidth: strokeFor(size),
      color: color ?? context.colors.tx,
      backgroundColor: Colors.transparent,
      strokeCap: StrokeCap.round,
    ),
  );
}
