import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/buttons/osd_text_button.dart';
import 'package:one_second_diary/shared/widgets/buttons/primary_button.dart';
import 'package:one_second_diary/shared/widgets/foundation/osd_icon.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The camera's permission / error panel (wrap the camera route in
/// `OsdForcedDark`): a glyph in a circle, a title (a header), a body, a
/// `PrimaryButton`, and an optional secondary text button.
class CameraStatePanel extends StatelessWidget {
  const CameraStatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  static const Key circleKey = Key('cameraStatePanel.circle');

  final IconData icon;

  final String title;

  final String body;

  /// The primary action ("Allow camera", "Open settings").
  final String actionLabel;

  final VoidCallback? onAction;

  /// The secondary action ("Use phone's camera app").
  final String? secondaryLabel;

  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final secondaryLabel = this.secondaryLabel;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: <Widget>[
          SizedBox.square(
            key: circleKey,
            dimension: 72,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.c2,
              ),
              child: Center(child: OsdIcon(icon, size: 36, color: colors.mu)),
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: typography.sheetTitle.copyWith(color: colors.tx),
            ),
          ),
          Text(
            body,
            textAlign: TextAlign.center,
            style: typography.body15Loose.copyWith(color: colors.mu),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: PrimaryButton(label: actionLabel, onPressed: onAction),
          ),
          if (secondaryLabel != null)
            OsdTextButton(
              label: secondaryLabel,
              tone: OsdTextButtonTone.secondary,
              onPressed: onSecondary,
            ),
        ],
      ),
    );
  }
}
