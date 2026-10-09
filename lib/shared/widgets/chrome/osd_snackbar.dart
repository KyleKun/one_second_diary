import 'package:flutter/material.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snack_kind.dart';
import 'package:one_second_diary/shared/widgets/chrome/osd_snackbar_host.dart';
import 'package:one_second_diary/shared/widgets/chrome/snackbar_action_pill.dart';
import 'package:one_second_diary/shared/widgets/chrome/status_icon_circle.dart';
import 'package:one_second_diary/theme/osd_colors.dart';
import 'package:one_second_diary/theme/osd_media.dart';
import 'package:one_second_diary/theme/osd_radius.dart';
import 'package:one_second_diary/theme/osd_text_scale.dart';
import 'package:one_second_diary/theme/osd_text_scale_clamp.dart';
import 'package:one_second_diary/theme/osd_typography.dart';

/// The floating snackbar, dark in both themes.
///
/// Show one with [OsdSnackbar.show]: the nearest `OsdSnackbarHost` places it
/// above the highest `SnackbarAnchor` (the nav, a bottom CTA) and owns its
/// motion, timeout and dismissal.
///
/// This widget is the surface: a [StatusIconCircle], a title, an optional
/// sub-line and an optional [SnackbarActionPill].
class OsdSnackbar extends StatelessWidget {
  const OsdSnackbar({
    super.key,
    required this.kind,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.busy = false,
  });

  static const Key surfaceKey = Key('osdSnackbar.surface');

  /// Shows a snackbar in the nearest `OsdSnackbarHost`, replacing the current
  /// one.
  ///
  /// [onAction] runs when the action is tapped: the pill spins until it
  /// completes, then the snackbar leaves. If it throws, the snackbar turns
  /// into an error with [actionErrorTitle] and no action. [onDismissed]
  /// runs once when it leaves any other way (see
  /// `OsdSnackbarRequest.onDismissed`).
  static void show(
    BuildContext context, {
    required OsdSnackKind kind,
    required String title,
    String? subtitle,
    String? actionLabel,
    Future<void> Function()? onAction,
    String? actionErrorTitle,
    Duration? duration,
    VoidCallback? onDismissed,
  }) => OsdSnackbarHost.of(context).show(
    OsdSnackbarRequest(
      kind: kind,
      title: title,
      subtitle: subtitle,
      actionLabel: actionLabel,
      onAction: onAction,
      actionErrorTitle: actionErrorTitle,
      duration: duration,
      onDismissed: onDismissed,
    ),
  );

  /// Hides the current snackbar of the nearest host.
  static void hide(BuildContext context) =>
      OsdSnackbarHost.maybeOf(context)?.hide();

  final OsdSnackKind kind;

  final String title;

  final String? subtitle;

  final String? actionLabel;

  final VoidCallback? onAction;

  /// Whether the action is running.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final subtitle = this.subtitle;
    final actionLabel = this.actionLabel;
    return OsdTextScaleClamp(
      role: OsdTextScaleRole.snackbar,
      child: Semantics(
        container: true,
        liveRegion: true,
        // Its own text style: a full-screen page puts its host above its
        // Scaffold, where a Text would inherit MaterialApp's fallback (a
        // yellow double underline).
        child: Material(
          type: MaterialType.transparency,
          child: DecoratedBox(
            key: surfaceKey,
            decoration: BoxDecoration(
              color: colors.snackbarBg,
              borderRadius: BorderRadius.circular(OsdRadius.r18),
              boxShadow: const <BoxShadow>[OsdMedia.snackbarShadow],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 58),
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 14, end: 12),
                child: Row(
                  spacing: 12,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: StatusIconCircle(kind: kind),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typography.titleSmall.copyWith(
                                color: colors.snackbarText,
                              ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: typography.caption13.copyWith(
                                  color: colors.snackbarSub,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (actionLabel != null)
                      SnackbarActionPill(
                        label: actionLabel,
                        onPressed: onAction,
                        busy: busy,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
