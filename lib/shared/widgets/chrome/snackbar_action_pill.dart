import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_pressable.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_spinner.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_motion.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The snackbar's action ("Undo", "Retry"), with a label that never wraps.
///
/// While the action runs ([busy]) a spinner replaces the label, the width
/// stays and the pill is disabled.
class SnackbarActionPill extends StatelessWidget {
  const SnackbarActionPill({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
  });

  static const Key surfaceKey = Key('snackbarActionPill.surface');

  static const Key spinnerKey = Key('snackbarActionPill.spinner');

  final String label;

  final VoidCallback? onPressed;

  /// Whether the action is running.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(OsdRadius.r10);
    return OsdPressable(
      onTap: busy ? null : onPressed,
      pressScale: OsdPressScale.button.scale,
      overlay: OsdPressOverlay.none,
      borderRadius: radius,
      semanticsLabel: label,
      excludeChildSemantics: true,
      child: DecoratedBox(
        key: surfaceKey,
        decoration: BoxDecoration(
          color: OsdMedia.snackbarActionFill,
          borderRadius: radius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              AnimatedOpacity(
                opacity: busy ? 0 : 1,
                duration: OsdMotion.d(context, OsdMotion.fast),
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: context.typography.label14Strong.copyWith(
                    color: colors.snackbarText,
                  ),
                ),
              ),
              if (busy)
                const OsdSpinner(
                  key: spinnerKey,
                  size: 14,
                  color: OsdMedia.onMedia,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
