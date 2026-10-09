import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/controls/quick_cut_chip.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_hit_slop.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_overflow_hit_area.dart';

/// The row of quick-cut chips under the trimmer, scrolling sideways
/// (unclipped) when it overflows at large text or on narrow screens.
///
/// A chip longer than [maxSeconds] (the source) is disabled; the chip equal
/// to [selected] is marked. The row lays out at the chips' visual height:
/// their tap targets reach into the gaps around it (`OsdOverflowHitArea`,
/// `OsdHitSlop`).
class QuickCutChipRow extends StatelessWidget {
  const QuickCutChipRow({
    super.key,
    required this.values,
    required this.selected,
    this.maxSeconds,
    required this.onSelected,
    required this.semanticsLabel,
  });

  /// How far the targets reach past the chips.
  static const double _reach = 11;

  /// The chip lengths, in seconds.
  final List<double> values;

  /// The current trim length, if it matches a chip.
  final double? selected;

  /// The source length; longer chips are disabled.
  final double? maxSeconds;

  /// Called with the length the user picks.
  final ValueChanged<double> onSelected;

  /// The semantics label of the chip for a length.
  final String Function(double seconds) semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final maxSeconds = this.maxSeconds;
    return OsdHitSlop(
      slop: const EdgeInsets.symmetric(vertical: _reach),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: OsdHitSlop(
          slop: const EdgeInsets.symmetric(vertical: _reach),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: <Widget>[
              for (final seconds in values)
                OsdOverflowHitArea(
                  child: QuickCutChip(
                    seconds: seconds,
                    selected: seconds == selected,
                    enabled: maxSeconds == null || seconds <= maxSeconds,
                    onTap: () => onSelected(seconds),
                    semanticsLabel: semanticsLabel(seconds),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
