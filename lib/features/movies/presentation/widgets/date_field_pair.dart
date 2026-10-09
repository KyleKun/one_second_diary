import 'package:flutter/material.dart';
import 'package:one_second_diary/core/l10n/strings.dart';
import 'package:one_second_diary/features/movies/domain/date_choice.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_haptics.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The "Choose dates" sheet's From and To fields, side by side: each shows its
/// day ([from], [to], formatted) or "Pick a day".
class DateFieldPair extends StatelessWidget {
  const DateFieldPair({
    super.key,
    required this.from,
    required this.to,
    required this.active,
    required this.onFromTap,
    required this.onToTap,
  });

  static const Key fromKey = Key('dateFieldPair.from');
  static const Key toKey = Key('dateFieldPair.to');

  /// The first day, formatted; null until picked.
  final String? from;

  /// The last day, formatted; null until picked.
  final String? to;

  /// The end the next tap on the grid sets.
  final DateEnd active;

  final VoidCallback onFromTap;
  final VoidCallback onToTap;

  @override
  Widget build(BuildContext context) => Row(
    spacing: OsdSpace.s8,
    children: <Widget>[
      Expanded(
        child: _DateField(
          key: fromKey,
          label: Strings.movieDateFrom,
          value: from,
          active: active == DateEnd.from,
          onTap: onFromTap,
        ),
      ),
      Expanded(
        child: _DateField(
          key: toKey,
          label: Strings.movieDateTo,
          value: to,
          active: active == DateEnd.to,
          onTap: onToTap,
        ),
      ),
    ],
  );
}

/// One field: its [label] over its [value] (or the placeholder), on a CO
/// fill while [active], C2 otherwise.
class _DateField extends StatelessWidget {
  const _DateField({
    super.key,
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String? value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final String? value = this.value;
    final String shown = value ?? Strings.movieDatePickDay;
    return OsdPressable(
      onTap: onTap,
      haptic: OsdHaptic.selection,
      pressScale: OsdPressScale.button.scale,
      borderRadius: BorderRadius.circular(OsdRadius.r12),
      selected: active,
      semanticsLabel: '$label, $shown',
      excludeChildSemantics: true,
      child: AnimatedContainer(
        duration: OsdMotion.d(context, OsdMotion.fast),
        curve: OsdMotion.curve(context, OsdMotion.fastCurve),
        decoration: BoxDecoration(
          color: active ? colors.coFill : colors.c2,
          borderRadius: BorderRadius.circular(OsdRadius.r12),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: OsdSpace.s12,
          vertical: OsdSpace.s10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: OsdSpace.s2,
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.caption.copyWith(
                color: active ? colors.coInk : colors.mu,
              ),
            ),
            Text(
              shown,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.typography.rowTitleStrong.copyWith(
                color: value == null ? colors.mu : colors.tx,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
