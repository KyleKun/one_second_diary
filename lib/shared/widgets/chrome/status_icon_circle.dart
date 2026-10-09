import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_icons.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_tints.dart';

/// The status badge at the start of a snackbar. The snackbar is dark in both
/// themes, so it uses the dark RED and GREEN.
class StatusIconCircle extends StatelessWidget {
  const StatusIconCircle({super.key, required this.kind});

  final OsdSnackKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (fill, icon, iconFill, ink) = switch (kind) {
      OsdSnackKind.success => (
        OsdTints.greenTint20,
        OsdIcons.check,
        0.0,
        colors.snackbarSuccess,
      ),
      OsdSnackKind.error => (
        OsdTints.redTint20,
        OsdIcons.error,
        1.0,
        colors.snackbarError,
      ),
      OsdSnackKind.delete => (
        OsdTints.redTint20,
        OsdIcons.delete,
        0.0,
        colors.snackbarError,
      ),
      OsdSnackKind.info => (
        OsdMedia.snackbarActionFill,
        OsdIcons.info,
        0.0,
        colors.snackbarText,
      ),
    };
    return SizedBox.square(
      dimension: 34,
      child: DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: fill),
        child: Center(
          child: OsdIcon(icon, size: 20, fill: iconFill, color: ink),
        ),
      ),
    );
  }
}
