import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/neutral_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_button_size.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_space.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// One numbered step of a how-to list (the Backup & restore sheet): the
/// number in a small circle, the text (any number of lines) and, for a
/// step that acts, a compact button under the text ([actionLabel],
/// [onAction]). The number and the text are one semantics node; the button
/// is its own.
class OsdStepRow extends StatelessWidget {
  const OsdStepRow({
    super.key,
    required this.number,
    required this.text,
    this.actionLabel,
    this.onAction,
    this.actionLoading = false,
    this.note,
  });

  static const Key actionKey = Key('osdStepRow.action');

  /// 1-based.
  final int number;

  final String text;

  /// The button's label; null for a step without one.
  final String? actionLabel;

  /// Called on tap; null disables the button.
  final VoidCallback? onAction;

  /// The button spins (a scan in flight).
  final bool actionLoading;

  /// A quieter line under the text (a result, a fallback).
  final String? note;

  static const double _circle = 26;

  @override
  Widget build(BuildContext context) {
    final OsdColors colors = context.colors;
    final OsdTypography typography = context.typography;
    final String? label = actionLabel;
    final String? note = this.note;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: OsdSpace.textInset,
        vertical: OsdSpace.s8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: OsdSpace.s12,
        children: <Widget>[
          MergeSemantics(
            child: SizedBox.square(
              dimension: _circle,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.c2,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: typography.label13.copyWith(color: colors.tx),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: OsdSpace.s8,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: OsdSpace.s4),
                  child: Text(
                    text,
                    style: typography.body15Loose.copyWith(color: colors.tx),
                  ),
                ),
                if (note != null)
                  Text(
                    note,
                    style: typography.footnote.copyWith(color: colors.mu),
                  ),
                if (label != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: NeutralButton(
                      key: actionKey,
                      label: label,
                      size: OsdButtonSize.compact,
                      hug: true,
                      loading: actionLoading,
                      onPressed: onAction,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
